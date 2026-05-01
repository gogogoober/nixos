// 1-to-1 translation of speak-selection.sh; not wired into tts.nix.
package main

import (
	"bytes"
	"cmp"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	piperHost      = "127.0.0.1"
	piperPort      = "5174"
	selectionSleep = 80 * time.Millisecond
	maxChars       = 10000
	maxChunkChars  = 200
)

var rt = cmp.Or(os.Getenv("XDG_RUNTIME_DIR"), "/tmp")
var lockFile = filepath.Join(rt, "speak-selection.pgid")
var mainLock = filepath.Join(rt, "speak-selection.main.lock")

var rules = []struct{ pat, repl string }{
	{`\x{200B}`, ""}, {`\x{200C}`, ""}, {`\x{200D}`, ""}, {`\x{FEFF}`, ""},
	{`[\x{1F000}-\x{1FFFF}]`, ""}, {`[\x{2600}-\x{27BF}]`, ""}, {`\x{FE0F}`, ""},
	{`\x{2014}`, ", "},
	{`\x{201C}`, `"`}, {`\x{201D}`, `"`}, {`\x{2018}`, "'"}, {`\x{2019}`, "'"},
	{`\*+([^*]+)\*+`, "$1"}, {`_+([^_]+)_+`, "$1"},
	{`(?m)^#+[ \t]+`, ""}, {`(?m)^>[ \t]+`, ""},
	{`https?://([^/\s]+)\S*`, "$1"}, {`\s+`, " "},
}

var punctEnd = regexp.MustCompile(`[.!?,]$`)

func sanitize(s string) string {
	parts := strings.Split(s, "```")
	for i := 1; i < len(parts); i += 2 {
		parts[i] = "Code Example."
	}
	s = strings.Join(parts, "")
	for _, r := range rules {
		s = regexp.MustCompile(r.pat).ReplaceAllString(s, r.repl)
	}
	return s
}

func chunks(text string, cap int) []string {
	var out []string
	var buf strings.Builder
	for _, w := range strings.Fields(text) {
		cand := w
		if buf.Len() > 0 {
			cand = buf.String() + " " + w
		}
		if len(cand) > cap && buf.Len() > 0 {
			out = append(out, buf.String()+" ")
			buf.Reset()
			buf.WriteString(w)
		} else {
			buf.Reset()
			buf.WriteString(cand)
		}
		if buf.Len() >= 40 && punctEnd.MatchString(buf.String()) {
			out = append(out, buf.String()+" ")
			buf.Reset()
		}
	}
	if buf.Len() > 0 {
		out = append(out, buf.String()+" ")
	}
	return out
}

func notifyErr(label string) {
	exec.Command("notify-send", "-t", "3000", "-u", "critical", "-a", "speak-selection", label).Run()
}

func synth(text string, w io.Writer) error {
	body, _ := json.Marshal(map[string]string{"text": text})
	req, _ := http.NewRequest("POST", "http://"+piperHost+":"+piperPort+"/", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: 60 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("status %d", resp.StatusCode)
	}
	if _, err := io.CopyN(io.Discard, resp.Body, 44); err != nil {
		return err
	}
	_, err = io.Copy(w, resp.Body)
	return err
}

func runMode() {
	text := os.Getenv("TTS_TEXT")
	os.Unsetenv("TTS_TEXT")
	if text == "" {
		return
	}
	pid := os.Getpid()
	os.WriteFile(lockFile, []byte(strconv.Itoa(pid)), 0600)
	cleanup := func() {
		if cur, err := os.ReadFile(lockFile); err == nil && strings.TrimSpace(string(cur)) == strconv.Itoa(pid) {
			os.Remove(lockFile)
		}
	}
	defer cleanup()
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	go func() { <-sigCh; cleanup(); os.Exit(0) }()

	text = sanitize(text)
	if strings.TrimSpace(text) == "" {
		return
	}
	aplay := exec.Command("aplay", "-q", "-f", "S16_LE", "-r", "22050", "-c", "1")
	in, err := aplay.StdinPipe()
	if err != nil || aplay.Start() != nil {
		return
	}
	for _, c := range chunks(text, maxChunkChars) {
		if strings.TrimSpace(c) == "" {
			continue
		}
		if err := synth(c, in); err != nil {
			notifyErr("synth-error")
			break
		}
	}
	in.Close()
	aplay.Wait()
}

func mainMode() {
	f, err := os.OpenFile(mainLock, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	if syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		return
	}
	if data, err := os.ReadFile(lockFile); err == nil {
		if pgid, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil && pgid > 0 {
			syscall.Kill(-pgid, syscall.SIGTERM)
		}
		os.Remove(lockFile)
		return
	}
	text, _ := exec.Command("wl-paste", "--primary", "--no-newline").Output()
	if len(text) == 0 {
		types, _ := exec.Command("wl-paste", "--list-types").Output()
		ts := string(types)
		if !strings.Contains(ts, "image/") && !strings.Contains(ts, "video/") && !strings.Contains(ts, "audio/") {
			saved, _ := exec.Command("wl-paste", "--no-newline").Output()
			exec.Command("wl-copy", "--clear").Run()
			exec.Command("ydotool", "key", "56:0", "100:0", "125:0", "126:0", "42:0", "54:0", "29:1", "46:1", "46:0", "29:0").Run()
			time.Sleep(selectionSleep)
			text, _ = exec.Command("wl-paste", "--no-newline").Output()
			if len(saved) > 0 {
				cmd := exec.Command("wl-copy")
				cmd.Stdin = bytes.NewReader(saved)
				cmd.Run()
			} else {
				exec.Command("wl-copy", "--clear").Run()
			}
		}
	}
	if len(text) == 0 {
		return
	}
	if len(text) > maxChars {
		notifyErr("Over max character count")
		text = text[:maxChars]
	}
	cmd := exec.Command(os.Args[0], "--run")
	cmd.Env = append(os.Environ(), "TTS_TEXT="+string(text))
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	devNull, _ := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = devNull, devNull, devNull
	cmd.Start()
	cmd.Process.Release()
	devNull.Close()
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--run" {
		runMode()
		return
	}
	mainMode()
}
