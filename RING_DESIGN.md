# The Deadbug Ring — design (2026-11-20)

Status: **design, not hardware.** An IMP-VISION accessory and a
Deadbug Labs board product in its own right. Deadbug Labs ruled the
interaction model 2026-11-20: **scroll + click, less is better.**
This doc works that ruling out against the ring's role in
`INPUT_SOURCES.md` (§1: BLE HID to the phone, never to the
glasses) and the confirm principle (`INPUT_SOURCES.md` §4 — a
confirmation is a discrete physical act; this ring exists to be
that act).

Conventions mirror the other specs: requirements are numbered
`RG-<BLOCK>-<nn>`; an item marked **OPEN** carries a default,
and the default governs unless overruled. Genuinely
the founder's items are collected in §6.

**The one-sentence version:** one board, one battery arc, one
rocker that scrolls in steps and one dome that clicks — a stock
BLE HID device that needs no app to be useful, and that the
IMP-VISION app treats as its reference ring.

## 1. Interaction model — scroll + click, nothing else

- RG-IN-01 — **Two controls total.** A two-way rocking scroll
  paddle and one click dome. No trackpad, no second button, no
  gesture surface. Every function below is a combination of
  step, hold, click, long-press, double-click.
- RG-IN-02 — **Scroll is steps, not a stream.** Each paddle tap
  = one scroll step (one HID wheel detent, or one D-pad step —
  the phone picks the dialect from the target, per IN-HID-03).
  Hold = auto-repeat, accelerating (4 steps/s ramping to
  20 steps/s after 1 s). Steps are discrete events the wearer
  can count blind; the app's spoken/HUD echo (Screen Control)
  closes the loop on audio-only variants.
- RG-IN-03 — **Click mapping (profile of record):** click =
  select / confirm; double-click = back; long-press (≥600 ms)
  = dismiss. This is the IN-HID-03 ring mapping with the
  second-button functions folded onto one dome, as the
  scroll + click ruling requires.

### Scroll mechanism — the honest comparison

| | (a) Micro rotary encoder | (b) Capacitive scroll band | (c) Mini trackball / bead | (d) Rocker / tilt paddle |
|---|---|---|---|---|
| Reference size | Bourns PEC09 class: 9.7 mm body, Ø6 mm shaft, 11.4 mm tall | Electrodes are flex traces: +0.1–0.2 mm on the band | Smallest catalog module (Pimoroni): 25 × 22 × 9.5 mm | 2 dome switches under a paddle: ~8 × 5 × 2.6 mm stack |
| Gloved hands | ✓ works | ✗ fails on most gloves | ✓ works | ✓ works |
| Wet hands / rain | ✓ (but IP40, grit ingress) | ✗ slide tracking degrades; water rejection helps buttons, not slides | ~ ball slips, well collects water | ✓ sealed domes, no openings |
| Blind one-handed use | ✓ best detents | ~ no tactile steps; relies on app echo | ~ ball position is unknowable blind | ✓ countable steps, distinct ends |
| Durability | 30k cycles min (PEC09); exposed shaft | No moving parts — best in class | Ball + rollers foul; worst in class | 100k+ cycles per dome; fully sealable |
| Idle power | 0 | ~1–3 µA (ULP wake, Azoteq IQS7222A class) | mA-class optical while moving | 0 |
| Thickness cost | Forces a ≥12 mm pod — a knob on a ring | Thinnest possible | Larger than the entire pod | Fits the pod slope |

- RG-IN-04 — **Primary: (d) the rocker paddle.** It is the only
  mechanism that passes every stated field condition at once:
  gloves, rain, blind counting, sealed construction, zero idle
  power, and a thickness a ring can carry. Its one honest
  weakness — scroll is rate-based on hold rather than
  positional — is mitigated by RG-IN-02's step counting and
  costs nothing in the D-pad dialect, where steps are native.
- RG-IN-05 — **Runner-up: (b) the capacitive band** (Azoteq
  IQS7222A class: 3 × 3 mm QFN, slider on flex electrodes, ULP
  wake). Thinnest and the most durable mechanism that exists —
  and the pick for any future dress variant. Rejected as
  primary on one ground: it fails the glove case, and this
  product is a field controller for glasses whose headline
  senses are night and thermal. (a) is rejected on size — the
  smallest catalog encoder is a panel part, not a ring part —
  and (c) on size alone: its smallest module is bigger than
  this ring's whole pod.

### The click

- RG-IN-06 — **A real tactile switch, never a touch surface.**
  The click is the confirm channel (IN-CFM-01); it must be
  feelable through a glove and unmissable blind. Metal snap
  dome, Ø6 mm class (or Alps SKST-class tact), under the pod's
  top face:
  - Actuation force: **2.0–2.6 N (200–260 gf)** — firm enough
    that a resting thumb never fires it, light enough for a
    deliberate press through a winter glove.
  - Travel: **0.25–0.4 mm with a snap** — the snap *is* the
    confirmation feedback; force drop at actuation ≥40%.
  - Life: ≥100k actuations; sealed under the pod cap (no
    exposed mechanism).

## 2. Electronics

### SoC — compared

| | nRF52810 (bare) | nRF52811 (bare) | ESP32-C3 (module) | Pre-cert module (Raytac MDBT42Q, nRF52832) |
|---|---|---|---|---|
| Footprint | QFN32 5 × 5 mm (WLCSP 2.5 × 2.5 exists) | QFN32 5 × 5 mm | MINI-1 module 13.2 × 16.6 mm | 16 × 10 × 2.2 mm, chip antenna fitted |
| Sleep | 0.3 µA System OFF; 1.5 µA System ON + RTC | 0.3 µA OFF; 1.1 µA ON + RTC, full RAM | 5 µA deep sleep; **130 µA light sleep** (the connected-idle floor) | Same silicon class as 52810 |
| Radio draw | 4.6 mA TX/RX @ 0 dBm | 4.6 mA | BLE peaks in the 100 mA class; Wi-Fi radio is dead weight | 5.3 mA @ 0 dBm |
| Cost qty-1 | **$3.66** (DigiKey, QCAA) | ~$3.7 (est., same class) | $3.26 (DigiKey, MINI-1) | $4.95 (DigiKey Marketplace) |
| Cost qty-100 | **$2.75** (DigiKey) | ~$2.8 (est.) | $2.45 (DigiKey) | ~$4.50 (est.) |
| Certification | On us (intentional radiator) | On us | Module pre-certified | **Module pre-certified (FCC/CE/Telec)** |

- RG-EL-01 — **Pick: nRF52810-QCAA.** A HID peripheral is the
  workload the nRF52 sleep architecture exists for: connected
  idle at a 1 s connection interval averages in the low tens of
  µA, where the C3's 130 µA light-sleep floor caps standby at
  ~2 weeks before its radio does anything. The C3 module is
  also 13 × 17 mm — it would *be* the pod. The 52811 buys
  direction-finding and Thread this product will never use.
- RG-EL-02 — **Staged RF plan.** EVT/first articles build on
  the Raytac MDBT42Q (pre-certified, antenna fitted, $4.95) to
  prove the product with zero RF risk; the production respin
  goes bare 52810 + chip antenna and takes the certification.
  Deadbug is a board company — the bare-SoC board is the
  product; the module is scaffolding, and the BOM delta
  (~$1.30/unit) funds the respin at qty-100 already.
- RG-EL-03 — **Board outline:** rigid pod PCB **16 × 11 ×
  1.0 mm**, rigid-flex tail carrying the two rocker domes, the
  battery leads, and the charge contacts around the band arc.
  One board serves every ring size (§3) — size lives in the
  band, never in the electronics.
- RG-EL-04 — **Antenna in a metal-adjacent, skin-adjacent
  wearable.** Chip antenna (2450 MHz ceramic class) at the
  pod's outer end, keep-out honoured on both faces, ground
  pour pulled back under it. Worn on a finger, the antenna sits
  against skin and loses on the order of 10 dB (est.) — the
  design answer is margin, not power: the link budget only has
  to reach a phone in a pocket ≤2 m away, the nRF52810 hears
  −96 dBm, and TX runs 0 dBm default with +4 dBm available.
  No metal band in v1 (§3) — a metal shell over the pod end
  would eat the antenna; if a metal variant ever happens, the
  pod cap stays polymer and becomes the RF window.

### Battery

| | LiPo pouch (picked) | Coin cell CR2032 |
|---|---|---|
| Capacity in this form | ~55 mAh (401020-class arc segment) | 220–240 mAh |
| Thickness | 4.0 mm cell, wraps the band arc | 3.2 mm + holder ≈ 4.5 mm, one hard lump |
| Rechargeable | ✓ USB-C, ~2 h at 0.5 C | ✗ — a door, a consumable, a dead ring in the field |
| Pulse behaviour | BLE pulses are nothing to it | Voltage droop under TX pulses; needs a reservoir cap |

- RG-EL-05 — **LiPo pouch, USB-C charging** (MCP73831-class
  charge IC, 0.5 C ≈ 27 mA). USB-C receptacle on the pod's
  underside face — plugged in off-finger, on the nightstand;
  a tethered dust plug keeps the port sealed in the field.
- RG-EL-06 — **Runtime math** (estimates, from datasheet
  currents): connected idle + wake sensing ≈ 15 µA average →
  standby-only ≈ 55 mAh / 0.015 mA ≈ **5 months**. Typical use
  — 30 min/day of active scrolling and clicking at ~1.5 mA
  burst average — ≈ 1.1 mAh/day → **~6 weeks per charge**.
  Headline: **charge it monthly, forget it otherwise.** (The
  C3 column above is why this number is Nordic-shaped.)
- RG-EL-07 — **One status LED, amber, and a short leash.** It
  may show: pairing (slow blink, only while unpaired), charge
  state (only while plugged in), low battery (triple-blink on
  click, only when clicked). It is **never red, never steady
  while worn, and never indicates anything about the glasses**
  — it is not, and must never be mistakable for, the glasses'
  hardwired recording indicator (FW-LED-01). Different device,
  different colour, different meaning, stated in the manual in
  those words.

## 3. Form

- RG-FM-01 — **Sizing reality, stated plainly:** US ring sizes
  5–13 span **15.7–22.2 mm inner diameter** (ISO/US standard:
  ID = 11.63 + 0.8128 × size). No single band fits that, and an
  adjustable band breaks twice — the battery arc and the flex
  tail both need a fixed circumference to live in. **The design
  takes a fixed size run:** one electronics set (RG-EL-03),
  band length per size.
- RG-FM-02 — **Launch run (OPEN, default): 6 whole sizes, US
  7–12** (17.3–21.4 mm ID), with a compliant inner liner
  absorbing ±0.4 mm — effectively half-size coverage. Sizes
  5–6 and 13 join the run when volume justifies the tooling;
  every size is the same board, so a size is a band, not a
  product.
- RG-FM-03 — **Layout on the finger:** pod on top (dorsal),
  battery arc down one side, rocker paddle on the pod's
  thumb-facing slope, click dome on the pod's top face. Worn
  on index or middle finger; the **thumb of the same hand**
  works both controls without looking — that is the blind-use
  requirement the whole layout serves.
- RG-FM-04 — **Targets:** pod ≤5.5 mm proud of the band; band
  6.5 mm wide, ≤2.2 mm thick off-pod; **total weight ≤6 g**
  (smart-ring class). Materials: glass-filled nylon band with a
  TPE inner liner, PC/ABS pod cap; no exposed metal against
  skin except none — there is none.
- RG-FM-05 — **Water/sweat posture: IP67 target.** Sealed pod,
  domes under membrane, no openings but the USB-C port (dust
  plug fitted). Sweat is a non-event; hand-washing and rain
  are design cases; it is not a dive instrument and the copy
  won't call it one.

## 4. Firmware posture

- RG-FW-01 — **Stock HID, full stop.** HID-over-GATT (HOGP):
  consumer-control + mouse (wheel) + keyboard report maps in
  one composite device. It pairs with Android, iOS, Windows,
  macOS and Linux with **no driver and no app**, and scrolls
  and clicks in all of them the day it first powers on.
- RG-FW-02 — **The generic usefulness is a selling point, say
  so on the box:** presenter clicker (scroll = advance/back in
  the keyboard dialect), media scroll, e-reader page turns,
  phone camera shutter via the phone's own HID mapping. The
  IMP-VISION app is the best host, never a required one.
- RG-FW-03 — **In the app**, the ring appears as a named input
  source ("Deadbug Ring") under IN-UX-01, enabled like any
  source, bound by the same boundaries as every HID source
  (IN-HID-06: it navigates and confirms UI actions; it opens
  nothing on an IMP).
- RG-FW-04 — **Wake and sleep.** Any dome or rocker contact
  wakes from System ON idle on GPIO sense (~1.5 µA); reconnect
  target <1 s to a bonded host. Advertising for re-pair only
  after 60 s unpaired idle, or on a 3 s click-hold with no
  host. Nordic BLE DFU for firmware updates — updates ride the
  same radio, no port gymnastics.

## 5. BOM sketch (qty-1, prototype build)

| Line | Part | Cost | Basis |
|---|---|---|---|
| SoC | nRF52810-QCAA (EVT: Raytac MDBT42Q) | $3.66 (EVT $4.95) | DigiKey list, 2026-11-20 |
| Switches | 3× snap dome / tact (2 rocker + 1 click) | $0.35 | est. |
| Battery | LiPo pouch ~55 mAh, 401020 class | $1.80 | est. |
| Charge | MCP73831-class IC + USB-C receptacle | $0.90 | est. |
| Antenna | 2.4 GHz chip antenna + matching passives | $0.55 | est. |
| LED + passives | 1× amber LED, crystal, discretes | $0.60 | est. |
| PCB | Rigid-flex, pod + tail | $2.50 | est., qty-1 panels |
| Shell | Band + pod cap + liner (printed at proto) | $3.00 | est. |
| **Total** | | **≈ $13.40** (EVT ≈ $14.70) | |

At qty-100 the same list lands ≈ $8–9 (SoC $2.75 cited; the
rest scales or vanishes into panels and moulding).

- RG-PR-01 — **Price posture:** standalone retail target
  **$35–45**, glasses-bundled below that — squarely in the
  IMP-101-class accessory band (an accessory priced like an
  accessory, standalone-priced like a small product), with
  honest margin at qty-100 and no cost breakdown published,
  per house rule.

## 6. Open items

**Genuinely the founder's** (defaults hold until he rules):

| # | Item | Default in this design |
|---|---|---|
| RG-1 | **Name.** "Deadbug Ring" is a working title on every surface so far. | Ship as the Deadbug Ring unless renamed |
| RG-2 | **Bundled or standalone-first.** It works with any phone on Earth (RG-FW-02); the glasses are its best host, not its only one. | **Standalone-first** — it can sell before the first glasses ship, and every ring in the wild is a glasses sale warming up |
| RG-3 | **Size-run count at launch.** Each size is tooling + inventory, same board. | 6 sizes, US 7–12 (RG-FM-02) |

**Covered by defaults** (no ruling needed unless founder
objects): rocker over capacitive band (RG-IN-04/05 — founder
can flip this one word and §1/§2 re-derive), amber LED
(RG-EL-07), double-click = back (RG-IN-03), EVT-on-module then
bare-SoC production (RG-EL-02).

## Sources

Prices and currents checked 2026-11-20: nRF52810 / nRF52811
product briefs (Nordic — 0.3 µA System OFF, 4.6 mA TX/RX,
1.1–1.5 µA System ON + RTC) and DigiKey listings (NRF52810-QCAA
$3.66 @1 / $2.75 @100); ESP32-C3-MINI-1 DigiKey listing
($3.26 @1 / $2.45 @100; module 13.2 × 16.6 mm) and Espressif
datasheet currents via LCSC (deep sleep 5 µA, light sleep
130 µA); Raytac MDBT42Q-512KV2 (16 × 10 × 2.2 mm, $4.95 DigiKey
Marketplace / $6.11 LCSC, FCC/CE/Telec pre-certified); Bourns
PEC09 datasheet (9.7 mm body, Ø6 mm shaft, 30k cycles, IP40);
Pimoroni Trackball Breakout (25 × 22 × 9.5 mm); Azoteq
IQS7222A datasheet (QFN20 3 × 3 mm, 4-element slider, ULP
wake); US ring sizes per ISO/US standard charts (size 5 =
15.7 mm ID … size 13 = 22.2 mm ID). Figures marked "est." are
engineering estimates, not quotes.
