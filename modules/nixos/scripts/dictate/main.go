// Press to record, press again to stop. Transcribes via whisper-server,
// types into focus and copies to clipboard.
package main

import (
	"bytes"
	"cmp"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	whisperHost = "127.0.0.1"
	whisperPort = "5175"
	maxSeconds  = 300
	minMillis   = 800
	httpTimeout = 5 * time.Minute
)

var rt = cmp.Or(os.Getenv("XDG_RUNTIME_DIR"), "/tmp")
var pgidLock = filepath.Join(rt, "dictate.pgid")
var mainLock = filepath.Join(rt, "dictate.main.lock")

func notify(label string, critical bool) {
	args := []string{"-t", "2000", "-a", "dictate"}
	if critical {
		args = append(args, "-u", "critical", "-t", "4000")
	}
	args = append(args, label)
	exec.Command("notify-send", args...).Run()
}

func transcribe(wavPath string) (string, error) {
	f, err := os.Open(wavPath)
	if err != nil {
		return "", err
	}
	defer f.Close()

	body := &bytes.Buffer{}
	w := multipart.NewWriter(body)
	fw, _ := w.CreateFormFile("file", "audio.wav")
	if _, err := io.Copy(fw, f); err != nil {
		return "", err
	}
	w.WriteField("response_format", "text")
	w.Close()

	req, _ := http.NewRequest("POST", "http://"+whisperHost+":"+whisperPort+"/inference", body)
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := (&http.Client{Timeout: httpTimeout}).Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("status %d", resp.StatusCode)
	}
	out, err := io.ReadAll(resp.Body)
	return strings.TrimSpace(string(out)), err
}

// Clipboard is the safety net; wtype is the best-effort auto-paste.
func deliver(text string) {
	cp := exec.Command("wl-copy")
	cp.Stdin = strings.NewReader(text)
	cp.Run()

	t := exec.Command("wtype", "-")
	t.Stdin = strings.NewReader(text)
	t.Run()
}

func recordMode() {
	pid := os.Getpid()
	pgid, _ := syscall.Getpgid(pid)
	os.WriteFile(pgidLock, []byte(strconv.Itoa(pgid)), 0600)

	wav := filepath.Join(rt, fmt.Sprintf("dictate-%d.wav", pid))

	cleanup := func() {
		if cur, err := os.ReadFile(pgidLock); err == nil && strings.TrimSpace(string(cur)) == strconv.Itoa(pgid) {
			os.Remove(pgidLock)
		}
		os.Remove(wav)
	}

	rec := exec.Command("parecord",
		"--rate=16000", "--channels=1", "--format=s16le",
		"--file-format=wav", wav)
	rec.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := rec.Start(); err != nil {
		cleanup()
		notify("dictate: parecord failed", true)
		return
	}

	notify("dictate: recording", false)

	started := time.Now()
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	timer := time.AfterFunc(maxSeconds*time.Second, func() { sig <- syscall.SIGTERM })
	defer timer.Stop()

	<-sig
	rec.Process.Signal(syscall.SIGTERM)
	rec.Wait()

	if time.Since(started) < minMillis*time.Millisecond {
		cleanup()
		return
	}

	notify("dictate: transcribing", false)
	text, err := transcribe(wav)
	cleanup()

	if err != nil {
		notify("dictate: transcribe failed", true)
		return
	}
	if text == "" {
		notify("dictate: empty result", true)
		return
	}
	deliver(text)
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

	if data, err := os.ReadFile(pgidLock); err == nil {
		if pgid, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil && pgid > 0 {
			syscall.Kill(-pgid, syscall.SIGTERM)
		}
		return
	}

	cmd := exec.Command(os.Args[0], "--record")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	devNull, _ := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = devNull, devNull, devNull
	cmd.Start()
	cmd.Process.Release()
	devNull.Close()
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--record" {
		recordMode()
		return
	}
	mainMode()
}
