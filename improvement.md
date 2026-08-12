# improvement.md — Roadmap

**Last updated:** 2026-08-11 · **Companion to:** [`CLAUDE.md`](CLAUDE.md)

- **[Part 1](#part-1--engineering)** — engineering. The original backlog **shipped on 2026-08-11**
  (full breakdown in `CLAUDE.md` §13). What remains is listed below.
- **[Part 2](#part-2--features-for-an-electricians-day-in-udaipur-rajasthan)** — researched feature
  roadmap for the working life of an electrical contractor in Udaipur, Rajasthan. **Unstarted.**

> When an item here ships, delete it from this file and record it in `CLAUDE.md` §13. The two documents
> must never disagree about what exists.

Tags: **Impact** (how much it matters) · **Effort** (S = hours, M = a day or two, L = a week+).

---

# Part 1 — Engineering

## 1.0 · Shipped (2026-08-11)

Auth + hardened Firestore rules · real passcode security (PBKDF2, secure storage, lockout,
biometrics) · bounded offline startup + write-error surfacing + sync banner · Android release config ·
the N+1 summary fix (60 queries → 4) · money as `int` rupees · settlements and carry-forward balances ·
full audit coverage + soft delete · bundled fonts · date/money/payroll utils · live dashboard ·
42 unit tests + emulator-capable integration tests + CI · CSV/PDF export · the worker profile screen ·
dead-code and documentation cleanup.

See `CLAUDE.md` §13 for the itemised list and what was verified.

## 1.1 · ✅ Database closed — 2026-08-12

Anonymous sign-in was enabled on the project, `authorised()` now requires `request.auth != null`, and
the rules are deployed and verified end to end (24 checks across two rounds — see `CLAUDE.md` §13).
Unauthenticated reads and writes are refused; the app's anonymous credential works; shape validation
still holds on top.

## 1.2 · Dropped: the append-only ledger model · was §1.8

The original entry proposed replacing the parallel `attendance` / `advances` / payments collections
with a single append-only `ledger`. It was phrased as "consider", and the **settlement model built for
carry-forward solves the same problem** — "what does this worker's account look like" is now one
document per worker per month, with an explicit closing balance.

Adopting both would create two competing sources of truth for a balance, which is worse than either
alone. Revisit only if Part 2 adds enough money *types* (piece-rate, bonus, adjustments, client
receipts) that the settlement shape starts to strain.

## 1.3 · Remaining engineering items

Small, and none of them block feature work.

| # | Item | Impact | Effort |
|---|---|---|---|
| a | **Firebase App Check** (Play Integrity). Anonymous auth stops anonymous *internet* traffic, not someone holding the APK. This is the next real control. | high | M |
| b | **Phone auth + uid allow-list**, replacing anonymous auth. The proper destination — also required for the owner/munshi role split (Part 2 D3). | high | L |
| c | `purgeWorker` deletes sequentially rather than in a `WriteBatch`; an interrupted purge leaves a partial delete. | low | S |
| d | The trade→colour mapping is duplicated in `worker_list_screen.dart` and `worker_profile_screen.dart` — pull into `DS` or a shared helper. | low | S |
| e | `advance_screen.dart` is the last screen calling `FirestoreService` directly instead of through a provider. | low | M |
| f | Settling a month is only reachable from the Payroll tab, not from the worker profile. | low | S |
| g | **Restore**, not just export. CSV/PDF share exists; a scheduled backup and restore-to-a-new-device do not. Folded into Part 2 D2. | high | M |
| h | Revisit the `flutter_secure_storage` pin (`^10.0.0`) when Flutter's default `compileSdk` reaches 37. | low | S |

---

# Part 2 — Features for an Electrician's Day in Udaipur, Rajasthan

## 2.1 The operating context (researched)

Everything below is calibrated to this picture. Sources are listed in [§2.8](#28-sources).

**The user.** A small electrical contractor / *thekedar* running a crew of 5–30: licensed wiremen, semi-skilled
helpers, and unskilled *beldars*. Work is a mix of residential wiring in Udaipur city, hotel and resort projects
(a large local sector), commercial fit-outs, and industrial work around the marble and mineral belt. Sites change
weekly; the crew splits across two or three at once.

**The workforce is migrant and seasonal.** Udaipur sits at the head of southern Rajasthan's tribal belt — the
Bhil, Garasiya and Meena districts where circular seasonal migration is the norm, driven by marginal land and
low-value agriculture. Aajeevika Bureau — a Udaipur-based organisation working with these workers since 2005 —
has supported over 12 lakh workers and helped recover roughly ₹120 crore in wages. On its migrant helpline,
**over 98% of complaints are about wage theft**, and an earlier study found more than half of workers who
returned home did so involuntarily, due to wage theft or ill health.

That single statistic should shape this product more than any other. **The most valuable thing this app can
produce is not a report for the owner — it is a credible, shareable record for the worker.** A contractor whose
crew trusts his numbers gets the same crew back next season, in a market where re-recruiting every year is the
actual cost.

**Language and literacy.** Hindi and Mewari, with variable literacy. English UI labels
("PAYROLL ADJUSTMENT", "AGGREGATE TOTALS", "COMMAND CENTER") are unreadable to most of the workforce and to
plenty of supervisors. Numbers, faces, colours and icons carry meaning; paragraphs do not.

**Connectivity.** Fine in Udaipur city. Unreliable on sites toward Jhadol, Kotra, Gogunda, Salumbar and
Rishabhdev, and inside basements, stairwells and concrete shells — exactly where an electrician works. The app
is now fully usable offline and honest about sync state, which was Part 1's work.

**Seasons and the working calendar.**
- **Summer (Apr–Jun), 40–45°C:** work shifts to early morning and evening with a long midday break. A day is
  still "a day" — but attendance timing changes and heat-illness risk is real.
- **Monsoon (Jul–Sep):** rain stops outdoor and rooftop work. Indoor wiring continues. Rain days need to be
  recorded as a *reason*, not silently marked absent — that distinction is exactly what causes disputes.
- **Festivals:** Holi and Diwali empty sites as workers return to their villages, and both carry an expectation
  of advance or bonus. **Gangaur** — an 18-day Mewar festival, at its most elaborate in Udaipur — and **Teej**
  in the monsoon are locally significant. Sowing and harvest also pull workers home.

**Money culture.** *Kharchi* (running cash advances) is universal and the app models it already. Settlement is
often **weekly** rather than monthly. Payment is a mix of cash and UPI — UPI now handles over 18 billion
transactions a month and around 82% of India's digital-payment volume, and daily-wage earners are firmly inside
that shift, but cash has not gone away.

**Statutory floor (verify before relying on it).** Rajasthan's own minimum wages are among India's lowest —
widely reported as **₹285/day unskilled, ₹297 semi-skilled, ₹309 skilled, ₹359 highly skilled**. Rajasthan
published **Draft Code on Wages Rules, 2026** on 13 January 2026, proposing **twice-yearly VDA revision (April
and October)**, with finalisation expected later in 2026 — so these numbers are likely to move. Note that
**central-sphere** minimum wages (applicable to Central Government works) are far higher — reported around
**₹827 / ₹693 / ₹556 per day for Area A / B / C** unskilled from 1 April 2026. Market rates for a skilled
electrician in Udaipur sit well above the state floor in any case. **Confirm current figures against the
Rajasthan Labour Department notification before wiring any number into the app.**

**Market pricing for the business side.** Electrician labour is commonly quoted **per point** — roughly
**₹500–₹1,200 per point** at pan-India base rates (AC points ₹800–₹2,000), or **₹200–₹500/hour**; metros add
25–30%, so Udaipur sits near base. Materials are quoted separately.

**Compliance surface.**
- **Electrical contractor licence** (Rajasthan Electrical Inspectorate, `eid.rajasthan.gov.in`) in classes, with
  **wireman and supervisor permits**. Licences renew annually, and wireman/supervisor permits require a
  **government-hospital health certificate submitted annually** to keep the permit valid. Missing a renewal
  stops work.
- **BOCW** — 1% cess on cost of construction; establishments with **10+ workers** must register, **per site**.
  Board benefits (health, maternity, accident, pension, children's education) require the **worker** to register
  individually; the cess does not enrol them.
- **e-Shram** — free registration for unorganised workers aged 16–59 who are not EPFO/ESIC members and not
  income-tax payers. Gives a 12-digit UAN and **₹2 lakh accidental-death cover** (₹1 lakh partial disability)
  under PMSBY.
- **GST** — works contracts are services taxed at **18%**; current 2026 guidance is that works-contract providers
  are **outside the composition scheme**. Registration threshold ₹20 lakh for services. *Confirm with a CA.*

---

## 2.2 Group A — Attendance and crew (the daily 5 minutes)

**A1 · Hindi-first UI with a language toggle** · Impact: very high · Effort: M
The highest-leverage feature in this document. Not a translation layer bolted on later — Hindi (Devanagari) as
the default, English as the option. हाज़िरी (attendance), खर्ची (advance), मज़दूरी (wage), पूरा दिन / आधा दिन /
छुट्टी (full day / half day / off), बकाया (balance). Indian number formatting is already in place
(`utils/money.dart`); Hindi month names belong in `utils/dates.dart`. Add `flutter_localizations` + ARB
files now, while there are only ~200 strings.

**A2 · Site / job-wise attendance** · Impact: very high · Effort: L
Today attendance is global: a worker was present, full stop. An electrician's crew splits across two or three
sites every single day, and job costing is impossible without knowing *where* the day was spent. Add a `sites`
collection and a `siteId` on each attendance record; let the operator pick a site, then mark that site's crew.
This is the structural change that unlocks C1–C4 (per-job profitability). Note that the attendance document id
is `{workerId}_{date}` and **the security rules now enforce that** — adding a site dimension means either a
three-part key or moving the site onto the record, and the rules must change in the same commit.

**A3 · Overtime (ओवरटाइम / घंटा)** · Impact: very high · Effort: M
OT is routine in this trade — night shifts before a hotel opening, deadline pushes. Add hours plus a rate rule
(flat ₹/hour or 1.5× the day rate ÷ 8), recorded per worker per day, flowing into salary via
`utils/payroll.dart` (and a test in the same commit, per `CLAUDE.md` §6).

**A4 · Reason codes for a non-working day** · Impact: high · Effort: S
"Absent" flattens four very different situations: **बारिश (rain)**, **माल नहीं आया (material didn't arrive)**,
**छुट्टी (personal leave)** and **गैरहाज़िर (no-show)**. Only the last is the worker's fault, and conflating
them is precisely the ambiguity that becomes a wage dispute. A rain day may even be paid at half rate by
agreement — the app should be able to represent that.

**A5 · Bulk "mark all present, then exceptions"** · Impact: high · Effort: S
The real-world flow is "everyone's here except Ramesh and Kalu." Today that's N taps. One button to mark the
whole site present, then long-press the two who aren't, turns a 30-tap chore into three taps — which is the
difference between the app being used daily and being abandoned by week three.

**A6 · Photo + face-first worker cards** · Impact: high · Effort: S
For a low-literacy operator (or a *munshi* marking attendance), a face is faster and less error-prone than a
name in a list — especially with three men named Ramesh. Add a `photoUrl`; use Firebase Storage with local
caching. *Store a photo, not biometrics — see [§2.7](#27-what-not-to-build).*

**A7 · Voice-assisted roll call (Hindi)** · Impact: medium · Effort: M
Speech-to-text roll call ("रमेश — पूरा दिन") for an operator with dirty hands on a ladder. `speech_to_text`
supports `hi-IN`. Genuinely useful, but build it after A5 — bulk-marking solves 80% of the same problem for 20%
of the effort.

**A8 · Supervisor check-in with GPS + timestamp** · Impact: medium · Effort: M
When the owner isn't on site, a trusted *munshi* marks attendance. Attaching site GPS and a server timestamp to
those marks (not to the owner's own) makes the record defensible without turning the app into surveillance.
Pair with the role split in D3.

**A9 · Festival and season calendar** · Impact: medium · Effort: S
Mark Holi, Diwali, Gangaur, Teej, Rakhi and local holidays in the attendance calendar so mass absences are
expected rather than mysterious, and so festival advances (B5) can be planned. Also useful for the monsoon
window (Jul–Sep) when rain days cluster.

---

## 2.3 Group B — Money and trust (the highest-value group)

**B1 · Digital haazri parchi — the WhatsApp wage slip** ⭐ · Impact: very high · Effort: S · *mostly shipped*

**Shipped 2026-08-12:** `SHARE STATEMENT` on the worker profile — pick any two dates, get a PDF with
full/half/absent/not-marked day counts, brought-forward balance, earnings with the day × rate
arithmetic shown, every advance with its date, payments and the pending amount, shared straight to
WhatsApp via the Android share sheet.

**What remains is the language.** The slip is in English. Devanagari needs a Noto Sans Devanagari face
embedded alongside Inter (the bundled Inter has no Devanagari coverage), and the labels need the words
the crew uses — हाज़िरी, खर्ची, बकाया. That is the half that makes it readable by the person it is for,
and it lands with A1.

The original entry read:

Why it matters here specifically: wage theft is the dominant grievance among exactly this migrant workforce
(§2.1). A contractor who hands every worker a clear, itemised record every week is doing something most don't,
and it converts the app from an internal ledger into a **retention tool**. It also removes the "you took ₹500
last Tuesday" — "no I didn't" argument permanently, because the record was shared *when it happened*, not
produced during a dispute. Nearly every worker or their family has WhatsApp; nobody needs to install anything.

The plumbing exists: `ExportService` already builds and shares PDFs, and `Settlement` already holds the
per-worker breakdown. The remaining work is **per-worker** (rather than whole-payroll) layout and **Devanagari
in the PDF** — the bundled Inter file does not cover Devanagari, so a Noto Sans Devanagari face has to be
embedded alongside it.

**B2 · Payment recording with mode and reference** · Impact: very high · Effort: S
Partly done: settlements record amount, date, mode (cash/UPI/bank) and a note, and support partial payment.
Still missing: a **UPI reference / UTR field** and an optional **photo of a signed receipt**.

**B3 · UPI payout deep links** · Impact: high · Effort: M
Store a UPI ID per worker; generate a `upi://pay?pa=…&am=…` intent so paying is one tap from the balance screen,
with the transaction auto-recorded on return. UPI is now ~82% of India's digital payment volume and daily-wage
earners are inside that shift — but keep cash as a first-class mode, because plenty of this crew still wants
notes on Saturday evening.

**B4 · Weekly and custom settlement cycles** · Impact: high · Effort: M
The app assumes calendar months (`month` keys are `YYYY-MM` throughout, including the settlement document id).
Many crews settle **weekly** — typically Saturday or Sunday — some fortnightly, some per-project. Making the
period configurable means generalising the settlement key, so do it deliberately and update `CLAUDE.md` §5/§6.

**B5 · Advance limits, warnings, and festival advances** · Impact: high · Effort: S
- Warn when a worker's advances exceed what they've earned to date — runaway *kharchi* is how contractors lose
  money to workers who then leave. The carry-forward work makes this computable: a negative `opening` is
  precisely the signal.
- Separate **festival advance / bonus** (Diwali, Holi) from routine kharchi, so it doesn't distort the
  earned-vs-drawn picture. This is a distinct cultural category, not a rounding detail.

**B6 · Cash denomination planner** · Impact: medium · Effort: S
Before Saturday's payout: "you need ₹47,300 — that's 92×500, 12×100, 3×50, 5×10." Small feature, used every
single week, and it saves a second trip to the ATM.

**B7 · Piece-rate / thekha mode** · Impact: medium · Effort: L
Not all electrical work is day-rated. Wiring is often sub-contracted **per point** or per board
(₹500–₹1,200/point at base rates). Support a per-worker or per-crew piece-rate agreement — quantity × rate,
progress tracked against an agreed total — alongside the existing day-rate model.

---

## 2.4 Group C — The electrician's business (beyond labour)

This is where the app stops being an attendance register and becomes the thing the contractor runs his business
on. Labour is roughly a third of his problem; materials and client payments are the rest.

**C1 · Site / job register** · Impact: very high · Effort: M
Client name, phone, address, job type (new wiring / repair / AMC), start date, expected end, status, agreed
value. The spine that A2, C2, C3 and C4 all hang from.

**C2 · Material tracking per site** · Impact: very high · Effort: L
Wire by gauge (1.0 / 1.5 / 2.5 / 4 sq mm), MCBs, DBs, switches, sockets, conduit, fan boxes — **issued vs used
vs returned**. Copper is expensive and portable; unaccounted material is a real and continuous leak in this
trade, and it is the single biggest gap between "attendance app" and "business app". Bonus: current stock in the
godown, and a low-stock nudge before the next site starts.

**C3 · Quotation / estimate generator** · Impact: very high · Effort: L
Build an estimate per point or per BOQ line (points × rate + materials + margin), share it as a PDF on WhatsApp,
and convert the accepted version into a job (C1) and then an invoice (C5). Contractors currently do this on
paper or in a notebook and lose bids to whoever replies first. A saved rate card per job type makes the second
estimate take two minutes.

**C4 · Receivables — what the client owes you** · Impact: very high · Effort: M
The app models only money going *out*. Track client payments received vs pending per site, with follow-up
reminders. Then show the one number a contractor actually needs each morning:
**"Clients owe me ₹X · I owe workers ₹Y · Net ₹Z."** The ₹Y half already exists — it is the Payroll tab's
STILL OWED total. That view alone justifies opening the app daily.

**C5 · GST-ready invoicing** · Impact: high · Effort: M
Works contracts are taxed at **18%**, and works-contract providers appear to be **outside the composition
scheme** under current 2026 guidance — so if the business is registered (₹20 lakh services threshold), invoices
need correct GSTIN, SAC and tax split. Make it optional: many small contractors are below threshold, and forcing
GST fields on them adds friction for no benefit. *Have a CA confirm the treatment before shipping tax logic.*

**C6 · Licence and compliance reminders** · Impact: high · Effort: S
Cheap to build, expensive to forget:
- **Electrical contractor licence** renewal date (Rajasthan Electrical Inspectorate).
- **Wireman / supervisor permits** — including the **annual government-hospital health certificate** each
  permit-holder must file to keep their permit valid.
- **BOCW** site registration where 10+ workers are engaged (registration is **per site**).
- **e-Shram enrolment status per worker** — free, gives ₹2 lakh accidental-death cover, and takes minutes at a
  CSC. Tracking who is and isn't enrolled, and nudging the gaps, is a genuinely protective feature for a
  workforce doing electrical work at height.

**C7 · Tool and equipment register** · Impact: medium · Effort: S
Who has the drill, the megger, the tester, the ladder, the extension board — checked out to which worker at
which site. Tools disappear at site handover; a two-field log stops most of it.

**C8 · Warranty and AMC service reminders** · Impact: medium · Effort: M
"Sunset Resort — DB inspection due, 6 months since installation." Turns finished jobs into repeat revenue, which
matters in a hospitality-heavy local market with seasonal maintenance cycles.

**C9 · Safety and incident log** · Impact: medium · Effort: S
PPE issued, safety briefings, and an incident record. Electrical work carries real risk; a dated log plus
e-Shram/PMSBY status (C6) is what actually helps a family after an accident.

---

## 2.5 Group D — Resilience and roles

**D1 · Offline-first, visibly** · ✅ **shipped 2026-08-11**
Explicit sync banner, pending-write count, a startup path that cannot hang offline, and rollback on failed
writes. See `CLAUDE.md` §13.

**D2 · Backup, export, restore** · Impact: very high · Effort: M · *partly shipped*
CSV and PDF export via the share sheet exist. Still missing: **scheduled backup** (Drive/WhatsApp on a cadence,
not on demand) and **restore onto a new device**. A lost phone must not mean a lost year.

**D3 · Two roles: owner and munshi** · Impact: high · Effort: M
A supervisor should be able to mark attendance for their site and nothing else — no wages, no advances, no
worker archiving. Requires real per-person auth (Part 1 §1.3b), and the Firestore rules are already structured
per collection, so the role check drops in cleanly. This is what makes A2 and A8 usable at more than one site.

**D4 · Sensible defaults for low-end devices** · Impact: medium · Effort: S · *partly shipped*
`minSdk` is now 24 (was 30) so budget devices can install it. Still worth doing: keep the APK small, avoid heavy
animation, cache images aggressively, and add a **high-contrast / large-type mode** for direct Udaipur sunlight
— more valuable here than a dark theme.

---

## 2.6 Suggested sequencing

Each phase should leave the app shippable.

| Phase | Theme | Contents |
|---|---|---|
| **0 — Foundation** | Stop the bleeding | ✅ **done** — see Part 1 §1.0. Remaining: deploy the rules (§1.1). |
| **1 — Trust** | Make the numbers defensible and readable | **A1 Hindi UI** · A4 reason codes · A5 bulk marking · **B1 WhatsApp wage slip** · B2 UPI reference + receipt photo · B5 advance warnings · D2 restore |
| **2 — The trade** | Turn it into an electrician's app | **A2 site-wise attendance** · A3 overtime · C1 site register · C4 receivables · B4 weekly cycles · B3 UPI · D3 roles |
| **3 — The business** | Materials and margin | C2 material tracking · C3 quotations · C5 GST invoicing · B7 piece-rate · C6 compliance reminders |
| **4 — Polish** | Retention and edge | A6 photos · A7 voice · A9 festival calendar · B6 denominations · C7 tools · C8 AMC · C9 safety · D4 high-contrast mode |

**If you only do three things:** Hindi UI (A1), the WhatsApp wage slip (B1), and site-wise attendance (A2).
Those three change what the app *is*. Everything else improves what it already does.

---

## 2.7 What NOT to build

Deliberate exclusions, so they don't get re-proposed later:

- **No biometric/face-recognition attendance.** Popular in enterprise workforce tools, wrong here: it fails on
  dusty hands and in bad light, needs constant connectivity, costs real money per scan, and reads as surveillance
  to a migrant workforce that already distrusts contractors. A photo on the worker card (A6) gives the actual
  benefit — recognition by the operator — with none of the cost. (The `local_auth` dependency is for unlocking
  *the app on the owner's own phone*, which is a different thing entirely.)
- **Don't store Aadhaar numbers or images.** Storing Aadhaar in an unaudited third-party app creates legal
  exposure under the Aadhaar Act and the DPDP Act, and offers this app nothing. Phone number + photo is
  sufficient identity. If e-Shram tracking (C6) is added, store the **UAN**, not the Aadhaar behind it.
- **No GPS tracking of workers through the day.** Site check-in at marking time (A8) is proportionate;
  continuous tracking is not, and it will kill adoption.
- **Don't build a worker-facing app.** A WhatsApp message (B1) reaches everyone today, needs no install, no
  storage, no login, and no support burden.
- **Don't chase full accounting/ERP.** Estimates, invoices, receivables and material tracking are the ceiling.
  Ledgers, TDS and balance sheets belong with the CA.
- **Don't add real-time listeners everywhere.** `WorkerProvider`'s stream is right (small, always needed, and it
  doubles as the offline signal); streaming attendance or advances would multiply Firestore read costs for no
  user-visible gain.

---

## 2.8 Sources

Wage figures, fee structures and compliance rules change. **Verify against the primary/official source before
encoding any number into the app.** Aggregator sites are convenient but are not the gazette.

**Wages and labour law**
- [Minimum Wages in Rajasthan 2026 — ClearTax](https://cleartax.in/s/minimum-wages-in-rajasthan)
- [Minimum Wages in Rajasthan 2026: Rates & Industry Breakdown — SalaryBox Academy](https://academy.salarybox.in/minimum-wages/rajasthan)
- [Minimum Wages in Rajasthan for 2026 — factoHR](https://factohr.com/minimum-wages-in-india/rajasthan/)
- [Code on Wages (Rajasthan) Rules, 2026 — draft (PDF)](https://www.lawrbit.com/wp-content/uploads/2026/01/code-on-wages-rajasthan-rules-2026.pdf)
- [Rajasthan Draft Code on Wages Rules 2026: Key Changes — India Law](https://www.indialaw.in/blog/labour/rajasthan-draft-code-on-wages-rules-2026-key-changes/)
- [Central Govt Minimum Wages — Construction Labour Rates](https://nsrcivil.in/minimum-wages-central-government/)

**Electrical licensing (Rajasthan)**
- [Rajasthan Electrical Inspectorate — contractor renewal form (PDF)](https://eid.rajasthan.gov.in/eid/EID/DownloadDocuments/Contractor%20Renewal%20Form.pdf)
- [Rajasthan Electrical Inspectorate — new contractor forms A & B (PDF)](https://eid.rajasthan.gov.in/eid/EID/DownloadDocuments/Contractor%20New%20Form%20%20A%20-B.pdf)
- [Electrical Contractors License Rajasthan — procedure overview](https://www.electrical4u.net/electrical-license/electrical-contractors-license-rajasthan-everything-you-need-to-know/)
- [Contractor licence, supervisor & wireman certificates — vidyutsuraksha.org](https://vidyutsuraksha.org/administrativeSupervisor_certificates.aspx)

**Worker welfare and registration**
- [BOCW Registration in Rajasthan for Construction Companies — GenZCFO](https://genzcfo.com/growthx/bocw-registration-in-rajasthan-for-construction-companies)
- [BOCW Cess Payment Process, step by step — Yojo](https://yojoapp.com/en/blog/bocw-cess-payment-process-step-by-step/)
- [BOCW Construction Worker Registration and Welfare Benefits](https://righttoinformation.wiki/bocw-construction-worker-registration-benefits)
- [e-Shram Card 2026 — registration, benefits, eligibility](https://righttoinformation.wiki/e-shram-card)
- [e-Shram Card: Benefits, Eligibility & ₹2 Lakh Insurance — Legal Service India](https://www.legalserviceindia.com/Legal-Articles/e-shram-card-benefits-eligibility-registration/)

**Migration and wage theft in southern Rajasthan**
- [Aajeevika Bureau (Udaipur) — official site](https://aajeevika.org/)
- [Super-exploitation of Adivasi Migrant Workers — Aajeevika Bureau (PDF)](https://aajeevika.org/wp-content/uploads/2023/10/Super-exploitation-of-adivasi-migrant-labourers.pdf)
- [12 Lakh Migrant Workers Win Dignity & ₹120 Crore Wages With Aajeevika Bureau — The Better India](https://thebetterindia.com/changemakers/aajeevika-bureau-migrant-workers-udaipur-labour-rights-wages-legal-aid-women-collectives-10585484)

**Digital payments**
- [Scaling up digital wages: lessons from India — ILO (PDF)](https://www.ilo.org/sites/default/files/2024-10/Scaling%20up%20digital%20wages%20in%20India_Final_0.pdf)
- [A decade of UPI and India's digital momentum](https://www.sentinelassam.com/more-news/life/a-decade-of-upi-and-indias-digital-momentum)
- [Does UPI Contribute to Financial Inclusion? Construction Workers in Andhra Pradesh](https://www.researchgate.net/publication/387052694_Does_Unified_Payment_Interface_UPI_Contribute_to_Financial_Inclusion_The_Case_of_Construction_Workers_in_Andhra_Pradesh)
- [A Day in the Life of a Daily Wage Worker in India — Digital Labour Chowk](https://digitallabourchowk.com/2026/05/13/life-of-a-daily-wage-worker/)

**Trade pricing and GST**
- [Electrician Charges Per Point in India 2026 — Dial4Trade](https://www.dial4trade.com/knowledgebase/electrician-charges-per-point-in-india-2026-%7C-wiring-and-labour-cost-guide.htm)
- [Electrician Rate List India 2026 — Solve24](https://solve24.in/answers/electrician-rate-list)
- [GST on Works Contract India 2026: 18% Rate, ITC Rules — Tax Garden](https://taxgarden.in/blog/gst-on-works-contract-construction-services-india-2026)
- [Works Contract under GST — ClearTax](https://cleartax.in/s/gst-impact-works-contract)
- [Composition Scheme For Contractors — Pice](https://piceapp.com/blogs/composition-scheme-for-contractors/)

**Local calendar**
- [Festivals of Rajasthan — Rajasthan Tourism](https://www.tourism.rajasthan.gov.in/fairs-and-festivals.html)
- [Festivals of Rajasthan calendar 2026–2027](https://www.rajasthandriver.com/travel-info/festivals-of-rajasthan)
