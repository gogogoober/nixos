# Speech-to-Text Model and Backend PRD

## Goal

Dictation on `surface-go-3` is inaccurate enough to be a chore. Find the most
accurate model that still answers fast enough to dictate into, given that this
host is a fanless 2c/4t Amber Lake-Y held at 5 W sustained on battery by
`modules.intelPowerLimit`. Larger memory footprint is acceptable if it buys
real accuracy.

## Current State

`modules/nixos/stt.nix` runs `whisper-server` from `pkgs.whisper-cpp` (CPU
build, 1.8.4) with `ggml-tiny.en` at 2 threads, silero VAD, `-mc 0`, `-sns`,
`-nt`. The model is pinned **inside the module**, so both hosts get tiny.en
regardless of what their hardware could carry. `dell-old` has a fan.

Three things in that config are worth calling out before any model change:

- **`-mc 0` silently disables `--prompt`.** Max-context zero drops the initial
  prompt tokens along with the carry-over context, so the one lever that fixes
  domain vocabulary is currently switched off.
- **The encoder always processes a 30 s window.** A 6 s dictation costs the
  same as a 25 s one. `audio_ctx` sized to the clip is the fix, and
  `whisper-server` accepts it per request.
- **The model pin violates the host-owns-values rule.** The comment on
  `settings.modelUrl` even names the Surface, inside a module `dell-old` also
  imports.

## What Was Measured

All on `surface-go-3`, on battery, `power-saver` (5 W sustained RAPL), 2
threads, greedy sampling to match the daemon, against two clips: `jfk.wav`
(11 s, real speech) and a 20 s piper-synthesised clip full of this repo's
vocabulary. Whisper figures are wall time including a ~0.3 s model load;
sherpa-onnx figures are inference only.

Absolute numbers drift up to 2x with thermal state, so only compare rows
measured in the same pass. The ordering was stable across passes.

### CPU, the current backend

| Model | 11 s clip | 20 s clip | Peak RSS | On disk |
| --- | --- | --- | --- | --- |
| `tiny.en` (current) | 5.4–8.2 s | 5.8–10.7 s | 152 MB | 75 MB |
| `base.en` | 14.8 s | 12.3–16.3 s | 245 MB | 142 MB |
| `small.en-q5_1` | 62.5 s | 55.6 s | 354 MB | 182 MB |

Whisper's cost is encoder-bound on this chip, and the encoder is the part
distillation does not shrink. That rules out `distil-small.en`,
`distil-large-v3` and `large-v3-turbo` as CPU options here: they all cut
decoder layers and keep a full-size encoder.

### Vulkan on the iGPU, the same models

`pkgs.whisper-cpp-vulkan` finds the UHD 615 through Mesa ANV with no config
change; `hardware.graphics` is already up for the desktop and the user is
already in `video`. Closure grows 54 MB because mesa and vulkan-loader are
shared with the session.

| Model | 20 s clip, CPU | 20 s clip, Vulkan | Peak host RSS |
| --- | --- | --- | --- |
| `tiny.en` | 5.8 s | — | 153 MB |
| `base.en` | 12.3–16.3 s | **4.3–5.1 s** | 113 MB |
| `small.en` fp32 | not measured | **11.3 s** | 141 MB |
| `small.en-q5_1` | 55.6 s | **10.5 s** | 92 MB |
| `medium.en-q5_0` | not measured | 30.4 s | 101 MB |
| `large-v3-turbo-q5_0` | not measured | 70.2 s, garbage out | 149 MB |
| `large-v3-turbo` fp16 | not measured | 52.0 s | 202 MB |

Transcripts were identical to the CPU runs for `base.en` and both `small.en`
builds. `large-v3-turbo-q5_0` is out on both counts: it took 70 s and returned
`Gسнаком situ啊,еп Bever valu ev law TERM6`. The fp16 turbo decodes cleanly, so
the fault is that model's q5_0 conversion rather than quantisation in general —
`medium.en-q5_0` is fine. Host RSS drops on the working models because the
weights live in GPU-shared memory rather than the process.

Whisper stops paying above `small.en` here. `medium.en` costs three times the
latency and recovered one more word (`Piper daemon`); fp16 turbo costs five
times and did worse, hearing `flake` as `flag` where `small.en` did not.

Both paths draw from the same 5 W package cap, so time to finish is a direct
proxy for energy per dictation. Vulkan `base.en` is both faster and more
accurate than the CPU `tiny.en` running today.

### sherpa-onnx, a different architecture

`pkgs.sherpa-onnx` (1.12.38) runs NVIDIA's Parakeet and Useful Sensors'
Moonshine. Parakeet is a 600M-parameter transducer, int8, English, with
punctuation and casing, CC-BY-4.0.

| Model | 11 s clip | 20 s clip | Peak RSS | On disk |
| --- | --- | --- | --- | --- |
| `moonshine-base-en-int8` | 1.8 s | 5.8 s | 462–585 MB | 114 MB |
| `parakeet-unified-en-0.6b-int8` | 5.4 s | 9.5 s | 1.02–1.13 GB | 630 MB |

Parakeet is faster than CPU `tiny.en` on this machine despite being eight
times the parameters, because a conformer encoder scales with actual audio
length instead of padding to 30 s. Python bindings exist
(`python3Packages.sherpa-onnx`) and load the model in 11.3 s, which a resident
daemon pays once.

### Accuracy on the vocabulary clip

The reference text contains `NixOS`, `home-manager`, `Hyprland`, `systemd`,
`piper`, `lessac`.

| Model | What came out |
| --- | --- |
| `tiny.en` | NYXOS, hyperlink e-bines, SystemD, Piper Demon, less-ac |
| `base.en` | Nix OS, hypele and keybinds, system D, Piper Demon, Lesac |
| `small.en-q5_1` | Nix OS, Hypo and Keybinds, SystemD, Piper Demon, LASAC |
| `moonshine-base` | NICSOS, hyperlink keybinds, systemd, piper demon, less ac |
| **parakeet** | **NixOS, Home Manager, Hyperland, systemd, Piper daemon**, LESAC |
| `tiny.en` + prompt, `-mc 224` | nixOS, Hypraland, systemd, lessac |

Two findings sit in that table. Whisper does not learn these words by growing:
`small.en` is no better than `base.en` on them. And an initial prompt on the
*smallest* model recovers most of them for 0.13 s, which the deployed `-mc 0`
currently makes impossible.

Separately, `audio_ctx` on `base.en` over the 20 s clip: default 1500 took
12.3 s, a clip-matched 1152 took 9.2 s with byte-identical output, and an
undersized 768 took 29.3 s and collapsed into a repetition loop. Sized per
clip it is free speed; fixed too low it is a bug.

### The prompt, retested on `small.en`

The garbled clause the prompt produced on `tiny.en` did not reappear. On
`small.en` over Vulkan:

| Run | Result |
| --- | --- |
| `-mc 0`, no prompt | Nix OS **flag**, **Hypo and Keybinds**, SystemD, Piper **Demon**, **Lesak** |
| `-mc 224` + prompt | nixOS **flake**, **Hyprland keybinds**, systemd, piper **daemon**, **lessac** |
| `-mc 224`, no prompt | byte-identical to `-mc 0` — the context setting alone changes nothing |
| JFK clip, `-mc 224` + prompt | byte-identical to no prompt — ordinary speech is untouched |

Cost was 0.25 s. This closes most of the vocabulary gap that was the main
argument for Parakeet.

## References

- **whisper.cpp model list** — https://huggingface.co/ggerganov/whisper.cpp
- **whisper-server request params** — accepts `audio_ctx`, `prompt`,
  `carry_initial_prompt`, `beam_size`, `best_of`, `max_context` per request as
  multipart fields, so the Go client can set them without a daemon restart
- **sherpa-onnx pretrained models** —
  https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html
- **Parakeet unified-en 0.6b int8** —
  `sherpa-onnx-nemo-parakeet-unified-en-0.6b-int8-non-streaming.tar.bz2` from
  the sherpa-onnx `asr-models` release, CC-BY-4.0
- **Moonshine** — 58 MB base.en, roughly whisper `base.en` accuracy at a third
  the latency; not enough of an accuracy jump to be worth a backend change

## Proposed Changes

### Phase 1 — Vulkan, a bigger model, and the two config bugs

1. Swap `pkgs.whisper-cpp` for `pkgs.whisper-cpp-vulkan` in the systemd unit.
2. Move the model pin out of the module. Add `modules.stt.model` as
   `{ url, hash }` with **no default**, so each host states its own, and
   `modules.stt.threads` likewise.
3. `surface-go-3` takes `small.en`; `dell-old` takes `small.en` or better once
   its numbers are taken on the box.
4. Drop `-mc 0` in favour of a small non-zero max-context, and add a
   `--prompt` naming this machine's vocabulary. Keep the hallucination guard by
   leaving `-sns` on and relying on VAD.
5. Have `dictate` compute `audio_ctx` from the recorded WAV length as
   `(seconds / 30) * 1500 + 128`, rounded up to a multiple of 64 and clamped to
   1500, and send it as a form field.

### Phase 2 — only if proper nouns still annoy

Swap the backend to sherpa-onnx with Parakeet. It needs a small resident HTTP
shim over `python3Packages.sherpa-onnx` exposing the same `/inference` path, so
the Go client does not change. Costs about 1.1 GB resident and gives up the
iGPU offload, and buys correct casing, punctuation, and most of the vocabulary.

## Target Files

- `modules/nixos/stt.nix` — package swap, host-owned model and threads, prompt
  and max-context change
- `modules/nixos/scripts/dictate/main.go` — `audio_ctx` form field
- `hosts/surface-go-3/default.nix` — model, threads, prompt vocabulary
- `hosts/dell-old/default.nix` — the same, with its own values
- `docs/hosts/surface-go-3.md` — the Speech section currently says tiny.en at
  2 threads and "bump to base.en only if accuracy becomes a problem"

## Decisions to Confirm

- **`small.en` or `base.en` on the Surface.** base.en on Vulkan is 4.3 s and
  strictly better than today in both speed and accuracy. small.en is 11.3 s for
  a further accuracy step that the vocabulary table suggests is small.
- **Whether the iGPU stutters the session.** The compositor shares that GPU and
  that 5 W budget. Needs a day of real use to judge.
- **Whether Phase 2 is worth a python daemon.** It is the only option measured
  that gets proper nouns, casing and punctuation right.

## Hashes, ready to pin

Same `https://huggingface.co/ggerganov/whisper.cpp/resolve/main` base URL the
module already uses.

```
ggml-base.en.bin        sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=
ggml-small.en.bin       sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=
ggml-small.en-q5_1.bin  sha256-v9/0iU3Ldrv2R9ViY+oqlmRUI/FmkXb0hEob+OR4rTA=
```

## Status

**Phase 1 implemented**, 2026-09-14, as generation 44. Built to the shape agreed
in conversation rather than the one proposed above: the enum owns the engine
*and* the model size, so a host says `engine = "whisper-small"` and nothing
else about the model. Splitting engine from model name was rejected as
mix-and-match complexity for little gain.

Delivered:

- `modules.stt.engine`, an enum whose single member today is `whisper-small`,
  with no default so each host states its own
- `modules.stt.threads`, host-owned; 2 on the Surface, 4 on the Dell
- `pkgs.whisper-cpp-vulkan` unconditionally, with its automatic CPU fallback
  instead of a module option
- `-mc 224` and the vocabulary prompt, verified clean on `small.en` first

Deliberately not done: the per-recording `audio_ctx` sizing in the Go client.
It is a separate change with a sharp edge and it is not what was hurting
accuracy. The numbers above stand if it is ever wanted.

Phase 2, Parakeet, is not started. It would arrive as a second member of the
same enum.
