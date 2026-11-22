# IMP-VISION — Input Sources spec (draft, 2026-11-20)

Status: **specification, not code.** Project direction, 2026-11-20:
expand the input model beyond head gestures — eye movements, and
peripherals like a ring or a mouse. This spec works that out
against the input model of record (`SCREEN_CONTROL.md`), the HUD
and gesture-tuning surface (`app-design.md` §5), and what the
glasses actually stream (`designs/temple-f/FIRMWARE.md`).

Conventions mirror the other specs: requirements are numbered
`IN-<BLOCK>-<nn>`; an item marked **OPEN** carries a recommended
default, and the default governs unless overruled.
Items that genuinely need a ruling are collected in §6.

**The one-sentence version:** every input source — head, ring,
mouse, and one day gaze — feeds one phone-side input layer, and a
confirmation is always a discrete physical act, no matter which
source it arrives from.

## 0. Principles

- IN-GEN-01 — **Sources are phone-side citizens.** The phone is
  the hub (SCREEN_CONTROL SC-GEN-02). A new source changes what
  the *phone* listens to; the glasses' stream — button events
  plus raw motion (FIRMWARE.md FW-BLE-02) — is untouched by
  everything in this spec except §3, which is new hardware and
  labelled as such.
- IN-GEN-02 — **One input layer, many sources.** All sources
  render into the same event vocabulary Screen Control already
  consumes — pointer motion, D-pad keys, select, confirm, back,
  dismiss (SC-IN-01…05). A mode never knows which source an
  event came from, only what it means. Adding a source is
  app work, never mode work, never glasses work.
- IN-GEN-03 — **The confirm principle (§4) binds every source.**
  No source ships with a mapping that violates it, and source
  management (§5) may not create one.

## 1. BLE HID peripherals — via the phone

The phone already speaks BLE HID host; Android pairs standard
HID-over-GATT devices natively. These peripherals pair **to the
phone**, never to the glasses. The glasses are not in this
section at all.

- IN-HID-01 — **Zero glasses change, stated plainly.** No new
  glasses hardware, no firmware delta — not even a flag. Screen
  Control's entire firmware consequence was one boolean
  (SC-FW-01); input sources add none. If a future draft of this
  spec grows a glasses-side requirement, that is a defect in the
  draft.
- IN-HID-02 — **Source classes in v1** (class-based, no SKU
  dependency — any conforming device works):
  - **Wearable ring controller** — a scroll action plus a
    click, worn on a finger. The **Deadbug Ring is the
    reference implementation** (`RING_DESIGN.md`); any
    conforming third-party ring also works.
  - **BLE mouse / trackball** — standard HID pointer + buttons.
  - **Presenter / clicker** — HID keyboard class (advance, back,
    blank); rides the same mapping table as D-pad keys.
- IN-HID-03 — **Mapping — ring (profile of record, ruled by
  2026-11-20: scroll + click).** **Scroll** = navigation:
  each scroll step is one D-pad step in key dialect, or one
  wheel detent in pointer dialect; the phone's control pipeline
  picks the dialect from the target, exactly as it does for
  head flicks (SC-IN-04). **Click** = **select / confirm** (the
  §4 discrete act). **Double-click** = back; **long-press**
  (≥600 ms) = dismiss. Nothing else is assigned in v1. The
  reference implementation is the Deadbug Ring
  (`RING_DESIGN.md` RG-IN-03); a third-party ring with more
  controls maps its extras onto the same four functions and no
  others.
- IN-HID-04 — **Mapping — mouse / trackball.** Motion = pointer
  (the same cursor the head-pointer drives, §2 arbitration);
  left button = select / confirm; right button = back; wheel =
  scroll. On the wearer's own HUD the mouse drives the §5
  phone-as-trackpad surface's cursor model — one pointer
  behaviour everywhere, per SC-HUD-01's learn-it-once rule.
- IN-HID-05 — **What this buys audio-only variants.** F / L / N /
  S builds have no cursor and were promised none (SC-UX-05). A
  ring gives them **full D-pad navigation with a physical
  confirm** — menus, target pickers, HUD-less flows — driven
  entirely by scroll + click with the spoken echo Screen Control
  already specifies. This closes the largest usability gap of
  the audio-only line without touching their hardware, and the
  copy may say exactly that.
- IN-HID-06 — **Pairing and trust.** HID devices pair through
  Android's normal Bluetooth flow and appear in the app as named
  sources (§5) only after the owner enables them there. An
  enabled HID source is trusted exactly as far as §4 lets it be:
  it can navigate and confirm UI-level actions; it inherits
  every existing boundary unchanged (it cannot open an IMP
  control session, cannot confirm an IMP-side gated action —
  PI-CTL-03 has no verbs, from any source).

## 2. Arbitration — several sources, one wearer

- IN-ARB-01 — **Pointer: last-active wins.** Head-pointer and
  mouse both write the pointer. Whichever source moved most
  recently owns it; ownership passes on the other source's next
  motion event. No mode switch, no announcement beyond the
  cursor simply answering the hand instead of the head. The
  head-pointer's recentre (SC-IN-05) remains available
  regardless of who owns the pointer.
- IN-ARB-02 — **Confirms: any enabled source.** A confirm from
  any enabled source is a confirm (§4). The wearer may nod at
  the TV, then press the ring to confirm — sources compose
  within one interaction; nothing requires finishing a gesture
  on the source that started it.
- IN-ARB-03 — **Keys: merged, ordered by arrival.** D-pad /
  navigation events from all enabled sources merge into one
  stream in arrival order. Two sources firing at once is the
  wearer's own doing and resolves as ordinary rapid key input —
  the same thing a TV does with two remotes in one room.

## 3. Gaze — Tech tier, evaluated option, NOT a v1 commitment

Gaze is the one source in this spec that is hardware. It is
specced here so the decision is on record with its costs, and it
is **not** committed for v1 on any variant.

- IN-GAZE-01 — **The hardware cost, named.** Gaze tracking
  requires an inward-facing eye camera plus near-IR eye
  illuminators, running continuously while gaze input is live.
  That is a second camera, a second emitter set, their capture
  pipeline, and the per-wearer calibration that goes with them
  — on top of everything the temple board already carries.
- IN-GAZE-02 — **Where it could live.** On Reticle / Twineye-
  class frames only: the brow bar and combiner housing already
  have the volume, the structure, and a powered engine block at
  the brow/temple junction; an eye camera in the combiner
  housing looks back at the eye it serves, and the illuminators
  sit in the brow bar beside the outward studs. The frame was
  drawn for optics; this is one more optic.
- IN-GAZE-03 — **Why it does not fit the stealth line.** Three
  independent reasons, any one sufficient:
  - **Size.** The stealth frames' whole discipline is ordinary
    glasses; there is no brow bar, no housing, nowhere an eye
    camera and illuminators hide.
  - **Power.** Continuous inward illumination + capture is an
    always-on load of the same class as the outward senses the
    design works hard to duty-cycle (FW-ILL-02, FW-PWR-04); the
    stealth line's battery story does not carry it.
  - **Privacy posture — the decisive one.** The product's
    recording promise faces outward: a hardwired LED tells the
    world when the world is being recorded (FW-LED-01). An
    inward camera watches the *wearer*. Shipping one — even an
    honest, local-only one — changes what the product is: the
    glasses stop being a sensor the owner points at the world
    and become a sensor pointed at the owner. That is a
    different product decision, not an accessory, and it is
    the founder's to take explicitly if it is ever taken (IN-OPEN-1).
- IN-GAZE-04 — **The input rule, if gaze is ever adopted: gaze
  POINTS, a discrete act CONFIRMS.** Gaze may move the pointer
  or highlight the focused element — nothing more. Confirmation
  is a temple tap or a ring button (§4). Gaze alone never
  confirms anything. This is the Midas-touch problem: a pointing
  sense that also fires makes every look a potential click —
  reading a menu becomes operating it. Dwell-to-confirm is a
  confirm-by-look with a timer and is prohibited by the same
  rule (IN-CFM-02).
- IN-GAZE-05 — **Blink patterns: last-resort class, honestly.**
  Deliberate blink codes (double-blink, long-blink) collide with
  involuntary blinking (~15–20/min), degrade with fatigue and
  dry eyes, and get *more* error-prone the longer a session
  runs — the opposite of what a confirm channel needs. If gaze
  hardware ever ships, blink patterns may serve as an
  accessibility fallback for wearers who cannot use the other
  sources, labelled as such in the app, and they may never be
  the sole path to a consequential action. They are not a
  feature to advertise.
- IN-GAZE-06 — **Data posture, pre-committed.** If adopted, eye
  imagery never leaves the temple board's host phone, is never
  recorded to the session log (gaze *events* — point coordinates
  — are data like any input; eye *images* are not), and the
  inward camera gets its own visible-when-live indicator on the
  HUD. This paragraph is written now so a future adoption
  inherits it rather than renegotiating it.

## 4. The confirm principle — restated for all sources

- IN-CFM-01 — **A confirmation is a discrete physical act:** a
  button press (ring, mouse, presenter), a temple tap (SW2 in
  its mode meaning, SC-IN-02), a PTT voice command spoken as a
  command. It has a beginning the wearer chose and an end the
  system can timestamp.
- IN-CFM-02 — **Never a state:** not a dwell (looking or
  pointing at something for N ms), not a gaze, not a head
  position or head pose held, not proximity, not the absence of
  a cancelling gesture. States are how the wearer *looks at the
  world*; acts are how they *tell the device something*. The
  line between those is the whole principle.
- IN-CFM-03 — **Head gestures keep their class.** Nod / shake /
  tilt remain navigation, back, and dismiss (SC-IN-04) — nod is
  Confirm in the D-pad dialect because it is a deliberate,
  bounded *motion event* the classifier fires once, not a pose;
  it is the one gesture-class confirm and no new one joins it
  by analogy. If a future source proposes a gesture confirm, it
  must argue its way past this paragraph, in writing, in this
  file.
- IN-CFM-04 — **Tuning bounds apply per source.** The gesture
  tuning of app-design §5 (nod / shake / tilt sensitivity, test
  pad) and its HUD-customization bounds are stored **per
  source**: the head stream has its profile; a future motion
  source gets its own. Loosening one source's bounds never
  loosens another's, and no source's tuning may widen a confirm
  into a state (IN-CFM-02) — sensitivity changes how easily an
  act registers, never what counts as one.

## 5. Source management UX

- IN-UX-01 — **One list.** Settings gains an **Input sources**
  card (the Settings screen stays short, app-design §7 — this is
  one card, not a section): the glasses' own head + temple
  source (always present, always enabled — it is the device),
  then each paired HID peripheral by the name it advertises
  ("Ring — left hand", "MX Master"), then gaze, greyed with its
  posture line on variants that have no eye hardware.
- IN-UX-02 — **Per-source controls:** enable/disable, priority
  (pointer ownership preference when two sources move in the
  same instant — §2's last-active rule governs steady state;
  priority breaks true ties), and a tuning entry (§5 of
  app-design: sensitivity + test pad, per IN-CFM-04). Nothing
  else. A source the owner never touches behaves per §1–§2
  defaults.
- IN-UX-03 — **Loss behaviour — nothing dead-ends.** A source
  dropping (ring battery, mouse out of range, HID bond lost)
  removes it from arbitration silently and the head-gesture
  model — which never went anywhere — simply remains. The app
  notes the loss once ("Ring disconnected — head control
  continues"), spoken on audio-only variants. A mode in progress
  (Screen Control session, HUD navigation) survives the loss of
  any single source, including the pointer's owner mid-drag:
  ownership falls back per IN-ARB-01. Reconnection re-enters
  arbitration without re-entering the mode.
- IN-UX-04 — **The floor is always the glasses.** With every
  peripheral disabled, dead, or left at home, the glasses alone
  deliver the full input model of SCREEN_CONTROL.md. Peripherals
  are additions to a complete system, never completions of an
  incomplete one — the same rule the product applies to its
  senses (app-design, Architecture notes).

## 6. Open items

**Genuinely the founder's** (defaults hold until he rules):

| # | Item | Default in this spec |
|---|---|---|
| IN-1 | **Gaze adoption (IN-GAZE-03):** an inward eye camera on Tech-tier frames — a product-posture decision (a camera pointed at the wearer), not a feature toggle. | Not adopted. Evaluated for Tech tier only, no v1 commitment, no stealth-line path; IN-GAZE-04…06 bind any future adoption |
| IN-2 | **Ring as a Deadbug product:** v1 treated the ring as a third-party HID class only. **Ruled by Deadbug Labs 2026-11-20:** the ring is a Deadbug product with a scroll + click interaction model; the design is `RING_DESIGN.md`, and the ring profile of record is IN-HID-03. Remaining open items (name, bundled vs standalone-first, size-run count) live in `RING_DESIGN.md` §6. | Deadbug Ring designed; third-party rings still work (class-based, IN-HID-02) |

**Covered by defaults** (flagged OPEN inline, no ruling needed
unless the founder objects): last-active pointer arbitration with
priority tie-break (IN-ARB-01, IN-UX-02), confirms accepted from
any enabled source (IN-ARB-02), per-source tuning profiles
(IN-CFM-04), HID sources may drive a Screen Control session but
may not *enter* one — entry stays deliberate per SC-UX-01
(voice or app), a ring button is not an entry gesture.
