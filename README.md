# imp-vision

IMP-VISION — Deadbug Labs AI smart glasses: real thermal imaging + night vision, phone-linked. Temple board, firmware, and app.

The glasses connect to a phone and nothing else — no hub, no cloud account, no builder-supplied parts. Complete glasses in the box; the phone app is where the AI experience lives.

## What it sees

- **Thermal imaging** — a FLIR Lepton-class 160×120 radiometric core on the full-sense build. Real heat signatures, not blobs.
- **Night vision** — a no-IR-cut camera with 940 nm illuminators that emit no visible glow.
- **IR Source Watch** — passive detection of other active IR emitters (camera night-vision arrays, illuminators), labelled with classification and confidence.
- **Camera + microphone** — with a recording LED that is hardwired to the camera: no firmware path can light the camera without lighting the LED.

## Your models, your pick

The app takes any compatible Hugging Face model per role — Eyes, Brain, Ears, Voice — GGUF with mmproj for vision, sized to your phone, license shown before download. Defaults are preselected; the picker is open. Model sets: [Devilishcode/imp-vision-model-sets](https://huggingface.co/Devilishcode/imp-vision-model-sets)

## Status — 2026-11-21

- Temple board (ESP32-S3): routing at 50 unconnected nets, 0 shorts. Not DRC-clean, not fab-ready; a placement respin is the next step.
- Temple firmware v0: compiles clean. The firmware is a dumb pipe — the phone does the thinking.
- Phone app: v0.10.3 — glasses link layer, IR Watch, and a thermal preview surface all working against the phone camera.
- Display variants: in evaluation. The base build is audio-first, no display.

## Design documents

- [app-design.md](app-design.md) — the companion app: voice-first UI, senses, model picker
- [INTEGRATION.md](INTEGRATION.md) — how the temple board, frames, and sensors fit together
- [RING_DESIGN.md](RING_DESIGN.md) — the BLE scroll + click ring
- [INPUT_SOURCES.md](INPUT_SOURCES.md) — ring, mouse, and other input classes
- [PAIR_IMP_PROTOCOL.md](PAIR_IMP_PROTOCOL.md) — how the glasses pair with an IMP-1, and the hard limits on what they may ask it to do
- [SCREEN_CONTROL.md](SCREEN_CONTROL.md) — the display control model for display variants

Deadbug Labs — boards and devices for people who build. https://deadbuglabs.github.io/
