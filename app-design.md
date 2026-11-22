# IMP-VISION — companion app design

Banked 2026-11-19 (project direction: "we should design an app for it too").
The concept already ruled the UI is the main part of the product;
this is that UI, designed. Android first (native, llama.cpp +
whisper.cpp as bundled native libs, ONNX Runtime for Piper);
iOS is a later fork, out of scope for v1.

## The one-screen rule

Every screen has exactly one primary action, in words a first-time
buyer understands without a manual — the Deadbug quality bar. If a
feature needs instructions, it gets redesigned or cut.

## Screens

### 1. Home
Glasses status at a glance: connected or not, variant detected
(S/U/P/T/R), battery, which senses are live. One big **Ask** button.
Sense toggles as plain chips: Camera · Night · Thermal. Current
model set named ("Balanced set") with a swap shortcut. This is the
screen the glasses wake into.

### 2. Ask
Voice-first. Push-to-talk on screen or from the temple button; live
transcript as you speak; the answer as a card — and the same card
pushed to the HUD on display variants. When the question needs
eyes ("what's this?", "read that sign"), the app pulls a camera or
thermal frame automatically and says so on the card ("Answered from
the camera"). No mode-switching by the user, ever.

### 3. Senses
The live feeds: camera, night vision, thermal (false-colour), each
full-screen capable, each with **Ask about this** attached. Plus
the compass: a heading ribbon (in the HUD on display variants, a
card here), tilt-compensated from the 9-axis IMU, declination from
GPS, with destination bearing and a plain "heading unreliable"
state when the magnetic field is disturbed.

**IR source watch** (added 2026-11-20): passive detection of
active infrared emitters in view — camera night-vision arrays,
standalone illuminators, remote controls, baby monitors. It runs
on the phone over the night feed: the no-IR-cut camera renders
850 nm arrays as bright saturated clusters (940 nm dimmer);
cluster detection draws the box, and geometry plus a thermal
cross-check produce the classification — an LED ring around a
warm centre reads camera-type, a lone hot panel reads
illuminator. Every label is emitter-first — "IR emitter ·
camera-type pattern · 82%" — never a bare "camera found": a
camera with its IR off emits nothing and is invisible to this,
and the feature's empty state says exactly that. Display
variants get the box and label in the HUD, with a bearing tick
on the compass ribbon when the source sits off-axis; audio-only
variants get a spoken cue ("IR source, camera-type, thirty
degrees left") and the card here. A box or card opens the detail
card: visible-feed snapshot, classification + confidence,
bearing, first-seen time, thermal thumbnail. Detections join
the session log like every other reading. Sessions
record like SPECTRE sessions — timestamped feeds and readings,
saved on the phone, exportable. Measure-and-record posture
throughout: the app shows what the sensors see, it does not dress
readings up as detections.

### 4. Models
The picker — the heart of the product. Four role slots: **Eyes /
Brain / Ears / Voice**, each showing its current model, size, and
license. Three ways in:
- **Sets** — Light / Balanced / Max, one tap, RAM-checked as a
  group (hf-model-sets.md). Balanced is the shipped default.
- **Browse** — the scanned catalog (hf-model-lists.md), searchable,
  filtered per role, every entry with size + license before download.
- **Paste a repo** — any Hugging Face repo name; the checks run
  live and answer in plain language: format OK or not, projector
  found or missing, fits or too big, license named. Fail = the
  reason, not an error code.
Storage manager underneath: what's downloaded, what it weighs,
delete to reclaim space. The owner's own repos (Devilishcode)
appear in Browse like anyone else's.

### 5. HUD (display variants only)
Live preview of the lens window. Pin/unpin elements (status strip,
card, sense thumbnail), brightness, gesture tuning (nod / shake /
tilt sensitivity with a test pad), and the phone-as-trackpad mirror
mode. What you set here is what the glasses show — same layout,
same positions.

### 6. Pair IMP (T / R variants)
Pair with an IMP-1 / IMP-2. In terminal mode the IMP's live
readouts (Sub-GHz, NFC, IR) stream to the HUD card and the app
session log, merged with the glasses' own sense feeds — one
timeline for the whole toolkit.

### 7. Settings
Deliberately short. Data stays on the phone (stated, and true —
models run locally, nothing is uploaded). Model storage location.
App updates. One item that is NOT a setting, listed so nobody
looks for it: the recording light is wired to the camera and
cannot be turned off.

## Modes

### Screen Control

A mode, not a screen (full spec: `SCREEN_CONTROL.md`). The
glasses become the input end of a remote for other screens —
TVs and streaming boxes on the owner's network, anything with
an IR eye through a paired IMP. Entry is deliberate: push-to-talk
"control the TV," or the **Control** chip on Home. Inside the
mode there is exactly one primary action — **drive the target**
— and the same motions drive the wearer's own HUD and the TV:
head moves the pointer, temple tap selects, nod confirms, shake
goes back, voice does search and text. The phone is the
translator; the glasses send input events only and learn nothing
about TVs. Display variants see the target's name and the last
action in the status strip; audio-only variants get the honest
subset — voice first, gesture keys with a spoken echo, no cursor
promised. Exit is always one motion, and the mode announces
itself on entry and exit, so a tap is never ambiguous between
"select" and "photo."

## Design language

Tungsten Ash, same as the rest of the line: near-black grounds,
glass panels, titanium text, ochre for caution, red rationed to
the record light, the Ask button ring, and hazards. Big type,
thumb-reach primary actions, no hamburger menus.

## Architecture notes

- The phone does all thinking: llama.cpp (Eyes/Brain), whisper.cpp
  (Ears), ONNX Runtime (Voice). The glasses are peripherals —
  camera, mic, audio, controls, and on display variants a video
  pipe (USB-C DP alt-mode) plus BLE for everything else.
- Offline by default. The only network the app ever needs is the
  model download the user asked for.
- **The app ships before the hardware has to.** With no glasses
  paired, the phone's own camera and mic stand in for the senses —
  every screen works. The F Free prototype (and later the product)
  then lands as an input upgrade to an app people already have.
  Development order: Models + Ask first (works today, phone-only),
  Senses next, HUD and Pair IMP when their hardware exists.
