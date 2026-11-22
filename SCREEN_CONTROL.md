# IMP-VISION — Screen Control spec (draft, 2026-11-20)

Status: **specification, not code.** Project direction, 2026-11-20:
the glasses should control external screens — "TV, devices,
whatever." This spec works that out against what already exists:
the input hardware and streams of `designs/temple-f/FIRMWARE.md`,
the hub topology and control boundary of `PAIR_IMP_PROTOCOL.md`,
and the app's one-primary-action rule (`app-design.md`).

Conventions mirror the other specs: requirements are numbered
`SC-<BLOCK>-<nn>`; an item marked **OPEN** carries a recommended
default, and the default governs unless overruled.
Items that genuinely need a ruling are collected in §10.

**The one-sentence version:** the glasses are the remote's *input
end* — head, tap, voice — the phone is the remote. The glasses
already stream everything this needs; §2 is the entire firmware
delta, and it is one flag.

## 0. Principles

- SC-GEN-01 — **Input events only.** In control mode the glasses
  emit exactly what they always emit — BLE button events and the
  raw motion stream (FIRMWARE.md §2/§6/§8). They gain no knowledge
  of TVs, targets, or protocols. All translation is phone-side,
  per FW-GEN-01 (firmware ferries, the phone thinks).
- SC-GEN-02 — **The phone is the hub and the translator.** One
  control pipeline on the phone consumes head-pointer, tap,
  gesture, and voice input and renders it into whatever the
  current target speaks (§4–§6). Adding a target brand is app
  work, never glasses work.
- SC-GEN-03 — **Honest feedback.** The app displays a target state
  only when the transport *reports* it. A one-way send is shown
  as sent — "Volume up · sent" — never dressed up as confirmed.
  This is the IR Watch emitter-first rule applied to remotes.
- SC-GEN-04 — **Owner's screens, owner's network.** Control exists
  only on the owner's LAN and the owner's pairings (§9). There is
  no cloud relay and no control-from-anywhere in this spec.

## 1. The control model — inputs that already exist

- SC-IN-01 — **Head-pointer.** The phone fuses the existing Motion
  stream (BMI270 100 Hz accel/gyro + MMC5983MA, FIRMWARE.md
  FW-IMU-02) into a relative pointer, the air-mouse model: head
  yaw/pitch move a cursor on the target, the magnetometer anchors
  against gyro drift, and gain/smoothing are the phone's existing
  gesture-tuning parameters (app-design §5). The fusion is the
  same phone-side stack that already produces the compass heading
  and classifies gestures (FW-IMU-05) — pointing is a new consumer
  of it, not a new stack.
- SC-IN-02 — **Temple tap = select.** SW2 tap is the click at the
  cursor (pointer targets) or OK on the focused element (D-pad
  targets). Firmware emits the identical event it always emits
  (FW-BTN-04); the phone's control mode interprets it. This is
  why the HUD must show the mode plainly (§7): in control mode a
  tap selects, it does not take a photo.
- SC-IN-03 — **Push-to-talk = voice.** SW1 hold is the voice path
  (FW-BTN-02, Opus up, whisper.cpp on the phone). Voice carries
  three loads in control mode, in this order: transport commands
  ("pause", "volume up", "go home"), search and text ("play
  Dune", dictation into a search box), and mode commands ("control
  the TV", "stop controlling"). Text entry is voice-first by
  design — head-typing a letter grid is the last resort, offered
  only where a target forces it, and the app says so.
- SC-IN-04 — **Head gestures = navigation keys.** Phone-side
  classification of the raw stream (FW-IMU-05), mapped:
  - **Nod → Confirm** (OK / select on focus).
  - **Shake → Back.**
  - **Tilt-hold → Dismiss** (close dialog; tilt-hold again, or a
    1 s hold at the top level, exits control mode).
  - **Directional flicks** (short, deliberate head flicks) →
    D-pad Up/Down/Left/Right on targets without a pointer.
  One stream, two dialects: pointer where the target takes one
  (§4), D-pad keys everywhere else. The app picks the dialect from
  the target's capability row, never asking the user.
- SC-IN-05 — **Recentre.** SW2 double-tap (an event pattern
  firmware already emits; unassigned in FIRMWARE.md) is
  interpreted by the phone in control mode as pointer recentre:
  cursor returns to screen centre and the fusion's zero re-anchors
  to the wearer's current head pose. Pointer drift is expected
  physics; recentre is one double-tap away, always.
- SC-IN-06 — **Latency honesty.** The chain BLE → phone fusion →
  LAN → TV lands in the ~50–150 ms class. That is right for
  navigation, menus, and media control. It is not a game
  controller, and no copy may sell it as one.
- SC-IN-07 — Phone-side reinterpretation is total: in control
  mode the phone also maps SW2 long-press (normally night-feed
  request, FW-BTN-04) to *exit control mode*. Firmware sends the
  same events in every mode; every mapping in this section is the
  phone's. The complete firmware consequence of this spec is §2.

## 2. Firmware delta — one flag

- SC-FW-01 — The glasses firmware changes in exactly one place: a
  `control_mode` boolean on the BLE Control service
  (FIRMWARE.md FW-BLE-02), set by the phone on mode entry/exit.
  While the flag is set:
  - the motion stream is pinned live — the FW-PWR-03 sleep ladder
    may not drop it at 60 s mid-pointing;
  - the stream is exempt from the FW-BLE-04 shed order (control
    pointing outranks thermal preview; voice and control already
    outrank everything).
  Nothing else changes: no new characteristics, no new packet
  formats, no target knowledge, no code path from the flag to any
  actuator. On BLE drop the flag dies with the link (FW-FAIL-01),
  which is also how control mode ends (§9).
- SC-FW-02 — Display variants need nothing at all for the HUD side
  of control mode: the lens window is already phone-rendered over
  the DP alt-mode pipe (FW-LINK-02); the phone simply renders
  control state into it (§7).

## 3. Architecture — one pipeline, three transports

- SC-ARC-01 — A control session binds three things: the live
  glasses link (the input source), one target screen, and one
  transport. The phone holds all three; losing any one ends or
  suspends the session per §9.
- SC-ARC-02 — Transport ranking, and the app tries them in this
  order for a given target:
  1. **Network remote protocol** (§4) — two-way, key/pointer
     injection, real state where the platform reports it.
  2. **IMP-as-IR-blaster** (§5) — universal: anything with an IR
     receiver, including every target §4 can't speak to. One-way,
     no feedback, and the app says so.
  3. The **HUD itself** (§6) is not a fallback but the same
     pipeline pointed home — see the symmetry note there.
- SC-ARC-03 — Content casting (Cast / DLNA, §4.5) is *not* a
  remote transport and is not ranked as one. It answers "play
  this on that screen," which Ask already does with content; it
  cannot navigate a UI. Screen Control is about driving the
  screen's own interface.

## 4. Transport 1 — network remote protocols

Discovery is LAN-scoped: mDNS + SSDP on the phone's current
network. The app lists what it finds by the name the device
advertises ("Living Room TV"), never by raw address in buyer
copy. Pairing, where a protocol has it, is a prompt **on the
target screen** the owner accepts or reads a PIN from — physical
presence is the credential, and the resulting token lives in
app-private storage on the phone and nowhere else.

Capability matrix (✓ = real, — = absent, ~ = partial):

| Target | Keys | Pointer | Text / voice search | App launch | State feedback |
|---|---|---|---|---|---|
| Android TV / Google TV | ✓ | — | ✓ | ~ | ~ |
| LG webOS | ✓ | ✓ | ✓ | ✓ | ✓ |
| Samsung Tizen | ✓ | — | ~ | ~ | ~ |
| Roku (ECP) | ✓ | — | ~ | ✓ | ~ |
| Fire TV | — (see §4.4) | — | — | — | — |
| Apple TV | — (see §4.4) | — | — | — | — |
| Cast / DLNA receiver | content only (§4.5) | — | — | — | ✓ (media) |

- SC-NET-01 — **Android TV / Google TV** (rank 1: the largest
  modern installed base, full key injection). The Google TV
  remote protocol: TLS with a phone-generated client certificate,
  one-time pairing PIN shown on the TV. Carries D-pad, transport
  keys, text input, and voice-search hand-off. State feedback is
  partial (power/focus class, not a live UI mirror) — the HUD
  shows sent-key echo plus reported state, labelled as each is.
- SC-NET-02 — **LG webOS** (rank 2: the only true pointer). SSAP
  over WebSocket; first connect shows a pairing prompt on the TV
  and returns a client key the phone stores. webOS exposes a
  dedicated **pointer input socket** — absolute pointer, click,
  scroll — which is what the head-pointer was designed for: on
  webOS the wearer points at the TV the way they point at their
  own HUD. Foreground-app state is reported, so its HUD line can
  show confirmed state, not just echoes.
- SC-NET-03 — **Samsung Tizen** (rank 3). WebSocket remote; first
  connection puts an Allow prompt on the TV and returns a token.
  Full key injection; search/text is partial (key-by-key into the
  TV's own keyboard — voice dictation per SC-IN-03 is the sane
  path); state feedback is coarse.
- SC-NET-04 — **Roku ECP** (rank 4). Plain HTTP on the LAN
  (port 8060): keypress, app launch, search, active-app query.
  **ECP has no authentication by default** — any device on the
  LAN can drive a Roku unless its owner restricted ECP in Roku's
  settings. That is Roku's posture, stated here so our copy never
  implies we added security Roku didn't: our app still only
  *offers* control of Rokus found on the owner's own LAN (§9),
  and the Settings card for a Roku target says, in plain words,
  that Roku control on a network is open to that network.
- SC-NET-05 — **Fire TV and Apple TV are not network targets in
  v1, honestly.** Fire TV exposes no open third-party LAN remote
  protocol (the vendor app channel is proprietary; ADB is a
  developer path, not a product feature). Apple TV's remote
  protocol is proprietary and not available to an Android app.
  Both fall through to §5 — and Apple TV additionally *learns* IR
  remotes, so the IR path gives it real basic navigation, not a
  token gesture.
- SC-NET-06 — **Cast / DLNA (content class).** AVTransport /
  Cast media sessions: play, pause, seek, volume — on media the
  phone sends. No key injection into the receiver's own UI
  exists in either protocol. Used by Ask for content requests;
  never presented in the target picker as a controllable screen
  unless it is the only thing found, and then labelled
  "play content only."

## 5. Transport 2 — the paired IMP as IR blaster

- SC-IR-01 — Any device with an IR receiver is controllable
  through the paired IMP-1 / IMP-2's IR transmitter — every TV
  §4 can't speak to, older TVs, set-top boxes, AV receivers,
  projectors, Apple TV (§4.5). This is the universal fallback and
  the reason "whatever" is a fair word for the v1 scope (§8).
- SC-IR-02 — **One-way, and the UI says so.** IR has no return
  channel. The app renders every IR action as sent, never
  confirmed (SC-GEN-03): "Channel up · sent — the IMP can't hear
  the TV answer." There is no state inference: the app does not
  pretend to know the TV's volume, input, or power state on this
  transport, and the HUD line shows the key sent and nothing
  more. If the owner needs feedback, §4 is the answer where it
  exists.
- SC-IR-03 — **Placement is part of the UX.** The blaster is the
  IMP, not the glasses: it must sit or be held facing the screen,
  in normal IR range. On entering an IR control session the app
  says exactly that ("Set the IMP facing the TV") and the first
  key is a harmless probe (Volume up one step) whose result only
  the wearer's eyes can confirm. The glasses aim the wearer's
  attention; they do not aim the IR.
- SC-IR-04 — **Reconciliation with the Pair IMP boundary — read
  this before building either side.** `PAIR_IMP_PROTOCOL.md`
  PI-CTL-03 is absolute: IR **Send** is confirm-gated on the IMP,
  the command set contains **no verb for it**, and the glasses
  can never ask for it. Screen Control does not repeal that. It
  proposes a narrow, holder-granted exception, specced here and
  flagged as an amendment (SC-OPEN-1, §10) — **until founder
  rules, the default below governs the design and PI-CTL-03
  governs any conflict:**
  - The exception is a **standing control session opened on the
    IMP itself**: a person holding the IMP selects *Screen
    Control* in the IR tool. The IMP shows a persistent banner
    ("Screen Control — phone may send remote keys · 28:41") for
    the session's whole life, with a countdown (default 30 min)
    and local BACK ending it instantly. Opening it is a physical,
    in-person act on the device that transmits — the confirm
    PI-CTL-03 exists to protect, taken once, in advance, in
    person, for a bounded scope and a bounded time.
  - Inside a session, the phone may send one new verb,
    `ir_key {profile, key}`: a **named key of a stored remote
    profile** (Power, Vol+, Ch−, OK, arrows…) — never a raw
    capture, never an arbitrary waveform, never a macro. Rate
    cap 2 keys/s, human remote pace. Every transmission is drawn
    on the IMP's screen as it fires (never silent, PI-CTL-02's
    principle) and journaled as a normal IR `result` event with
    `confirmed_action` semantics extended by the session grant —
    the event stream keeps the receipt.
  - Outside a session, `ir_key` does not exist: the IMP answers
    `error {code: no_session}` and the app offers the owner the
    instruction to open one on the IMP. There is no phone-side
    way to open, extend, or renew a session.
  - Session class only: this grant covers *remote keys for
    screens*. It does not generalise — no other IMP tool gains a
    standing grant from this spec, and the session verb set is
    `ir_key` alone.
  - If the founder declines the amendment, §5 degrades honestly to:
    per-send confirm on the IMP (the wearer glances at the IMP
    and confirms each key) — which is a working IR remote for
    single keys and an unusable one for navigation, and the spec
    will say that instead. The network transports are unaffected
    either way.
- SC-IR-05 — Remote profiles (which keys a given TV understands)
  come from the IMP's learned/saved IR library — the same signals
  build 1 already learns and stores (§4.3 of the Pair IMP spec).
  A TV the IMP has never learned is a two-minute guided learn on
  the IMP, once, in front of the TV — after which it is a profile
  like any other. No cloud code database in v1.

## 6. Transport 3 — the HUD is the same pipeline pointed home

- SC-HUD-01 — Display variants already live the symmetry: the
  lens window is phone-rendered (DP alt-mode), and its input is
  this same head-pointer + tap + gesture + voice model
  (app-design §5, including the phone-as-trackpad mirror). Screen
  Control adds no second input system: **the wearer drives their
  own HUD and the living-room TV with one set of motions**, and
  switching targets is choosing which surface the phone renders
  the input to. Learn it once, use it on every screen — that is
  the feature's real pitch, and the copy may say exactly that.
- SC-HUD-02 — While an external target is being controlled, the
  HUD keeps a minimal control strip (§7): target name, dialect
  (pointer / keys), last action. The wearer's own HUD remains
  fully drivable by the same gestures the moment control mode
  exits — there is never a state where the glasses' input is
  captured by the TV with no exit (SC-IN-04 tilt-hold, SC-IN-07).

## 7. Modes and UX

- SC-UX-01 — **Entry.** Two doors, both deliberate: voice —
  push-to-talk, "control the TV" (Ask routes it; this is a
  command, not a question, and Ask's no-mode-switching rule is
  about *questions* — control is an explicit state the owner
  enters and leaves, which is why it may be a mode at all) — or
  the app's **Control** chip on Home, beside the sense toggles.
  There is no temple-only entry in v1: SW1 double-press is spoken
  for (FW-BTN-03), and a mode this stateful should announce
  itself on a screen or in the ear, not start from a silent
  gesture. **OPEN** (default as stated).
- SC-UX-02 — **The mode's one primary action** is *drive the
  target*. Everything inside the mode serves that; settings,
  pairing, and profile management live outside it (Pairing and
  Settings screens), so the mode itself never needs a menu.
- SC-UX-03 — **Target picker.** On entry the app resolves
  targets: the last-used target, if reachable, is rejoined
  directly and announced ("Controlling Living Room TV"). Several
  new targets → the picker: a HUD card list on display variants
  (nod to select), a spoken list on audio-only ("Two screens:
  Living Room TV, Bedroom Roku — say a name or nod when I read
  it"). None found → the app says what's missing in plain words
  and offers the exits that exist: join the TV's Wi-Fi network,
  or pair the IMP for IR (§5). Discovery failure never dead-ends
  in an error code.
- SC-UX-04 — **HUD in control mode** (display variants): the
  target name pinned in the status strip, the dialect icon
  (pointer vs keys), and the last action — echoed as *sent* or
  shown as *state* per SC-GEN-03 and the transport's feedback
  column. Centre stays clear (the HUD rule); the cursor itself
  lives on the TV for pointer targets — the wearer is looking at
  the TV, which is the point.
- SC-UX-05 — **Audio-only variants — the honest subset.** No
  cursor exists, so none is promised. What works, genuinely:
  voice commands as the primary channel (transport, volume,
  channel, search, launch where supported); directional flicks
  as blind D-pad keys with a **spoken echo of every key sent**
  ("Right." "Right." "OK.") so navigation is audible bookkeeping
  rather than faith; shake for Back. What is true and stated in
  the mode's own help line: browsing a dense grid this way is
  slow, and the phone in the owner's hand shows a full remote
  surface (the §5 trackpad, grown into a remote) — the glasses
  are the always-on-you remote, the phone is the remote you look
  at, and the mode never pretends the first is the second.
- SC-UX-06 — **Exit is always one motion:** tilt-hold, SW2
  long-press, voice "stop controlling," or the app. Exit is
  spoken/shown ("Stopped controlling Living Room TV") so the
  wearer knows the next temple tap is a photo again. Mode state
  is never ambiguous from the wearer's side — that ambiguity is
  the one genuinely dangerous failure this feature has (a tap
  meant as Select firing the camera, or meant as a photo sending
  OK to a purchase dialog), and §7 exists to make it impossible
  to be in doubt about which mode the tap belongs to.

## 8. Scope — "whatever," bounded

- SC-SCOPE-01 — **v1 device classes:** TVs and streaming boxes on
  the owner's LAN (§4's matrix) plus **any IR-controlled device**
  via §5 — TVs of any age, set-top boxes, AV receivers,
  projectors, soundbars. That is the honest content of
  "whatever" in v1: if it has a screen and a remote protocol, or
  a screen and an IR eye, it's in.
- SC-SCOPE-02 — **Plausible v2:** presentation control (the phone
  already drives slides on a LAN companion; the glasses add
  pointer + advance/backup gestures — a natural dialect reuse);
  desktop pointer, as the phone-as-trackpad's evolution — via a
  small desktop companion receiving the pointer over the LAN (the
  phone cannot present itself as a standard BLE HID peripheral to
  arbitrary desktops, so the companion is the honest route; an
  IMP-class device presenting as BLE HID is a hardware-shaped
  alternative for later); kiosk/public screens **only** where
  they expose a network remote or accept IR and the owner is
  authorised to drive them — most expose neither, and the spec
  does not promise them.
- SC-SCOPE-03 — **Out, named so nobody designs toward them:**
  - **HDMI-CEC direct.** The phone cannot source CEC: a phone's
    USB-C/HDMI output does not give apps a CEC channel to inject
    frames on. The bridge that would change this is hardware —
    a CEC injector in the TV's HDMI chain (a USB-CEC adapter on
    a host that has one, or a future IMP-class pass-through
    dongle with a CEC transceiver). If that hardware ever exists,
    CEC becomes a §4-class transport then, not before.
  - **Vendor cloud remotes** (SmartThings / ThinQ-style cloud
    control): excluded by SC-GEN-04 — no cloud relay, and the
    credentials they need are account credentials, not pairing
    tokens.
  - **Anything whose pairing credential we cannot hold as a
    token on the phone** — if accepting control requires the
    owner's vendor-account password inside our app, it is out.
    Pairing prompts and PINs on the target screen are in;
    passwords are not.
  - Gaming (SC-IN-06) and any safety-relevant screen (medical,
    vehicle, industrial control): key injection at 150 ms through
    three radios is a media remote, full stop.

## 9. Failure and privacy posture

- SC-SEC-01 — **LAN-scoped, pairing-bound.** Discovery runs only
  on the phone's current local network; tokens live in
  app-private storage, are never synced, exported, or logged
  (session logs record target *names* and actions, never tokens);
  leaving the network leaves the targets behind — there is no
  roam-home path in v1.
- SC-SEC-02 — **Session end conditions**, any one ends the
  session and says so: explicit exit (§7); glasses BLE drop —
  the input source is gone (FW-FAIL-01 also clears SC-FW-01's
  flag), and the phone alone in the mode is just the app's
  ordinary remote surface, not Screen Control; LAN change or
  target unreachable after 3 failed sends (picker offered again,
  §7); IMP control-session expiry on the IR path (§5). No
  session survives its input, its network, or its grant.
- SC-SEC-03 — **Blast radius, stated plainly:** a control session
  can send the keys of a remote — including, on platforms whose
  owners disabled purchase PINs, the keys that complete a
  purchase. The protocol cannot fix a platform setting; the
  target card for key-injection transports carries one line —
  "Keep your TV's purchase PIN on; anything a remote can press,
  this can press." Wrong-target risk (two TVs, one home) is
  handled by SC-UX-03's announced rejoin and the persistent HUD
  target name — the wearer always knows which screen a tap is
  about to hit, because the mode tells them before it matters.
- SC-SEC-04 — The IR path inherits §5's whole posture: holder-
  opened, banner-shown, countdown-bound, journaled. There is no
  configuration of this feature in which any device transmits,
  injects, or pairs silently.

## 10. Open items

**Genuinely the founder's** (defaults hold until he rules):

| # | Item | Default in this spec |
|---|---|---|
| SC-1 | **The Pair IMP amendment (SC-IR-04):** a holder-opened, 30-min, banner-shown *Screen Control* session on the IMP inside which the phone may send named remote-profile keys (`ir_key`, ≤2/s, every send displayed + journaled) — amending PI-CTL-03's no-verb rule for this one bounded class. Without it, IR control degrades to per-send confirms on the IMP. | Adopt as specced in SC-IR-04; PI-CTL-03 stands untouched outside a session |
| SC-2 | Temple-only entry to control mode (SC-UX-01) — v1 enters by voice or app only; a temple gesture entry would need SW1 double-press, which is T2's hands-free Ask by default in FIRMWARE.md §14. | Voice + app entry only |

**Covered by defaults** (flagged OPEN inline, no ruling needed
unless the founder objects): pointer gain/smoothing reuse the §5
gesture tuning (SC-IN-01), SW2 double-tap = recentre (SC-IN-05),
SW2 long-press = exit in mode (SC-IN-07), 30-min IMP session
length and 2 keys/s cap (SC-IR-04), 3-failed-sends session end
(SC-SEC-02).
