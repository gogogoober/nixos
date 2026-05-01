// 1-to-1 translation of speak-selection.sh; not wired into tts.nix.
package main

import (
	"bufio"
	"bytes"
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

var (
	piperHost            = envOr("PIPER_HOST", "127.0.0.1")
	piperPort            = envOr("PIPER_PORT", "5174")
	selectionSleep       = envFloat("SELECTION_SLEEP", 0.08)
	maxChars             = envInt("MAX_CHARS", 10000)
	maxChunkChars        = envInt("MAX_CHUNK_CHARS", 200)
	lockFile             = envOr("LOCK_FILE", filepath.Join(runtimeDir(), "speak-selection.pgid"))
	mainLock             = envOr("MAIN_LOCK", filepath.Join(runtimeDir(), "speak-selection.main.lock"))
	logDir               = envOr("LOG_DIR", filepath.Join(stateDir(), "speak-selection"))
	loggingEnabled       = envBool("LOGGING_ENABLED", false)
	notificationsEnabled = envBool("NOTIFICATIONS_ENABLED", false)

	debugLogPath = filepath.Join(logDir, "speak-selection-"+time.Now().UTC().Format("2006-01-02")+".log")
)

func envOr(k, d string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return d
}
func envInt(k string, d int) int {
	if v, ok := os.LookupEnv(k); ok {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return d
}
func envFloat(k string, d float64) float64 {
	if v, ok := os.LookupEnv(k); ok {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return d
}
func envBool(k string, d bool) bool {
	if v, ok := os.LookupEnv(k); ok {
		return v == "true"
	}
	return d
}
func runtimeDir() string {
	if v := os.Getenv("XDG_RUNTIME_DIR"); v != "" {
		return v
	}
	return "/tmp"
}
func stateDir() string {
	if v := os.Getenv("XDG_STATE_HOME"); v != "" {
		return v
	}
	return filepath.Join(os.Getenv("HOME"), ".local/state")
}

func logEvent(label, msg string) {
	if !loggingEnabled {
		return
	}
	pid := os.Getpid()
	pgid, _ := syscall.Getpgid(pid)
	line := fmt.Sprintf("[%s] %s pid=%d pgid=%d %s\n",
		time.Now().Format("15:04:05.000"), label, pid, pgid, msg)
	_ = os.MkdirAll(logDir, 0700)
	f, err := os.OpenFile(debugLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(line)
}

func sendNotification(label string, isError bool) {
	if isError {
		_ = exec.Command("notify-send", "-t", "3000", "-u", "critical",
			"-a", "speak-selection", label).Run()
		return
	}
	if !notificationsEnabled {
		return
	}
	_ = exec.Command("notify-send", "-t", "1500",
		"-a", "speak-selection", label).Run()
}

// Sanitization rules. Order matters; code-fence runs first, whitespace collapse last.
type sanitizeRule struct {
	name  string
	apply func(string) string
}

func reRule(name, pat, repl string) sanitizeRule {
	re := regexp.MustCompile(pat)
	return sanitizeRule{name: name, apply: func(s string) string {
		return re.ReplaceAllString(s, repl)
	}}
}

var codeFenceRule = sanitizeRule{
	name: "code-fence",
	apply: func(s string) string {
		parts := strings.Split(s, "```")
		var b strings.Builder
		for i, p := range parts {
			if i%2 == 0 {
				b.WriteString(p)
			} else {
				b.WriteString("Code Example.")
			}
		}
		return b.String()
	},
}

var sanitizeRules = []sanitizeRule{
	codeFenceRule,
	reRule("zwsp", `\x{200B}`, ""),
	reRule("zwnj", `\x{200C}`, ""),
	reRule("zwj", `\x{200D}`, ""),
	reRule("bom", `\x{FEFF}`, ""),
	reRule("emoji-smp", `[\x{1F000}-\x{1FFFF}]`, ""),
	reRule("emoji-misc-sym", `[\x{2600}-\x{27BF}]`, ""),
	reRule("emoji-var-sel", `\x{FE0F}`, ""),
	reRule("em-dash", `\x{2014}`, ", "),
	reRule("sq-left-double", `\x{201C}`, `"`),
	reRule("sq-right-double", `\x{201D}`, `"`),
	reRule("sq-left-single", `\x{2018}`, "'"),
	reRule("sq-right-single", `\x{2019}`, "'"),
	reRule("md-emphasis-asterisk", `\*+([^*]+)\*+`, `$1`),
	reRule("md-emphasis-underscore", `_+([^_]+)_+`, `$1`),
	reRule("md-heading-hash", `(?m)^#+[ \t]+`, ""),
	reRule("md-blockquote", `(?m)^>[ \t]+`, ""),
	reRule("url-path-collapse", `https?://([^/\s]+)\S*`, `$1`),
	reRule("collapse-whitespace", `\s+`, " "),
}

func sanitize(s string) string {
	for _, r := range sanitizeRules {
		s = r.apply(s)
	}
	return s
}

// splitIntoChunks mirrors the awk: pack words to cap, flush early after punctuation past 40 chars.
func splitIntoChunks(text string, cap int, out chan<- string) {
	defer close(out)
	var buf strings.Builder
	punctEnd := regexp.MustCompile(`[.!?,]$`)

	scanner := bufio.NewScanner(strings.NewReader(text))
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		for _, w := range strings.Fields(scanner.Text()) {
			var candidate string
			if buf.Len() == 0 {
				candidate = w
			} else {
				candidate = buf.String() + " " + w
			}
			if len(candidate) > cap && buf.Len() > 0 {
				out <- buf.String() + " "
				buf.Reset()
				buf.WriteString(w)
			} else {
				buf.Reset()
				buf.WriteString(candidate)
			}
			if punctEnd.MatchString(buf.String()) && buf.Len() >= 40 {
				out <- buf.String() + " "
				buf.Reset()
			}
		}
	}
	if buf.Len() > 0 {
		out <- buf.String() + " "
	}
}

func runMode() {
	text := os.Getenv("TTS_TEXT")
	_ = os.Unsetenv("TTS_TEXT")
	logEvent("RUN-enter", fmt.Sprintf("text_len=%d", len(text)))
	if text == "" {
		return
	}

	pid := os.Getpid()
	_ = os.WriteFile(lockFile, []byte(strconv.Itoa(pid)), 0600)
	logEvent("RUN-lockwritten", fmt.Sprintf("content=%d", pid))

	cleanup := func() {
		if cur, err := os.ReadFile(lockFile); err == nil &&
			strings.TrimSpace(string(cur)) == strconv.Itoa(pid) {
			_ = os.Remove(lockFile)
		}
	}
	defer cleanup()

	// Trap SIGTERM/SIGINT so the lock file is cleared when main kills the pgid.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-sigCh
		cleanup()
		os.Exit(0)
	}()

	text = sanitize(text)
	logEvent("SANITIZE-stats", fmt.Sprintf("len=%d", len(text)))
	logEvent("SANITIZE-output", text)

	if strings.TrimSpace(text) == "" {
		logEvent("SANITIZE-empty", "")
		return
	}

	sendNotification("processing-start", false)

	aplay := exec.Command("aplay", "-q", "-f", "S16_LE", "-r", "22050", "-c", "1")
	aplayIn, err := aplay.StdinPipe()
	if err != nil {
		logEvent("APLAY-error", err.Error())
		return
	}
	if err := aplay.Start(); err != nil {
		logEvent("APLAY-error", err.Error())
		return
	}

	chunks := make(chan string)
	go splitIntoChunks(text, maxChunkChars, chunks)

	failed := false
	for chunk := range chunks {
		if strings.TrimSpace(chunk) == "" {
			logEvent("CHUNK-skip-empty", "")
			continue
		}
		logEvent("CHUNK-emit", fmt.Sprintf("len=%d text=%s", len(chunk), chunk))
		if err := synthChunk(chunk, aplayIn); err != nil {
			logEvent("SYNTH-error", "chunk_failed")
			sendNotification("synth-error", true)
			failed = true
			break
		}
	}
	_ = aplayIn.Close()
	_ = aplay.Wait()

	if !failed {
		logEvent("PIPELINE-finished", "")
		sendNotification("processing-end", false)
	}
}

func synthChunk(text string, w io.Writer) error {
	body, err := json.Marshal(map[string]string{"text": text})
	if err != nil {
		return err
	}
	req, err := http.NewRequest("POST",
		fmt.Sprintf("http://%s:%s/", piperHost, piperPort),
		bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("piper status %d", resp.StatusCode)
	}

	// Skip the 44-byte WAV header (matches `tail -c +45`).
	if _, err := io.CopyN(io.Discard, resp.Body, 44); err != nil {
		return err
	}
	_, err = io.Copy(w, resp.Body)
	return err
}

func mainMode() {
	logEvent("MAIN-enter", "args="+strings.Join(os.Args[1:], " "))

	f, err := os.OpenFile(mainLock, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		logEvent("MAIN-flock-open-failed", err.Error())
		return
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		logEvent("MAIN-flock-failed", "another main flow is already running")
		return
	}
	logEvent("MAIN-flock-acquired", "")

	// 1. Reader in flight → stop and exit (press-again-to-stop).
	if data, err := os.ReadFile(lockFile); err == nil {
		oldPgid := strings.TrimSpace(string(data))
		logEvent("MAIN-stopping", "old_pgid="+oldPgid)
		if pgid, err := strconv.Atoi(oldPgid); err == nil && pgid > 0 {
			_ = syscall.Kill(-pgid, syscall.SIGTERM)
		}
		sendNotification("cancelled", false)
		_ = os.Remove(lockFile)
		return
	}
	logEvent("MAIN-no-reader", "LOCK_FILE absent")

	// 2. Capture selection. PRIMARY first to skip synth Ctrl+C where possible.
	text := wlPastePrimary()
	if text == "" {
		clipTypes := wlPasteListTypes()
		if !hasMediaType(clipTypes) {
			saved := wlPasteRegular()
			wlCopyClear()
			ydotoolCtrlC()
			time.Sleep(time.Duration(selectionSleep * float64(time.Second)))
			text = wlPasteRegular()
			if saved != "" {
				wlCopyText(saved)
			} else {
				wlCopyClear()
			}
		}
	}

	if text == "" {
		return
	}

	// 3. Cap to avoid queuing 20 minutes of audio on accidental whole-page selections.
	if len(text) > maxChars {
		logEvent("SELECTION-truncated",
			fmt.Sprintf("from=%d to=%d", len(text), maxChars))
		sendNotification("Over max character count", true)
		text = text[:maxChars]
	}

	// 4. Hand off via detached re-exec; env keeps text out of /proc/<pid>/cmdline.
	logEvent("MAIN-spawning", fmt.Sprintf("text_len=%d", len(text)))
	spawnReader(text)
	logEvent("MAIN-spawned", "")
}

func spawnReader(text string) {
	cmd := exec.Command(os.Args[0], "--run")
	cmd.Env = append(os.Environ(), "TTS_TEXT="+text)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	devNull, _ := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if devNull != nil {
		defer devNull.Close()
		cmd.Stdin, cmd.Stdout, cmd.Stderr = devNull, devNull, devNull
	}
	if err := cmd.Start(); err == nil {
		_ = cmd.Process.Release()
	}
}

func wlPastePrimary() string {
	out, _ := exec.Command("wl-paste", "--primary", "--no-newline").Output()
	return string(out)
}
func wlPasteRegular() string {
	out, _ := exec.Command("wl-paste", "--no-newline").Output()
	return string(out)
}
func wlPasteListTypes() string {
	out, _ := exec.Command("wl-paste", "--list-types").Output()
	return string(out)
}
func wlCopyClear() {
	_ = exec.Command("wl-copy", "--clear").Run()
}
func wlCopyText(s string) {
	cmd := exec.Command("wl-copy")
	cmd.Stdin = strings.NewReader(s)
	_ = cmd.Run()
}
func hasMediaType(s string) bool {
	return strings.Contains(s, "image/") ||
		strings.Contains(s, "video/") ||
		strings.Contains(s, "audio/")
}

// 56=LEFTALT 100=RIGHTALT 125=LEFTMETA 126=RIGHTMETA 42=LEFTSHIFT 54=RIGHTSHIFT 29=LEFTCTRL 46=C
func ydotoolCtrlC() {
	_ = exec.Command("ydotool", "key",
		"56:0", "100:0", "125:0", "126:0", "42:0", "54:0",
		"29:1", "46:1", "46:0", "29:0").Run()
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--run" {
		runMode()
		return
	}
	mainMode()
}
