# IMP-VISION — Pair IMP protocol spec (draft, 2026-11-20)

Status: **specification, not code.** Defines how an IMP-1 / IMP-2
pairs with the IMP-VISION app and streams its tool readouts into the
glasses' HUD, the app timeline, and the session log.

**This protocol is an IMP firmware PHASE-2 addition.** The IMP-1
build-1 firmware (v2 UX layer, `BUILD_REPORT_V2.md`, 2026-11-18) is
**frozen** and implements none of it — build 1 has no BLE link
service at all. Nothing in this document changes build 1. The
protocol lands when IMP firmware phase 2 opens, and the schema is
written to cover IMP-2's fitted tools (native 125 kHz, iButton)
from the start so the app never needs a second dialect.

Conventions mirror `designs/temple-f/FIRMWARE.md`: requirements are
numbered `PI-<BLOCK>-<nn>`; an item marked **OPEN** carries a
recommended default, and the default governs unless founder rules
otherwise. Items that genuinely need a ruling are collected in §9.

Posture (from `app-design.md` §3/§6): measure-and-record. The IMP's
readings are readings — rendered in plain words, never dressed up.
Buyer-facing strings reuse the IMP-1 firmware's own wording table
(Card ID, not UID; Listen, not RX; Send, not TX) so the glasses
speak the same language as the device in the user's other hand.

## 1. Topology — the phone is the hub

- PI-TOP-01 — There are exactly two links: **IMP ↔ phone** and
  **glasses ↔ phone**. The app merges both into one session. There
  is **no direct IMP ↔ glasses link in v1.**
- PI-TOP-02 — Why, in one line: one radio budget, one session log,
  one pairing UX — a third link buys nothing the hub can't do and
  costs a second bond, a second clock, and a second failure mode
  on a temple battery that can't afford any of them.
- PI-TOP-03 — Consequences the rest of the spec relies on:
  - The glasses never see IMP traffic. A lost or absent pair of
    glasses changes nothing about IMP pairing or logging.
  - The IMP never sees glasses traffic. It cannot tell whether its
    events are being shown on a HUD, a phone screen, or nothing.
  - Every merge decision (ordering, dedup, rendering) is the
    phone's. The IMP's whole job is: emit well-formed events,
    accept the small command set of §7, keep its own confirms.

## 2. Transport — BLE GATT, IMP side

- PI-TRN-01 — BLE 5 GATT between the IMP and the phone, consistent
  with the glasses link conventions (FIRMWARE.md §2): bonding is
  mandatory, every characteristic except the advertising identity
  requires an encrypted, bonded link, and the IMP accepts **one**
  bonded phone. **OPEN** (default: one phone; a second bond is a
  founder call, §9).
- PI-TRN-02 — One custom 128-bit **IMP Link** service, four
  characteristics:
  - **Events** (notify, IMP → phone): the event stream of §3.
  - **Control** (write, phone → IMP): the command set of §7, and
    nothing else.
  - **Status** (notify + read): IMP state — firmware phase, fitted
    tools bitmask, active tool, battery, SD state, link journal
    depth (§8). Sent on connect and on change.
  - **Journal** (notify, IMP → phone): store-and-forward backfill
    (§8), same envelope as Events, flagged `backfill`.
- PI-TRN-03 — The IMP-1's ESP32-S3 already carries BLE hardware;
  phase 2 adds this GATT server in the IMP firmware. The frozen
  build-1 pin map and API are untouched by the addition (the v2
  report's "no Wi-Fi update tool" stance stands: this link carries
  readouts and session commands, never firmware).
- PI-TRN-04 — Connection behaviour mirrors FIRMWARE.md FW-BLE-06:
  fast reconnect advertising (100 ms, 10 s) then normal (1 s);
  supervision timeout 4 s; on timeout §8 applies. The IMP's local
  UI never blocks on the link — a tool in hand outranks a phone
  that isn't there.

## 3. Event model

- PI-EVT-01 — Every readout is one **event**: a fixed header plus a
  small typed payload. One event fits one BLE notification
  (PI-EVT-05); there is no multi-event batching in v1.
- PI-EVT-02 — **Envelope** (binary header, payload CBOR map):

  | Field | Type | Meaning |
  |---|---|---|
  | `v` | u8 | Protocol version (1) |
  | `dev` | u8 enum + name in Status | Source device: 1 = IMP-1, 2 = IMP-2 |
  | `seq` | u32 | Per-device monotonic sequence, survives reboot (persisted counter) |
  | `mono` | u32 | Milliseconds since IMP boot, for intra-device ordering |
  | `tool` | u8 enum | §4 tool ids |
  | `type` | u8 enum | Per-tool event type (§4) |
  | `flags` | u8 | bit0 `backfill`, bit1 `priority` (spoken-cue eligible, §6), bit2 `confirmed_action` (event reports an action the IMP's own §4-style confirm already gated locally) |
  | `payload` | CBOR map | Per §4; may be empty |

  The phone stamps **wall-clock time on receipt** and stores both
  clocks (§5). The IMP has no trustworthy wall clock and the
  protocol does not pretend otherwise.
- PI-EVT-03 — Event classes, uniform across tools:
  `session` (tool opened/closed on the IMP), `state` (listening,
  idle, busy, waiting-for-press), `reading` (a measured thing),
  `result` (an action the IMP took locally, completed), `error`
  (the IMP's three-line error pattern, compressed: code + one
  plain line).
- PI-EVT-04 — **Readings, not interpretations.** A payload carries
  what the tool measured. If the IMP firmware itself names a
  protocol or tag type, the payload carries its confidence as the
  firmware reports it; the app renders the name with the number,
  never bare (the IR Watch emitter-first rule, generalised).
- PI-EVT-05 — **Size ceiling: 200 bytes payload, 244 bytes on the
  wire** (ATT MTU 247 target). Anything bigger is not an event —
  it is a file on the IMP's SD card, and the event carries a
  reference (`ref`: archive path + byte size + CRC32). Raw Sub-GHz
  captures, flash copies, and NFC page dumps are references, always.
  **OPEN** (default as stated; a 512-byte fragmented class for NFC
  tag summaries was considered and rejected — the reference does
  the same job without a fragmentation layer).
- PI-EVT-06 — Rate caps. Per-tool defaults in §4; global ceiling
  **20 events/s**, beyond which the IMP collapses repeats into a
  `digest` event (tool, count, strongest/first/last reading)
  rather than dropping silently. **OPEN** (defaults in §4 table).

## 4. Per-tool payloads

Tool ids: `subghz` 1, `nfc` 2, `ir` 3, `rfid125` 4, `ibutton` 5,
`flash` 6, `audit` 7, `badusb` 8, `gpio` 9, `u2f` 10, `onewire` 11.
Payloads list the fields the v2 firmware's tools actually produce;
a field the firmware cannot fill is omitted, never zero-filled.

### 4.1 Sub-GHz (CC1101) — fitted, build 1

| Type | Payload | Notes |
|---|---|---|
| `state` | `mode`: listen / idle | Strip word on the IMP is LISTEN |
| `reading` | `freq_hz` u32, `rssi_dbm` i8, `mod` enum (ook, fsk, unknown), `proto` text? , `proto_conf` u8%? , `ref`? | A detected signal. `proto` only when the IMP's decoder names one (e.g. a Princeton-class remote), always with `proto_conf`. Capture saved on the IMP ⇒ `ref` set |
| `result` | `action`: saved / sent, `freq_hz`, `ref` | `sent` carries flag `confirmed_action` — the Send confirm happened on the IMP (§7) |

Rate: hits stream; cap 10/s then digest. Build-1 limitation
stands (capture fidelity, v2 report L1): the payload promises
frequency + RSSI + decoder's best name, not a decode guarantee.

### 4.2 NFC (ST25R3916) — fitted, build 1

| Type | Payload | Notes |
|---|---|---|
| `reading` | `uid` bytes (Card ID), `tech` enum (iso14443a, …), `atqa` u16, `sak` u8, `tag_type` text? , `tag_conf` u8%? | Tag in field. Type guess (NTAG / Ultralight / Classic …) rendered with confidence; the MIFARE Classic limit is the IMP's own wording, reused verbatim on the app card |
| `result` | `action`: copied / write_tested, `blocks` u16, `verified` bool, `ref`? | Copy dump lives on SD ⇒ `ref`. Write test is `confirmed_action` |

Rate: snapshot per tag presentation (dedup same UID within 3 s).

### 4.3 IR — fitted, build 1

| Type | Payload | Notes |
|---|---|---|
| `reading` | `proto` text (NEC, RC5, Samsung, …), `addr` u32, `cmd` u32 | A decoded receive while listening/learning |
| `result` | `action`: learned_saved / sent, `proto`, `addr`, `cmd`, `ref`? | `sent` is `confirmed_action`; learned signals auto-save only inside the IMP's own guided flow, exactly as build 1 behaves |

Rate: snapshot. IR has no scan class; nothing streams.

### 4.4 RFID 125 kHz — IMP-2 fitted; NOT fitted on IMP-1 build 1

The IMP-1 tool is a guarded stub ("NOT FITTED — IMP-2"). The
schema is defined now so IMP-2 firmware emits it unchanged.

| Type | Payload | Notes |
|---|---|---|
| `reading` | `id` u64, `format` enum (em4100, hid_prox, t5577, unknown), `facility` u16?, `card_no` u32? | Read-only event class. There is no write/clone event type and no command (§7) — any such action is IMP-local, IMP-confirmed, and off this protocol entirely |

Rate: snapshot per presentation, 3 s dedup as NFC.

### 4.5 iButton / 1-Wire — IMP-2 fitted; stubs on IMP-1 build 1

| Type | Payload | Notes |
|---|---|---|
| `reading` | `rom` 8 bytes, `family` u8 (0x01 = DS1990 class), `crc_ok` bool | Contact read. `onewire` tool id covers non-iButton 1-Wire sensors if IMP-2 grows them: `reading` {`rom`, `kind`: temp, `value_milli` i32} |

Rate: snapshot.

### 4.6 Flash Lab — fitted, build 1 (snapshot class)

`reading` {`jedec_id` u24, `maker` text, `capacity_kb` u32,
`wp_locked` bool} on Chip ID check; `result` {`action`: copied /
erased / write_tested, `bytes` u32, `ref`} — copies are SD files
(`ref`), erase/write are `confirmed_action`. No progress stream;
start + result only.

### 4.7 Auto-Audit — fitted, build 1 (passive only)

The IMP tool is passive by design (no deauth/jamming code exists
in the firmware); its events are sightings, nothing more.

| Type | Payload | Notes |
|---|---|---|
| `reading` | `kind`: wifi_ap {`ssid` text, `bssid` 6B, `rssi_dbm`, `chan` u8, `security` enum} / ble_dev {`addr` 6B, `addr_type` u8, `name` text?, `rssi_dbm`} | Dedup by BSSID / address per scan session |
| `result` | `action`: scan_complete, `wifi_count` u16, `ble_count` u16 | Plus `checklist` {`item` text, `state` enum} events for the Safety checks list |

Rate: sightings capped at **2/s aggregate**, digest beyond — the
HUD shows counts (§6), the app card holds the list.

### 4.8 BadUSB, GPIO, U2F — fitted, build 1 (session class)

- `badusb`: `session` {script name} on run start, `result`
  {`action`: run_complete} on end. Both are `confirmed_action`
  reports (the RUN/TYPE confirm is IMP-local, §7). The protocol
  has **no** command that starts a script.
- `gpio`: `state` {`pin` u8, `mode` enum, `level` u8?} on claim
  (claim is `confirmed_action`) and on toggle. Low value, low
  rate; included so the timeline is complete.
- `u2f`: `state` {`mode`: waiting_for_press} when the IMP is
  blocked on its presence prompt, `result` {`action`:
  presence_confirmed} when the user presses on the IMP. The
  waiting event is `priority` — it is the one IMP event whose
  whole point is to reach the wearer's ear (§6). There is no
  command and no event by which presence can be supplied
  remotely; that would defeat the control.

## 5. Session merge — one timeline, one export

- PI-SES-01 — The app already logs sessions as JSONL
  (`sessions.jsonl`, with `/api/export`). Pair IMP extends that
  file; there is no second log. Every line, glasses-native or IMP,
  shares one envelope:

  ```json
  {"ts": 1763672400123, "session": "s-2026-11-20-1430",
   "src": "imp", "dev": "imp1", "seq": 412, "mono_ms": 882131,
   "tool": "nfc", "type": "reading",
   "hud": "NFC · Card 04:A3:B2:C1 · NTAG215?",
   "spoken": "NFC card read.",
   "payload": {"uid": "04A3B2C1", "tag_type": "NTAG215", "tag_conf": 90},
   "ref": null, "backfill": false}
  ```

- PI-SES-02 — **Schema delta** over the existing glasses-only
  lines: add `src` (`glasses` | `imp`), `dev`, `seq`, `mono_ms`,
  `tool`, `type`, `hud` (the exact line rendered, §6), `spoken`
  (the exact cue spoken, or null), `ref` (pointer to an attachment
  or an IMP SD path), `backfill`. Glasses-native events use
  `src: "glasses"`, `tool` in the existing sense vocabulary
  (`glasses.camera`, `glasses.irwatch`, `glasses.thermal`, …) and
  `seq` from the phone's own counter.
- PI-SES-03 — Ordering and dedup: the timeline sorts by phone
  receipt `ts`; within a burst, `(dev, seq)` is the stable order.
  Dedup key is `(dev, seq)` — a backfilled event that also arrived
  live is stored once. `mono_ms` is kept so an IMP burst can be
  re-ordered exactly even if notifications arrived coalesced.
- PI-SES-04 — One session spans both devices: opening a session in
  the app (or the first event from either side, per the app's
  existing rule) starts it; the merged timeline interleaves
  glasses sense events and IMP events in receipt order. A session
  closes on user action, or when both links have been down for
  10 minutes — never with an IMP segment left "open" (§8).
- PI-SES-05 — Export is the same JSONL plus its attachment folder
  (glasses frames/stills). IMP `ref` payloads export as the
  reference record (path, size, CRC32) — the file itself moves
  when the user pulls it from the IMP's Archive over USB/SD, and
  the app notes it as `ref_unfetched` until then. **OPEN**
  (default: reference-only export; auto-fetch over BLE was
  rejected — bulk transfer is not what this link is for).

## 6. Rendering — HUD line, app card, spoken cue

Every event type renders three ways from the same payload. The
phone renders; the IMP supplies data and (for its own tool names)
the buyer-wording strings.

- PI-REN-01 — **HUD card line** (display variants): one line,
  edge-pinned, centre clear, ≤ 30 characters of big type, format
  `Tool · primary reading · qualifier`:

  | Tool | HUD line |
  |---|---|
  | Sub-GHz hit | `Sub-GHz · 433.92 MHz · −58 dBm` |
  | Sub-GHz digest | `Sub-GHz · 12 signals · strongest −41` |
  | NFC | `NFC · Card 04:A3:B2:C1 · NTAG215?` (the `?` is the confidence, worn openly) |
  | IR learned | `IR · NEC 20DF · saved` |
  | 125 kHz | `125 kHz · EM4100 · …345678` |
  | iButton | `iButton · DS1990 · …C1` |
  | Flash | `Flash · W25Q64 · 8 MB · unlocked` |
  | Audit | `Wi-Fi · 14 networks` / `Bluetooth · 6 devices` (counts, never a scroll of sightings) |
  | U2F waiting | `IMP · sign-in key waiting` |
  | Error | `IMP · <tool> needs you` (detail lives on the app card and the IMP's own screen) |

  A HUD line shows for the app's standard card dwell, then clears;
  it never stacks more than one IMP line at a time — newest wins,
  the timeline keeps the rest.
- PI-REN-02 — **App timeline entry / expanded card**: the full
  payload in buyer words, the IMP's plain label first and the
  technical value in a Details line (the IMP firmware's own
  convention), plus: timestamp, device name, `ref` with a
  "on the IMP" marker, and for `result` events the
  `confirmed on the IMP` note where `confirmed_action` is set.
- PI-REN-03 — **Spoken cue** (audio-only variants, and display
  variants with audio on): only `priority` events speak.
  Defaults: NFC read, 125 kHz read, iButton read, U2F waiting,
  IMP errors, and Sub-GHz hits **only** when the user has armed
  "speak RF hits" in the app (default off — an RF-dense room
  would talk over everything). Cue format is one short clause:
  "NFC card read." / "Sub-GHz signal, 433 megahertz." / "IMP is
  waiting for a press." Cues are generated by the phone (Piper,
  per the app architecture); the IMP has no speech. **OPEN**
  (default priority set as above; the set is the founder's to trim).

## 7. Control direction — a front-end, not a remote trigger

- PI-CTL-01 — The Control characteristic accepts exactly these
  verbs, all **session/passive class**:
  `link_hello` (version + Status pull), `scan_start` /
  `scan_stop` with a tool argument from the scan-capable set —
  **Sub-GHz listen, NFC poll, Auto-Audit scan** — `state_query`,
  `journal_pull` (§8). There are no other verbs in v1.
- PI-CTL-02 — A scan request is a *request the IMP displays*: the
  IMP shows the incoming request on its own screen and starts the
  listen, reporting `state` back. This mirrors the IMP firmware's
  own rule that reads/listens start immediately — but nothing on
  the IMP ever starts **silently**: the tool screen opens, the
  status strip shows LISTEN/READY, and the IMP's local BACK stops
  it like any local session. Local input always wins: if the user
  is mid-task on the IMP, it answers `error {code: busy}` and the
  app says so in plain words.
- PI-CTL-03 — **Everything the IMP gates behind its own
  confirmation stays IMP-local, without exception.** The command
  set contains no verb for, and no event flow can substitute for:
  Sub-GHz **Send**, IR **Send**, NFC **write test**, Flash
  **erase / write**, BadUSB **run / type**, GPIO **claim**, U2F
  **presence**. The glasses can watch these happen (the `result`
  events of §4 report them, flagged `confirmed_action`); they can
  never ask for them, pre-arm them, or supply the confirm. The
  temple buttons inherit this exactly: a temple press can
  start/stop a scan class via the app, and can do nothing else to
  the IMP.
- PI-CTL-04 — Rationale, stated once so it doesn't get relitigated
  per tool: the glasses are eyes, ears, HUD and log. A transmit,
  write, or keystroke action is taken by the person holding the
  device that performs it, looking at that device's own confirm
  screen — the same "no silent action" rule the IMP firmware
  already enforces locally, extended across the link unchanged.

## 8. Pairing, security, loss

- PI-SEC-01 — Pairing is initiated from the app (the Pair IMP
  screen) and completed **on the IMP**: the IMP shows a pairing
  prompt that a person holding it accepts (physical-presence
  rule, mirroring the glasses' SW1+SW2 hold in FW-BLE-01). No
  pairing completes from the phone side alone.
- PI-SEC-02 — Per-device identity: the IMP advertises and bonds
  under its owner-set name (`IMP-1 · <name>`), reported in Status
  with firmware phase and fitted-tools bitmask, so the app can
  show "IMP-1, 9 tools fitted, RFID not fitted" instead of
  guessing. The app keeps one bond record per `dev` identity.
- PI-SEC-03 — Link drop: the IMP keeps working locally (PI-TRN-04)
  and **journals** events to its SD card (the Archive store) in
  envelope order. On reconnect, the phone issues `journal_pull`;
  journaled events arrive on the Journal characteristic flagged
  `backfill`, are deduped by `(dev, seq)` (§5), and slot into the
  timeline by their receipt-stamp rule with `backfill: true`
  visible on the card. **OPEN** (default: SD journal, unbounded
  within card space, oldest-segment rollover; a RAM ring was
  rejected — it dies with the battery, which is when backfill
  matters most).
- PI-SEC-04 — Unpair / bond removed on either side: the IMP stops
  the IMP Link service advertising until a person re-enters
  pairing from the IMP's own menu; the journal stays on the card
  (it is the user's data, on the user's device) but nothing leaves
  the IMP. The app marks the device "unpaired" and closes any open
  merged session segment for it.
- PI-SEC-05 — **Fail quiet, no orphan sessions.** A lost IMP, a
  lost pair of glasses, or a dead phone each degrade the system to
  the remaining local devices doing their local jobs. No session
  is left open-ended by a disappearance (§5 PI-SES-04), no event
  is emitted by a device that has no bonded peer about a peer it
  cannot see, and no device retries a dead link forever
  (FW-FAIL-01 cadence applies by analogy).
- PI-SEC-06 — The link carries readouts and the §7 verbs only.
  It is not an update channel (PI-TRN-03), not a file channel
  (PI-EVT-05), and not a control channel for any action class
  beyond §7 — by construction, not by policy text: the verbs do
  not exist.

## 9. Open items

**Genuinely the founder's** (defaults hold until he rules):

| # | Item | Default in this spec |
|---|---|---|
| P1 | Second phone bond (PI-TRN-01) — ever, or one phone per IMP permanently? | One phone |
| P2 | Spoken-cue priority set (PI-REN-03) — which IMP events may speak uninvited? | NFC / 125 kHz / iButton reads, U2F waiting, errors; RF hits opt-in only |
| P3 | Journal retention (PI-SEC-03) — SD journal size cap / rollover age? | Unbounded within card, oldest-first rollover |
| P4 | IMP-2 tool sign-off (§4.4/§4.5) — payload fields for 125 kHz + iButton to be confirmed against IMP-2 firmware when it is written | As specced here |

**Covered by defaults** (flagged OPEN inline, no ruling needed
unless the founder objects): payload ceiling 200 B / reference-not-bulk
(PI-EVT-05), global 20 events/s cap with digest rollup
(PI-EVT-06), per-tool rate caps (§4), reference-only session
export (PI-SES-05), stream-vs-snapshot split — **stream**:
Sub-GHz hits, Auto-Audit sightings; **snapshot**: NFC, IR,
125 kHz, iButton, Flash, BadUSB, GPIO, U2F (§4).
