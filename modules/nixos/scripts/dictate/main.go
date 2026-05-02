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
	whisperHost          = "127.0.0.1"
	whisperPort          = "5175"
	maxSeconds           = 300
	minMillis            = 800
	httpTimeout          = 5 * time.Minute
	modifierReleaseDelay = 250 * time.Millisecond
)

var rt = cmp.Or(os.Getenv("XDG_RUNTIME_DIR"), "/tmp")
var stateHome = cmp.Or(os.Getenv("XDG_STATE_HOME"), filepath.Join(os.Getenv("HOME"), ".local/state"))
var pgidLock = filepath.Join(rt, "dictate.pgid")
var mainLock = filepath.Join(rt, "dictate.main.lock")
var statePath = filepath.Join(rt, "dictate.state")
var logDir = filepath.Join(stateHome, "dictate")
var logPath = filepath.Join(logDir, "dictate-"+time.Now().UTC().Format("2006-01-02")+".log")

const readyDuration = 3 * time.Second

func logf(label, format string, args ...any) {
	os.MkdirAll(logDir, 0700)
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	pid := os.Getpid()
	pgid, _ := syscall.Getpgid(pid)
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintf(f, "[%s] %-18s pid=%d pgid=%d %s\n",
		time.Now().Format("15:04:05.000"), label, pid, pgid, msg)
}

func notifyFail(label string) {
	exec.Command("notify-send", "-a", "dictate", "-u", "critical", "-t", "4000", label).Run()
}

func writeState(state string) {
	if state == "" {
		os.Remove(statePath)
	} else {
		os.WriteFile(statePath, []byte(state), 0600)
	}
	exec.Command("pkill", "-SIGRTMIN+10", "waybar").Run()
}

func transcribe(wavPath string) (string, error) {
	info, _ := os.Stat(wavPath)
	logf("TRANSCRIBE-start", "wav=%s bytes=%d", wavPath, info.Size())

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

	start := time.Now()
	resp, err := (&http.Client{Timeout: httpTimeout}).Do(req)
	if err != nil {
		logf("TRANSCRIBE-http-err", "%v", err)
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		logf("TRANSCRIBE-status", "status=%d", resp.StatusCode)
		return "", fmt.Errorf("status %d", resp.StatusCode)
	}
	out, err := io.ReadAll(resp.Body)
	logf("TRANSCRIBE-done", "elapsed=%s chars=%d", time.Since(start).Truncate(time.Millisecond), len(out))
	return strings.TrimSpace(string(out)), err
}

func deliver(text string) {
	cp := exec.Command("wl-copy")
	cp.Stdin = strings.NewReader(text)
	cpErr := cp.Run()
	logf("DELIVER-clip", "err=%v", cpErr)

	time.Sleep(modifierReleaseDelay)

	t := exec.Command("wtype", "-")
	t.Stdin = strings.NewReader(text)
	tErr := t.Run()
	logf("DELIVER-wtype", "err=%v", tErr)
}

func recordMode() {
	pid := os.Getpid()
	pgid, _ := syscall.Getpgid(pid)
	os.WriteFile(pgidLock, []byte(strconv.Itoa(pgid)), 0600)
	logf("RECORD-enter", "lock=%s", pgidLock)

	wav := filepath.Join(rt, fmt.Sprintf("dictate-%d.wav", pid))

	defer func() {
		if cur, err := os.ReadFile(pgidLock); err == nil && strings.TrimSpace(string(cur)) == strconv.Itoa(pgid) {
			os.Remove(pgidLock)
		}
		os.Remove(wav)
	}()

	rec := exec.Command("parecord",
		"--rate=16000", "--channels=1", "--format=s16le",
		"--file-format=wav", wav)
	rec.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := rec.Start(); err != nil {
		logf("RECORD-parecord-fail", "%v", err)
		notifyFail("dictate: parecord failed")
		return
	}
	logf("RECORD-parecord", "pid=%d wav=%s", rec.Process.Pid, wav)
	writeState("recording")

	started := time.Now()
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	timer := time.AfterFunc(maxSeconds*time.Second, func() {
		logf("RECORD-cap", "max=%ds", maxSeconds)
		sig <- syscall.SIGTERM
	})
	defer timer.Stop()

	<-sig
	rec.Process.Signal(syscall.SIGTERM)
	rec.Wait()
	elapsed := time.Since(started)
	logf("RECORD-stop", "elapsed=%s", elapsed.Truncate(time.Millisecond))

	if elapsed < minMillis*time.Millisecond {
		logf("RECORD-too-short", "min=%dms", minMillis)
		writeState("")
		notifyFail("dictate: too short")
		return
	}

	text, err := transcribe(wav)

	if err != nil {
		writeState("")
		notifyFail("dictate: transcribe failed")
		return
	}
	if text == "" {
		logf("RESULT-empty", "")
		writeState("")
		notifyFail("dictate: empty result")
		return
	}
	logf("RESULT", "chars=%d preview=%q", len(text), preview(text))
	deliver(text)

	writeState("ready")
	time.Sleep(readyDuration)
	if data, err := os.ReadFile(statePath); err == nil && strings.TrimSpace(string(data)) == "ready" {
		writeState("")
	}
}

func preview(s string) string {
	const cap = 60
	if len(s) <= cap {
		return s
	}
	return s[:cap] + "..."
}

func mainMode() {
	logf("MAIN-enter", "args=%v", os.Args)
	f, err := os.OpenFile(mainLock, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		logf("MAIN-lockfile-err", "%v", err)
		return
	}
	defer f.Close()
	if syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		logf("MAIN-flock-busy", "another instance running")
		return
	}

	if data, err := os.ReadFile(pgidLock); err == nil {
		pgid, _ := strconv.Atoi(strings.TrimSpace(string(data)))
		logf("MAIN-stopping", "target_pgid=%d", pgid)
		if pgid > 0 {
			syscall.Kill(-pgid, syscall.SIGTERM)
		}
		return
	}

	logf("MAIN-spawning", "")
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
