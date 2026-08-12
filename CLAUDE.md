# CLAUDE.md — Project Context for Labour Attendance

> **This file is the single source of truth for project context.**
> **It MUST be updated at the end of every session, and after every change, fix, or improvement.**
> See [§14 — Keeping This File Current](#14-keeping-this-file-current) for the required procedure. Do not skip it.

**Last updated:** 2026-08-12
**Last commit at time of writing:** `b1ff3dd` — *docs: update README with project description and strengthen proprietary license terms*
**Working tree:** substantial uncommitted changes (Part 1 of `improvement.md` — see §13)
**Deployed:** `firestore.rules` live and **closed** on `labour-mgmt-ai-mvp-2026` (auth required) — see §8
**Verified on device:** `emulator-5554`, Android 15 — carry-forward and wage history checked on live data
**Branch:** `main`

---

## 1. What This Project Is

A **Flutter + Firebase mobile app for a small labour contractor / electrical contractor** to run daily
workforce administration from a phone, on site, without paperwork.

It answers five questions the owner asks every day:

1. Who worked today? (attendance — full day / half day / absent)
2. Who took cash in advance? (*kharchi*)
3. What do I owe each worker this month? (opening + salary − advances − paid)
4. What did I actually pay, and what carries into next month? (settlements)
5. Who changed what, and when? (audit trail)

**Operating context:** in-house, single-operator tool. One trusted person (the owner/*thekedar*) holds the
device. There is no login screen, no multi-tenant concept, and no public distribution. Licence is
**proprietary, in-house use only** (see `LICENSE`). Deployment target is Udaipur, Rajasthan, India — Hindi/Mewari
speaking crews, INR currency, patchy rural connectivity. This context matters for every design decision;
see `improvement.md` for the researched breakdown.

**Repo note:** the directory is spelled `labour-attandance` (typo, historical). The Dart package is
`labour_attendance`. Do not "fix" the directory name — it will break local tooling paths.

---

## 2. Tech Stack

| Layer | Choice | Version |
|---|---|---|
| Framework | Flutter | 3.38.7 (stable), engine rev `78fc3012e4` |
| Language | Dart | 3.10.7 (`sdk: ^3.10.7`) |
| Backend | Cloud Firestore | `cloud_firestore ^6.2.0` |
| Firebase core | `firebase_core` | `^4.6.0` |
| Auth | `firebase_auth` | `^6.5.7` — anonymous only |
| State management | `provider` (ChangeNotifier) | `^6.1.5+1` |
| Hashing | `crypto` | `^3.0.7` — PBKDF2 for the passcode |
| Device secrets | `flutter_secure_storage` | **`^10.0.0` — pinned, see §9** |
| Biometrics | `local_auth` | `^3.0.2` (optional unlock) |
| Build info | `package_info_plus` | `^10.2.1` |
| Sharing | `share_plus` | `^13.3.0` |
| Files | `path_provider` | `^2.1.6` |
| PDF | `pdf` | `^3.12.0` (no `printing` — bytes are shared directly) |
| Lints | `flutter_lints` | `^6.0.0` (default ruleset) |
| Icons | `flutter_launcher_icons` | `^0.13.1` |
| App version | `pubspec.yaml` | `0.2.0+2` (Settings reads this at runtime — no hardcoded copy) |

**Not used (deliberately):** `shared_preferences`, `intl`, routing packages, code generation
(`freezed`/`json_serializable`), dependency injection, charting.
There is still **no `flutter_localizations` / i18n** — all UI strings are hardcoded English literals.
Hindi-first UI is the top item in `improvement.md` Part 2 (A1).

Platform folders exist for android / ios / linux / macos / windows / web scaffolding, but **Android is the only
target that is actually configured and used**.

---

## 3. Commands

```bash
# Setup (first time on a machine)
cp lib/firebase_options.dart.example lib/firebase_options.dart   # then fill in real values
cp android/local.properties.example android/local.properties     # Android SDK path
cp android/key.properties.example android/key.properties         # release signing (optional)

flutter pub get

# Develop
flutter run
flutter analyze                       # currently: "No issues found!" — keep it that way
dart format lib test integration_test # CI fails on unformatted code
dart run flutter_launcher_icons       # regenerate launcher icons from assets/logo.png

# Test
flutter test                          # 63 unit tests, no Firebase needed, ~5s

# Integration tests — prefer the emulator
firebase emulators:start --only firestore,auth
flutter test integration_test/firestore_test.dart -d <deviceId> \
  --dart-define=USE_FIREBASE_EMULATOR=true
#   Without the flag these hit the REAL Firestore project.
#   Add --dart-define=FIREBASE_EMULATOR_HOST=<ip> for a physical device
#   (default 10.0.2.2 is the Android emulator's alias for the host).

# Run the app against the emulator
flutter run --dart-define=USE_FIREBASE_EMULATOR=true

# Build
flutter build apk --release
flutter build appbundle --release

# Firebase
firebase deploy --only firestore:rules
#   ⚠ .firebaserc has NO project configured ({"projects": {}}). Run `firebase use --add` first.
#   ⚠ Enable Anonymous auth in the console BEFORE deploying rules (§8).
```

CI (`.github/workflows/ci.yml`) runs format + analyze + unit tests on push and PR. Integration tests are
not in CI — they need a device.

**Platform note:** development happens on **Windows**. The Bash tool here is Git Bash; PowerShell is the primary
shell. The npm `firebase` shim misbehaves under Git Bash — run `firebase` from PowerShell.

---

## 4. Architecture

Strict layering. Data flows one way: **Firestore → Service → Provider → Screen**.
Screens never touch `FirebaseFirestore.instance`.

```
lib/
├── main.dart                     # Firebase init, theme, MultiProvider, _AppGate (bounded startup)
├── design_tokens.dart            # class DS — colours, type styles, radii, shadows, the CTA gradient
├── firebase_options.dart         # GITIGNORED. Copy from .example.
├── models/                       # Plain Dart classes + fromFirestore()/toMap(). No codegen.
│   ├── worker.dart               #   includes isActive (soft delete)
│   ├── attendance.dart           #   + class AttendanceStatus (canonical strings + dayValue)
│   ├── advance.dart
│   ├── settlement.dart           #   a closed month: opening/salary/advances/paid/closing
│   ├── monthly_row.dart          #   one worker's payroll position for one month (view model)
│   └── worker_statement.dart     #   one worker's account over an arbitrary date range
├── providers/                    # ChangeNotifier state, injected in main.dart
│   ├── worker_provider.dart      #   LIVE stream of all workers (the only real-time listener)
│   ├── attendance_provider.dart  #   one selected date + a separate "today" view for the dashboard
│   └── summary_provider.dart     #   per-month payroll; 4 queries total, cached per month
├── screens/
│   ├── main_screen.dart          # Shell: IndexedStack + custom bottom nav + SyncBanner
│   ├── home_screen.dart          # Tab 0 — dashboard (all figures live)
│   ├── worker_list_screen.dart   # Tab 1 — worker CRUD; also hosts showWorkerForm()
│   ├── advance_screen.dart       # Tab 2 — record/edit/delete advances, calculator keypad
│   ├── summary_screen.dart       # Tab 3 — monthly payroll, settle flow, CSV/PDF export
│   ├── attendance_screen.dart    # PUSHED — daily marking
│   ├── worker_profile_screen.dart# PUSHED — per-worker month history + calendar
│   ├── settings_screen.dart      # PUSHED — passcode, biometrics, audit link, version
│   ├── passcode_screen.dart      # Full-screen lock with lockout + biometric
│   └── audit_log_screen.dart     # PUSHED — paged edit history
├── services/                     # Singletons (factory constructor returning a static _instance)
│   ├── firestore_service.dart    # ALL reads/writes. Audit logging lives here, not in screens.
│   ├── auth_service.dart         # anonymous sign-in; supplies createdBy/changedBy
│   ├── audit_service.dart        # audit_log writes + paged reads
│   ├── passcode_service.dart     # PBKDF2 + secure storage + lockout + biometrics
│   ├── export_service.dart       # CSV/PDF build + share sheet
│   ├── sync_status.dart          # pending-write count + online/offline (a ChangeNotifier singleton)
│   └── emulator_config.dart      # opt-in redirect to the Firebase Emulator Suite
├── utils/                        # Pure functions. No Flutter, no Firebase — unit tested.
│   ├── dates.dart                #   dateKey / monthKey / display helpers
│   ├── money.dart                #   int rupees, Indian digit grouping
│   └── payroll.dart              #   openingBalances() / computeMonthlyRows() /
│                                 #   buildWorkerStatement() — THE payroll calculations
└── widgets/
    └── sync_banner.dart          # shared offline/pending strip
```

`utils/` and `widgets/` are new. Screen-local private widgets still live at the bottom of their screen
file with a `// ── Name ──` banner; only genuinely shared widgets go in `widgets/`.

### Navigation model — unchanged quirk

Two mechanisms are still mixed:

- **Tabs** (Home / Workers / Payroll / Reports) are an `IndexedStack` in `MainScreenState`; `setIndex(i)` switches.
- Tab screens' back arrows reach up with
  `context.findAncestorStateOfType<MainScreenState>()?.setIndex(0)`, falling back to `Navigator.pop`.
- **Attendance, Worker Profile, Settings and Audit Log are pushed routes**, so they cover the bottom nav.

`findAncestorStateOfType` is fragile — a widget-tree restructure breaks back buttons silently.

---

## 5. Firestore Data Model

Six top-level collections. No subcollections.

### `workers/{autoId}`
| Field | Type | Notes |
|---|---|---|
| `name` | string | 1–80 chars (enforced by rules) |
| `type` | string | Free text trade: "Mason", "Helper", "Electrician"… drives badge colour |
| `dailyWage` | number | **whole rupees** — the *current* rate |
| `wageHistory` | list | `[{from: 'YYYY-MM-DD', wage: number}]`, newest first. Absent until the rate is first changed. See §6 |
| `isActive` | bool | Soft delete. **Absent = active** (legacy docs) |
| `createdBy` | string | auth uid (legacy rows say `'admin_1'`) |
| `createdAt` | Timestamp | |

### `attendance/{workerId}_{YYYY-MM-DD}`  ← **composite document ID**
| Field | Type | Notes |
|---|---|---|
| `workerId` | string | |
| `date` | string | `YYYY-MM-DD` |
| `month` | string | `YYYY-MM` — must equal `date[0:7]` (enforced by rules) |
| `status` | string | `'present'` \| `'half_day'` \| `'absent'` |
| `createdBy` | string | auth uid |

The composite ID makes re-marking **idempotent**. **The rules now enforce that the document id equals
`{workerId}_{date}`** — it is no longer merely a client convention.

### `advances/{autoId}`
`workerId`, `amount` (number, > 0, whole rupees), `date` (`YYYY-MM-DD`), `month` (`YYYY-MM`), `createdBy`.
Auto-ID, so duplicates are possible — intentional (a worker may draw twice in a day).

### `settlements/{workerId}_{YYYY-MM}`  ← **composite document ID**
| Field | Type | Notes |
|---|---|---|
| `workerId`, `month` | string | |
| `opening` | number | balance carried in from the previous month (may be negative) |
| `salary` | number | earnings at the wage in force when settled |
| `advances` | number | kharchi drawn in the month |
| `paid` | number | cash actually handed over |
| `closing` | number | **must equal `opening + salary − advances − paid`** (enforced by rules) |
| `mode` | string | `'cash'` \| `'upi'` \| `'bank'` |
| `note`, `createdBy` | string | |
| `settledAt` | Timestamp | |

This is what makes balances carry forward. Storing `closing` explicitly avoids replaying history — a
worker's `dailyWage` changes over time, so old attendance must not be re-priced at today's rate.

### `audit_log/{autoId}`
`action` (`{collection}_{created|updated|deleted}`), `collectionName`, `documentId`, `workerId`,
`before` (map \| null), `after` (map \| null), `changedBy` (auth uid), `changedAt` (`serverTimestamp`).

**All four data collections are audited** — workers, attendance, advances and settlements. Writes go
through `FirestoreService`, which logs on the caller's behalf. The collection is **append-only**: rules
deny update and delete to every client, including this app.

### `settings/passcode` — **legacy, being removed**
The passcode now lives in device secure storage. `PasscodeService` reads this document once, migrates
it, then deletes it. Rules allow read and delete but **no writes**.

### Indexes
`firestore.indexes.json` is intentionally **empty**. Every query in the app is single-field equality or
a document-id lookup, all served by automatic indexes. Adding a `where` + `orderBy` combination means
adding an index here in the same change.

---

## 6. Business Rules

- **Day value:** `present = 1.0`, `half_day = 0.5`, `absent = 0.0`. Unmarked days count as nothing.
  Canonical strings live in `AttendanceStatus`; `AttendanceStatus.dayValue()` is the only place the
  mapping exists.
- **Money is `int` whole rupees.** The business has no paise. Firestore stores them as `number`;
  `asRupees()` reads legacy doubles back correctly, so **no data migration was needed**.
- **Salary:** each day is priced at the rate in force **on that day** (`Worker.wageOn(date)`), the
  amounts are summed, and the result is rounded once at the end (2.5 days × ₹655 = ₹1637.50 → ₹1638).
- **Wage history.** `dailyWage` is the *current* rate; `wageHistory` records effective-dated changes,
  newest first, and `wageOn()` returns the first entry whose `from` is on or before the date.
  - *Why:* changing the rate used to re-price **every unsettled day the worker had ever worked** —
    raising Jagdish from ₹600 to ₹650 in August silently made his April–July days worth ₹650 too
    (₹3,300 of phantom earnings on real data). Historical pay is a record of what was agreed and must
    not move because of a decision taken later.
  - A worker with **no** `wageHistory` has never had a rate change, so `dailyWage` correctly applies to
    all their days. The first change writes *two* entries: the new rate from its effective date, and a
    baseline at `0000-01-01` carrying the old rate.
  - The edit form asks **when** a new rate starts (this month / today / next month / "correct a
    mistake"). "Correct a mistake" collapses history to a single all-time entry and *does* re-price
    unsettled past work — that is its purpose.
  - Rates are per *day*, so a change mid-month splits the month correctly.
  - **Every period-scoped screen shows the rate for that period**, via
    `MonthlyRow.rate` / `ratesApplied` and `rateLabel()`. Never label a past month with
    `worker.dailyWage` — a July card reading "₹650/day" beside 16 days and ₹9,600 contradicts its own
    arithmetic and reads as a bug. The worker *list* is the exception: it has no period, so it shows
    the current rate.
- **Balance:** `opening + salary − advances − paid`.
- **Carry-forward:** `opening` is the running total of **every month before this one**, from
  `openingBalances()` — not just the previous month. Each prior month contributes
  `salary − advances − paid`, taken from the **settlement** if that month was settled, otherwise
  computed from its attendance and advances.
  - *Why:* reading only the previous month's settlement meant any month nobody had settled contributed
    nothing, so a worker owed ₹4,200 for July started August at zero and the debt vanished. Contractors
    do not settle every month on the nose.
  - *Consequence:* **back-dated attendance is picked up automatically** in an unsettled month — the
    common case when a worker is added to the app a few days after joining. Back-dating into a
    **settled** month does *not* move the balance; reopen the month first.
  - Unsettled past months are priced day by day through `wageOn()`, so a later raise does not reach
    back. Settling a month freezes its figures regardless.
- **A month is closed** by writing a settlement (Payroll tab → RECORD PAYMENT). Reopening deletes it.
- **Statements are date-range, not month-bound.** `buildWorkerStatement()` slices a worker's whole
  history between any two dates and reports full/half/absent/unmarked days, advances with their dates,
  payments, brought-forward balance and pending amount.
- **PDFs are previewed before they are shared.** Both exports open `PdfPreviewScreen` (rendered by
  `printing`) with a SHARE button and print/save-as-PDF; nothing reaches the share sheet unseen. CSV
  goes straight to the share sheet — there is nothing to preview.
- **All dates are device-local.** No timezone handling; only `changedAt` uses `serverTimestamp`.
- The calculation lives in `lib/utils/payroll.dart` as a pure function and is covered by
  `test/payroll_test.dart`. **Change it there, and add a test in the same commit.**

### Attendance gesture language
| Gesture | Result |
|---|---|
| **Tap** | present |
| **Long press** | absent |
| **Swipe left** (endToStart `Dismissible`, `confirmDismiss` returns `false`) | half day |

Marks write **immediately and optimistically**; the Firestore write is deliberately **not awaited**
(see §9). The floating button now says **DONE**, not ✓-save, and the overlay reports what actually
happened ("Saved on this phone. Will sync when back online.") rather than always claiming success.

---

## 7. Design System

**"The Industrial Atelier"**, specified in [`ui_screens/guild_gear/DESIGN.md`](ui_screens/guild_gear/DESIGN.md).
Read it before touching UI.

- **No 1px sectioning borders.** Separate content with surface-tone shifts and whitespace.
- **Surfaces stack like paper:** `surface` (#FAF9F6) → `surfaceContainerLow` (#F4F3F0) → `surfaceContainerLowest` (#FFFFFF).
- **Dark "command centre" headers:** `primaryContainer` (#121826), asymmetric padding `fromLTRB(24, 56, 24, 20)`,
  often with the first card pulled up via `Transform.translate`.
- **64px tap targets** for primary actions and inputs.
- **Gradient CTAs:** use `DS.ctaGradient` + `DS.buttonShadow`.
- **Accent semantics:** `DS.green` = present/positive · `DS.error` = absent/negative ·
  `DS.warning` (amber) = half day and advances · `DS.tertiary` (blue) = informational/edit ·
  `DS.reports` (purple) = reporting · `DS.cyan` = plumbing badge.

All tokens live in `lib/design_tokens.dart` as `class DS`. **Use `DS.*`; never hardcode hex in screens.**
The amber/purple/gradient literals that used to be inlined are now tokens.

**Fonts are bundled and actually render.** `assets/fonts/Manrope-Variable.ttf` and
`assets/fonts/Inter-Variable.ttf` are declared in `pubspec.yaml` — one variable file per family carries
every weight w300–w800 via the `wght` axis. (Before this they were referenced everywhere but never
bundled, so the app silently rendered in Roboto.)

**Reference designs:** `ui_screens/*/code.html` + `screen.png`. All of them now have implementations,
including `worker_profile_redesign/`.

---

## 8. Security Posture

Read this before touching anything auth-related.

**Authentication.** The app signs in **anonymously** at startup (`AuthService.ensureSignedIn`). There is
still no login screen — that is a product decision — but Firestore now has an authenticated principal to
check, and `createdBy`/`changedBy` carry a real uid instead of the literal `'admin_1'`.

**Rules — deployed and closed 2026-08-12.** Anonymous sign-in is enabled on the project.

Two layers:

1. **Authentication** — `authorised()` requires `request.auth != null`. Unauthenticated traffic is
   refused outright. Verified: reads of `workers`, `attendance` and `audit_log` without a credential
   all return 403; the same calls with an anonymous token succeed.
2. **Shape validation** — money ranges, date/month key formats, the `status` enum, the composite-id
   invariants for attendance (`{workerId}_{date}`) and settlements (`{workerId}_{month}`), and the
   `closing == opening + salary − advances − paid` equation. `audit_log` is append-only (update and
   delete denied to everyone, this app included). `settings` is read/delete only. Unmatched paths are
   denied.

**Residual risk, stated plainly.** Anyone holding the APK can also obtain an anonymous credential, so
layer 1 raises the bar without being a wall — it stops opportunistic access with the project id, not a
determined attacker who unpacks the app. Layer 2 is what actually protects the payroll from corruption.
The next controls, in order: **Firebase App Check** (Play Integrity), then **phone auth with a uid
allow-list** (`improvement.md` Part 1 §1.3a/b).

**If Firestore suddenly starts returning `PERMISSION_DENIED`,** check in this order: (1) is the device
signed in — Settings → About shows "Signed in · <uid>" or "Not signed in"; (2) is Anonymous sign-in
still enabled in the console; (3) is the Android API key restricted to a package name other than
`com.ai.labour_attendance` (§9); (4) does the document being written satisfy the shape rules.

**Passcode.** Now a real lock, and entirely device-local:
- **PBKDF2-HMAC-SHA256**, 50 000 iterations, per-install 16-byte random salt, run off the UI isolate.
- Stored in **`flutter_secure_storage`**, never in Firestore.
- **Lockout**: 5 failures → 30s, doubling to a 15-minute cap, persisted so a restart does not reset it.
- **Optional biometrics** that always fall back to the PIN.
- On first run, `PasscodeService` migrates the legacy Firestore passcode — the old scheme was
  `base64('labour_mgr_salt_' + pin)`, which is reversible, so the PIN is recovered, re-derived properly,
  and the remote document deleted.

**Secrets kept out of VCS** (`.gitignore`): `lib/firebase_options.dart`, `android/key.properties`,
`android/upload-keystore.jks`, `android/local.properties`. **Never commit these.**

---

## 9. Known Gaps, Dead Code and Traps

Verified against the code, not assumed.

**Traps that will bite you:**
- **Tab screens load before the worker stream arrives.** The shell is an `IndexedStack`, which builds
  *every* tab eagerly — so a tab's `initState`/post-frame load runs while `WorkerProvider` is still
  streaming and sees an **empty** worker list. `SummaryProvider`'s cache is therefore keyed by month
  **and worker-set signature**, never month alone, and refuses to cache a result computed from an empty
  list; `SummaryScreen` reloads whenever that signature changes. Any new screen that derives from
  `workers` needs the same treatment — an unguarded version silently shows an empty month.
- **Time the network, not local work.** `PasscodeService.initialize(networkTimeout:)` bounds *only* the
  Firestore read. An earlier version timed the whole legacy migration at 4s; PBKDF2 (50k iterations)
  plus an isolate spawn on a cold emulator overran it, so the gate gave up, let the user in **unlocked**,
  and the migration then completed in the background — the one launch that imported the passcode was
  the one that didn't enforce it. Caught by actually running the app (2026-08-12). Local work always
  finishes; only the network can hang.
- **`E/FlutterSecureStorage: Key mismatch / Algorithm changed detected` on first launch is expected
  noise**, not a failure. The plugin is migrating its own cipher (RSA18 → AES_GCM) and logs at E level
  while doing so; it then reports `migrateOnAlgorithmChange is enabled. Attempting data migration...`
  and succeeds.
- **`E/GoogleApiManager: Unknown calling package name 'com.google.android.gms'` and
  `Phenotype.API is not available` are emulator artifacts**, not app bugs. They appear on Play-Services
  images and are harmless.
- **Firestore write futures never complete offline.** `set()`/`update()` resolve only on server ack, so
  awaiting one on a no-signal site hangs forever. `AttendanceProvider.mark` therefore issues the write
  **without awaiting** and rolls back in `catchError`. Do not "fix" this by adding an `await`.
  `SyncStatus` counts in-flight writes; `SyncBanner` shows them.
- **`flutter_secure_storage` is pinned to `^10.0.0`.** v11.0.0 requires `compileSdk 37`, which Flutter
  3.38.7 does not target — the build fails with `Failed to find target with hash string 'android-37'`.
  Revisit when Flutter's default compileSdk moves to 37.
- **`applicationId` changed** to `com.ai.labour_attendance` (was `com.example.labour_attendance`).
  Any device with the old build installed gets a *separate* app, not an upgrade. If anonymous sign-in
  starts failing with an API-key error, register the new package in the Firebase console.
- **`firestore.rules` is deployed but `authorised()` returns `true`** — the database is open to anyone
  with the project id until Firebase Auth is provisioned (§8). The validation half is live and verified.
- **Settlement `closing` is validated by the rules.** If a client computes it differently, the write is
  rejected. Use `closingBalance()` from `utils/payroll.dart`.

**Still missing / deliberately not built:**
- **No i18n.** All strings are English literals. Hindi-first UI is `improvement.md` A1.
- **No restore.** Export (CSV/PDF share) exists; scheduled backup and restore-to-a-new-device do not
  (`improvement.md` D2).
- **No overtime, no site/job dimension, no piece rate.** See `improvement.md` Part 2.
- `purgeWorker` deletes sequentially rather than in a `WriteBatch` — fine at this scale, but it is not
  atomic; an interrupted purge leaves a partial delete.
- The trade→colour mapping is duplicated in `worker_list_screen.dart` and `worker_profile_screen.dart`.
- `advance_screen.dart` calls `FirestoreService` directly rather than through a provider — the only
  screen that still does.
- Settling is only reachable from the Payroll tab, not from the worker profile.
- `WorkerProvider.search()` is not debounced (irrelevant at tens of workers).

**Build/config:**
- No ProGuard/R8 rules, no flavors.
- `.firebaserc` still has no project configured; `firebase use --add` before deploying.
- iOS/macOS/web/linux/windows scaffolding is unconfigured and untested.

---

## 10. Code Conventions

- **Services are singletons** via `factory X() => _instance;` + private `X._internal()`.
- **Providers own async state**; screens use `context.watch<T>()` / `read<T>()` / `Consumer<T>`.
- Screens load on entry via `WidgetsBinding.instance.addPostFrameCallback` in `initState`, never a
  direct `context.read` in `initState`.
- **Always guard `BuildContext` across an `await`** with `if (!mounted) return;`. Capture
  `ScaffoldMessenger.of(context)` *before* the await when you need it after.
- **Every write is wrapped in `SyncStatus.instance.track(...)`** so the pending count and error banner
  stay honest, and every screen-level call sites catches and surfaces failures.
- **Never format money or dates by hand.** Use `utils/money.dart` (`rupees`, `formatDays`, `asRupees`)
  and `utils/dates.dart` (`dateKey`, `monthKey`, `displayDayMonth`, …). The old inline
  `padLeft(2, '0')` idiom and the `['JAN', …]` arrays are gone — do not reintroduce them.
- **Payroll arithmetic goes in `utils/payroll.dart`**, never inline in a provider or screen.
- Private widgets are file-local `class _Foo extends StatelessWidget` at the bottom of the screen file
  with a `// ── Name ──` banner. Shared widgets go in `lib/widgets/`.
- Comments use `// ── Section ──` banners for UI regions and `///` dartdoc on services/providers/utils.
- `dart format` is enforced by CI.

---

## 11. Companion Documents

| File | Purpose |
|---|---|
| `CLAUDE.md` (this file) | **Authoritative context.** Architecture, data model, rules, gotchas. |
| `improvement.md` | Remaining engineering work + the researched Udaipur/Rajasthan feature roadmap. |
| `ui_screens/guild_gear/DESIGN.md` | The design system spec. Read before UI work. |
| `README.md` | Setup on a new machine + licence summary. |
| `LICENSE` | Proprietary, in-house use only. |
| `project_summary.md` | **Retired.** Now a stub pointing here. |
| `graphify-out/` | Generated code-graph output, 2026-04-28. Stale, ignore. |

---

## 12. Working Agreements

- **Run `flutter analyze` and `flutter test` before declaring work done.** Baseline: zero analyzer
  issues, 63 passing tests. Run `dart format lib test integration_test` — CI fails otherwise.
- **Do not add a dependency** without noting it in §2 and saying why in the session log.
- **Do not loosen `firestore.rules`.** If a write starts failing, fix the document shape, not the rule.
- **Never commit** `lib/firebase_options.dart`, `android/key.properties`, `android/upload-keystore.jks`,
  `android/local.properties`.
- Integration tests default to **production Firestore**. Use `--dart-define=USE_FIREBASE_EMULATOR=true`.
- When you change a business rule (§6) or the data model (§5), update this file **and a test** in the
  same change.

---

## 13. Session Log

Newest first. One entry per working session. Keep entries short and factual.

### 2026-08-12 (d) — Effective-dated wage history

Prompted by the owner: *"when I update someone's daily wage it applies to all previous months too — I
updated Jagdish from 600 to 650 from the month Aug."* Correct, and it was live.

- **A rate change re-priced every unsettled day the worker had ever worked.** `dailyWage` was a single
  number, so `days × dailyWage` valued April at whatever the rate is today. On real data Jagdish had
  **111 attendance records across Apr–Aug and 66 present days before August**, all silently re-valued
  at ₹650 — **₹3,300 of earnings that were never agreed**. I had recorded this in §6 as an
  "approximation"; that was far too soft a word.
- **Fix:** `Worker.wageHistory` — effective-dated rates, newest first — plus `Worker.wageOn(date)`.
  Every pricing site (`computeMonthlyRows`, `openingBalances`, `buildWorkerStatement`) now values each
  day at the rate in force **on that day**, summing exact amounts and rounding once. A mid-month change
  splits the month correctly. A worker with no history is unaffected: the current rate has always
  applied. The first change writes the new rate *and* a `0000-01-01` baseline carrying the old one.
- **UI:** changing the wage now asks *from when* — this month (recommended) / today / next month /
  "correct a mistake" (red; collapses history and does re-price, which is its purpose). Title reads
  "Raise" or "Change" depending on direction.
- **Rules updated and deployed** to permit `wageHistory` (list, ≤200 entries).
- **Repaired Jagdish through the UI**, so the change is audited: set 600 → "Correct a mistake", then
  650 → "From August 2026". Resulting document: `dailyWage: 650`,
  `wageHistory: [{2026-08-01, 650}, {0000-01-01, 600}]`.
- **Verified on device:** July shows **16 days → ₹9,600** (₹600/day) and August **9 days → ₹5,850**
  (₹650/day). Both months priced at their own rate.
- **Fixed:** the worker form overflowed by 8.6px behind the keyboard, painting overflow stripes across
  the save button. The sheet body is now scrollable.
- **Tests: 55 → 63**, including the Jagdish case directly (July must be ₹3,000, not ₹3,250),
  mid-month splits, and statements spanning a rate change.

Incidental but worth recording: while checking data I found an advance I had not created, and the
**audit trail resolved it in one query** — the entry carried a different uid and a timestamp 17 minutes
before my edits, so it came from the owner's own device. That is precisely what §5's audit log is for.

`flutter analyze` clean, 63 tests pass.

### 2026-08-12 (c) — Carry-forward spans all history; per-worker date-range statement

Prompted by a question from the owner: *"is the balance carried over from all past months from the
date the worker first joined?"* It was not.

- **Carry-forward was one month deep, and only for settled months.** `opening` read the previous
  month's settlement `closing`; settlements exist only when someone taps RECORD PAYMENT, so any
  unsettled month contributed **nothing**. Replaced with `openingBalances()` in `utils/payroll.dart`,
  which walks **every** prior month — settled months use their recorded figures, unsettled months are
  computed from attendance and advances. See §6 for the rules and the two documented caveats
  (back-dating into a *settled* month needs a reopen; unsettled months price at the current wage).
- **On live data this was not academic.** `devi lal` showed a **-₹800** August balance before the fix
  and **₹13,000** after, with a visible "Carried from last month ₹13,800" row. Three other workers had
  ₹1,200 each being dropped. The old code was silently discarding real money.
- **Payroll tab now issues 6 queries** (was 4), still constant regardless of headcount.
- **Fixed: the two screens disagreed about the same worker.** The worker profile still used the old
  single-month opening, so it showed ₹2,000 where the Payroll tab showed ₹3,200. The profile now loads
  the worker's full history once, slices it locally, and computes `opening` with the same
  `openingBalances()` walk. Three queries instead of four, and the statement below needs no second trip.
- **New: per-worker date-range statement.** `SHARE STATEMENT` on the worker profile → pick any two
  dates → PDF to the Android share sheet. Contains full/half/absent/**not-marked** day counts, the
  brought-forward balance, earnings with the day × rate arithmetic shown, every advance with its date,
  payments, and the pending amount. Backed by `buildWorkerStatement()` (pure) and
  `models/worker_statement.dart`. Date-range rather than month-bound because "the 12th to the 26th" is
  what actually gets asked, and because a worker added days after joining has a first period that
  starts mid-month.
- Statements slice the worker's whole history in memory rather than range-querying, which avoids a
  composite index and makes "brought forward" fall out of the same split.
- Fixed the SHARE STATEMENT button being clipped by the system navigation bar.
- **Tests: 42 → 55.** New coverage for multi-month accumulation, settled/unsettled mixing without
  double-counting, a settled month resisting a later wage rise, back-dated attendance, range boundary
  inclusivity, unmarked-vs-absent, and the statement PDF rendering with the ₹ glyph.

`flutter analyze` clean, 55 tests pass, verified on `emulator-5554`.

### 2026-08-12 (b) — Rules closed; app verified on a device; two regressions found and fixed

Anonymous sign-in was enabled on the project, so the transitional state below lasted one deploy.

- **Database closed.** `authorised()` → `return request.auth != null;`, deployed. Verified with
  unauthenticated REST calls: reads of `workers`, `attendance`, `audit_log` and a well-formed write all
  **403**; the same calls carrying an anonymous token **200**; a bogus `status` still **403**, so
  validation stacks on top of auth rather than replacing it. 24 rule checks across both rounds.
- **App run on `emulator-5554`** (Android 15) via `flutter run`. Launches on
  `com.ai.labour_attendance`, signs in, and reads live data through the closed rules — no
  `PERMISSION_DENIED`, no sign-in failure. Dashboard shows real figures (`MARKED TODAY 0/5` where the
  old build hardcoded `— / 5`); payroll shows `deepak` 2 days ₹1,200 and `devi lal` 7 days ₹4,200 with
  a **-₹800** balance in red. Settlement UI, `RECORD PAYMENT`, export button, ₹ glyph and Indian digit
  grouping all render correctly.
- **Legacy passcode migration completed against production.** `settings` is now empty in Firestore: the
  reversible `base64('labour_mgr_salt_' + pin)` document was read, the PIN recovered, re-derived with
  PBKDF2, stored in device secure storage, and the remote copy deleted. Confirmed idempotent — it did
  not re-run on the next launch.
- **Fixed: passcode migration timeout scope.** `initialize()` had timed the *whole* migration at 4s,
  including PBKDF2 (50k iterations) plus an isolate spawn; it overran on a cold emulator, the gate fell
  through, and the migration finished afterwards. Now `initialize(networkTimeout:)` bounds only the
  Firestore read. (Impact in this instance was nil — the migrated passcode was `enabled: false` — but
  the defect was real.)
- **Fixed: empty-payroll regression, introduced by the §1.5 cache.** The Reports tab showed zero worker
  cards and all-zero totals on first open despite five workers with data. The shell's `IndexedStack`
  builds every tab eagerly, so `SummaryScreen` loaded while `WorkerProvider` was still streaming,
  computed zero rows from an empty list, and the per-month cache **memoised that empty result**;
  nothing re-triggered a load. Only pull-to-refresh revealed the real payroll. Fixed by keying the
  cache on month **and worker-set signature**, refusing to cache a result computed from an empty list,
  and reloading when the signature changes. Re-verified on a fresh launch: payroll populates unaided.
  Recorded as a trap in §9 — it passed `flutter analyze` and all 42 unit tests, and was only visible by
  opening the app.

`flutter analyze` clean, 42 tests pass after both fixes.

### 2026-08-12 (a) — Firestore rules deployed (validation-only, transitional)

- **Discovered:** Firebase Authentication was never provisioned on `labour-mgmt-ai-mvp-2026`.
  `identitytoolkit` returns `CONFIGURATION_NOT_FOUND` for the Android *and* web keys on both
  `accounts:signUp` and `accounts:signInWithPassword` — so the anonymous sign-in added in the previous
  session cannot succeed, and deploying auth-requiring rules would have denied every request.
- **Decision (user's):** deploy the validation half now rather than wait. `firestore.rules` gained a
  single `authorised()` function returning `true`, with the restore line commented directly above it.
  One file, one line to flip — no second ruleset to drift.
- **Deployed** via `firebase deploy --only firestore:rules` and read back through the Firebase MCP to
  confirm the live ruleset matches the repo.
- **Verified functionally — 16/16 checks** using unauthenticated Firestore REST calls, which *are*
  evaluated against rules (the MCP/admin tools bypass them, so they prove nothing here):
  wrong attendance doc id ✗ · `month` ≠ `date[0:7]` ✗ · bogus status ✗ · well-formed attendance ✓ ·
  unknown collection ✗ · `settings` write ✗ · negative wage ✗ · empty name ✗ · zero advance ✗ ·
  correct settlement closing ✓ · **fabricated closing balance ✗** · bad payment mode ✗ ·
  settlement id ≠ `{workerId}_{month}` ✗ · `audit_log` delete ✗. Both probe documents deleted and
  absence re-confirmed.
- **Still open:** the two-minute console step in §8. Until then the database is readable by anyone with
  the project id.
- Firebase MCP credentials recovered on their own this session; the earlier 401s were stale tokens.
  `gcloud` is signed in as a *different* account (`teligjn2@gmail.com`) with no access to this project,
  so the Identity Platform admin API is not reachable from here — enabling Auth is console-only.

### 2026-08-11 (b) — Part 1 of `improvement.md` implemented
Everything in Part 1 shipped except §1.8 (see "Deliberately deferred" below). Verified:
`flutter analyze` clean, **42 unit tests pass**, `flutter build apk --debug` succeeds, merged manifest
confirmed. **Not committed.**

- **Auth + rules (1.1):** added `firebase_auth`; `AuthService` signs in anonymously at startup and
  supplies `createdBy`/`changedBy`. Rewrote `firestore.rules` from `allow read, write: if true` to
  auth-required + per-collection shape validation, composite-id enforcement, an append-only
  `audit_log`, and a write-denied legacy `settings`. Rules syntax validated by loading them in the
  Firestore emulator; **not yet deployed**.
- **Passcode (1.2):** rewrote `PasscodeService` — PBKDF2-HMAC-SHA256 (50k iterations, per-install salt,
  `compute()` isolate), stored in `flutter_secure_storage`, escalating lockout, optional biometrics
  with PIN fallback, and a one-time migration that recovers the PIN from the old reversible encoding
  and deletes the world-readable Firestore copy.
- **Startup + errors (1.3, 1.12):** `_AppGate` is now a bounded state machine with try/catch, timeouts,
  RETRY and CONTINUE OFFLINE — it can no longer hang on a spinner. Firebase init failure shows an
  explanation. Added `SyncStatus` (pending-write count + `isFromCache` offline signal, fed by the
  workers listener's metadata) and `SyncBanner`; every write is tracked and every failure surfaced.
- **Android (1.4):** `applicationId`/namespace → `com.ai.labour_attendance`; `minSdk` 30 → 24; label
  → "Labour Manager"; `INTERNET` and `USE_BIOMETRIC` declared in the main manifest; `MainActivity`
  moved and now extends `FlutterFragmentActivity`; AGP 8.11.1 → 8.12.1 (share_plus needs ≥8.12.1);
  version 0.1.0 → 0.2.0+2, read at runtime via `package_info_plus`.
- **N+1 fix (1.5):** `SummaryProvider` went from 2 sequential queries *per worker* (60 for 30 workers)
  to **4 queries total**, grouped in memory, cached per month.
- **Money + carry-forward (1.6, 1.7):** money is now `int` whole rupees end to end (`utils/money.dart`,
  Indian digit grouping); no data migration needed because `asRupees()` reads legacy doubles. Added the
  **`settlements` collection**, opening/closing balances, and a settle sheet (amount, cash/UPI/bank,
  note, live "carried to next month" preview). Balances no longer reset at the month boundary.
- **Audit + soft delete (1.9, 1.10):** audit logging moved *inside* `FirestoreService` so no caller can
  forget it; attendance, workers and settlements are now audited (previously advances only); the
  advance audit entry is linked to the real document id (was `''`); audit log is paged. `deleteWorker`
  became `archiveWorker` (soft, `isActive: false`) with an explicit `purgeWorker` for a real erase.
- **Fonts, dates, fake UI (1.11, 1.13, 1.14):** bundled Manrope + Inter (they had never rendered);
  extracted `utils/dates.dart`; dashboard TODAY card, alert rows and sync row are now live data; the
  hardcoded "Recent Alerts" and dead hamburger are gone; the attendance ✓ button is now DONE with an
  honest message.
- **Tests, emulator, CI (1.15):** extracted the payroll math into `utils/payroll.dart` as a pure
  function; added `test/` with 42 tests (money, dates, payroll incl. carry-forward regressions, export
  incl. a PDF font-embedding check); rewrote the integration tests to be independent and
  emulator-capable (`--dart-define=USE_FIREBASE_EMULATOR=true`); added `.github/workflows/ci.yml`.
- **Export, profile, cleanup (1.16, 1.17, 1.18):** `ExportService` builds CSV and PDF (Inter embedded so
  ₹ renders) and shares via the Android share sheet; built `WorkerProfileScreen` from the unimplemented
  design; deleted dead code (`getAttendance`, `getWorkerAuditLog`, `enablePasscode`, `changePasscode`,
  `_isSaving`); moved inline hex to `DS`; fixed the duplicated README; retired `project_summary.md` to
  a stub; added `android/.kotlin/` and emulator logs to `.gitignore`.

**Deliberately deferred:** §1.8 (append-only ledger model). It was phrased as "consider", and the
settlement model built for §1.7 addresses the same problem — adopting both would mean two competing
sources of truth for a balance. Removed from `improvement.md` with that reasoning recorded there.

**Needs a human:** enable Anonymous auth in the Firebase console, `firebase use --add`, then
`firebase deploy --only firestore:rules` and smoke-test. Firebase MCP could not do this — its
credentials returned 401 all session (`firebase login --reauth`).

### 2026-08-11 (a) — Context baseline established
- Read the full codebase (23 Dart files, ~5,050 lines) and all config.
- Created `CLAUDE.md` and `improvement.md`.
- `flutter analyze` clean. No code behaviour changed.

---

## 14. Keeping This File Current

**Rule: `CLAUDE.md` is updated at the end of every session, and after every change, fix, or improvement.**
An out-of-date context file is worse than none — it makes confident, wrong decisions cheap.
`project_summary.md` is the cautionary example this repo already produced.

### Required procedure — before you report a task complete

1. **Add a Session Log entry (§13)** at the top: date, what changed, what you verified, anything left
   broken or half-done. Include the commit hash once committed.
2. **Update the affected sections**, not just the log:
   - New/changed collection or field → **§5 Data Model**
   - New/changed calculation, status value, or period logic → **§6 Business Rules** *and a test*
   - New screen, provider, service or util → **§4 Architecture** tree
   - New dependency or version bump → **§2 Tech Stack**
   - New command or changed build step → **§3 Commands**
   - Fixed something listed in **§9 Known Gaps** → *delete the entry* (don't just mark it done)
   - Found a new trap → *add it to §9* while it is fresh
   - Anything touching rules, auth, passcode or secrets → **§8 Security Posture**
3. **Refresh the header** — `Last updated`, `Last commit`, `Branch`, working-tree state.
4. **Move completed items out of `improvement.md`** into the §13 log here, so the two files never
   disagree about what has been built.
5. **Re-read §9 and §1** — if a statement there is now false, fix it. Stale *"known issues"* waste more
   time than missing ones.

### Quality bar for entries
- State what is **true now**, not what was intended. Aspirations belong in `improvement.md`.
- Prefer concrete detail: file paths, field names, exact commands, real numbers.
- If something was left broken or deliberately skipped, **say so explicitly**. Silence reads as "done".
