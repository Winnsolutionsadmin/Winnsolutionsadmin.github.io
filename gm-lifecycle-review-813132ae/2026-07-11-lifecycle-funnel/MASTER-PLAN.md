# MASTER PLAN: GM Lifecycle Funnel + Ad Variant Matrix (2026-07-11)

Synthesis of ground/ (8) + design/ (12) + verify/ (3). Where files conflicted, the verifier
findings and the two adopted resolution docs (`design/lifecycle-engine.md`, `design/measurement-v2.md`)
win. Nothing here executes. Every parent-facing send, clickwrap, budget, or prod deploy is a Tier-2
Jarred gate. No em dashes. No licensing text. Time math America/Los_Angeles. Marketing kinds stay
suppression-gated.

---

## 1. Executive summary (read this, then the single inquiry in section 12)

Growing Mindfully runs paid search into a static site + an onsite waitlist worker (D1). Empty seats
cost $6,400-9,400 per WEEK (Infant emptiest, Toddler full til Aug, Preschool 6-9 open). Paid volume is
thin: 43-58 clicks per WEEK account-wide. The directive builds a full lifecycle funnel on the existing
tour-waiver machinery: (a) a T1-T4 automated email/popup journey keyed off fee-settled + tour state,
(b) an ad-variant matrix (V1-V7) run as a SEQUENCED pipeline (never a 5-way parallel launch the volume
cannot read), (c) a per-family x per-campaign engagement grid in the Kindred admin, and (d) full
"update all databases" tour-booking instrumentation. Almost all of the transport, template, tracking,
and measurement substrate ALREADY EXISTS and is reused. The genuinely net-new build is: 6 additive D1
side tables (migrations 052+), one cron leg on the existing `*/10` tick, one shared tracked-send
helper, the `enrollmentFeeDue` $45 choke point, a Kindred no-show mark, the campaign-grid endpoint +
view, and the V1-V7 LP stamps. The whole engine ships DARK (`LIFECYCLE_ENABLED=0`) and is HOOTL by
construction: it acts on its own deadlines, writes verifiable evidence at act time (the grid IS the
audit surface), self-heals failures to `#biz-gm-ads`, and reaches Jarred only through the weekly
scorecard and the ONE numbered inquiry below. Two hard gates dominate everything downstream: the $45
enrollment-fee waiver is NOT automated yet (blocks V3/T3/T4), and every fee-deferring variant needs a
counsel-reviewed clickwrap bump. Recommended path: ship V4 (pure tour, zero backend gate) FIRST to
cold-start the tour events, then V1-vs-V5 ($65 waiver A/B), then scale the winner, holding the $45
stack for a phase-2 flight after the choke point lands.

---

## 2. System architecture

### 2.1 Data / tracking layer (canonical: `design/data-tracking.md`)

Naming reconciliation up front (the directive's names vs shipped reality):

| Directive asked for | Canonical table | Status |
|---|---|---|
| `campaign_touches` | **`campaign_sends`** (mig 032) | EXISTS - one row per (family, campaign); first-timestamps + open/click counts |
| `email_sends` | **`emails`** (schema.sql) + `campaign_sends` | EXISTS - `emails` is the raw send log; `campaign_sends` is the trackable marketing send |
| `email_events` | **`campaign_events`** | NEW - append-only per-event log for the drill-down |

EXISTING and reused as-is (do NOT recreate): `emails`, `campaign_sends` (with the open pixel
`/c/:token/o.gif`, wrapped-link click redirect `/c/:token`, Postmark `gm_send_token` delivery
webhook, `campaignFunnel()` report), `funnel_events`, `tour_bookings` (+ `slot_end` stored per
booking), `tour_invites`, `email_suppressions`, `campaigns`, `reservation_reminders` (the idempotency
shape all lifecycle stamps copy). `applications` is at 99/100 D1 columns and CLOSED; every new
per-family field is a side table keyed by `application_id` (or `email` for lead-only).

NEW additive side tables (all `CREATE TABLE IF NOT EXISTS`, `applications` untouched):

| # | Table | Role |
|---|---|---|
| 1 | `tour_waivers` + `tour_waiver_email_history` | $65 waiver state (`pending_tour`/`waived`/`expired`/`forfeited`), per-variant `offer_code`, one waiver per email ever |
| 2 | `lifecycle_sends` (PK `(application_id, stage)`) | T1/T3/T4 idempotency ledger, the agent-owned-deadline evidence |
| 3 | `tour_outcomes` (PK `booking_id`) | tour attendance (`attended`/`no_show`/`cancelled`), the T4 gate + comparative "completed" signal, written by Ashley via Kindred |
| 4 | `campaign_events` (append-only) | each open/click/delivered/bounce with its own ts + `ip_hash` (SHA-256, never raw IP) + `bot_suspected` |
| 5 | `offer_variants` (PK `offer_code`) | the `?offer=` registry: label, lp_slug, waived cents, `expires_at` for honest rotation |
| 6 | `enroll_fee_waivers` (PK `application_id`) | the ONE $45-waiver state per family, first-writer-wins, the single authoritative deadline `enrollmentFeeDue` reads |

MIGRATION NUMBERING (verify F0a, BLOCKER, adopted): **050 and 051 are TAKEN on disk**
(`050_feedback.sql`, `051_table_day_waivers.sql`, both committed 2026-07-11). Next free is **052**.
Every migration reference in the raw design set was off by two. Canonical sequence (per
lifecycle-engine F0a): **052** tour_waivers, **053** tour_outcomes, **054** lifecycle_sends,
**055** campaign_events, **056** offer_variants, **057** enroll_fee_waivers. Verify no collision at
write time (repo has parallel-numbered files from concurrent branches).

Open/click instrumentation: the pixel and `/c/:token` handlers ALREADY stamp `campaign_sends`; the
only extension is that each ALSO appends a `campaign_events` row. Opens are Apple-MPP-inflated
(directional only); the wrapped CLICK is the trust metric; `SCANNER_UA_RE` + a <60s-post-send rule
set `bot_suspected`.

### 2.2 The three fee-settled cohorts (verify F0b, BLOCKER, adopted)

A SECOND live $65-waiver path shipped 2026-07-11 (`fee_grandfathered_at` via `051_table_day_waivers.sql`
+ `waiver.ts`): per-building "table day" event codes waive the $65 on-site, leaving `fee_paid=0 AND
fee_grandfathered_at` set. So "fee settled" is **`(fee_paid=1 OR fee_grandfathered_at IS NOT NULL)`,
NOT `fee_paid=1`**. Three distinct fee-settled families the lifecycle logic must keep separate:
1. **standard** - paid the $65 (`fee_paid=1`).
2. **table_day** - $65 waived on-site (`fee_grandfathered_at` set, `fee_paid=0`), a funded VIP/state push.
3. **open_enrollment** - $65 waived on tour completion (`tour_waivers.waiver_state='waived'`, `fee_paid=0`).

T1/T3 audience predicates use the OR; a `cohort` tag (`standard` / `table_day` / `open_enrollment`)
segments them in the grid + scorecard so the comparative read stays honest. The table-day path uses
event CODES on `fee_grandfathered`, not a `?offer=` LP param, so it is a fourth attribution surface the
grid cohort resolver must bucket (else it falls to `standard`).

### 2.3 Lifecycle engine T1-T4 (canonical: `design/lifecycle-engine.md`)

State is DERIVED each `*/10` sweep from existing timestamps + `lifecycle_sends` rows (never a column).
"A stage fired" = a row exists; the family cannot re-enter. Derived states: FEE_SETTLED -> T1_SENT ->
T3_SENT (nurture arm); or -> TOUR_BOOKED -> TOUR_DONE/TOUR_NOSHOW -> T4 (tour arm); RESERVED and
UNSUBSCRIBED are terminal. Booking a tour STOPS the T1->T3 nurture (both predicates require "no tour"),
so nurture and tour arms never both run.

Scheduler: PIGGYBACK the existing `*/10 * * * *` cron leg (account is at the 5-cron limit; verified by
the repo's own `wrangler.jsonc` comment). One gated leg `if (env.LIFECYCLE_ENABLED === '1')
runLifecycleSweeps(...)`, each sub-sweep (T1/T3/T4) in its own try/catch, isolated so one failure never
blocks another. The sweep is a pure per-tick re-derivation (no cursor): crash-safe, self-healing next
pass, double-send-safe via the `campaign_sends` UNIQUE(campaign_id, application_id) anti-join.

- **T1 "Reserve Your Space"** (fee settled, no tour, +24h): fires on the first tick where
  `now >= fee_settled_at + 24h`. Two registry entries: **T1-A** (standard + table_day, `fee_paid=1 OR
  fee_grandfathered_at`) and **T1-B** (open_enrollment cohort, `fee_paid=0 AND waiver_state='waived'`,
  24h from `waived_at`). Cohort C (`pending_tour`) is intentionally uncovered (has a booked tour; T4
  reaches them on completion). CTA = reserve deep-link (`gm_intent=reserve`). No fee claim, no $ figure.
- **T2 reserve-exit winback popup** (C-1 resolution): a PLAIN book-a-tour popup, NO $45, no `?offer=`
  waiver code. Not a cron send; the overlay records it. See 2.4.
- **T3 "Book a tour and waive your enrollment fee"** (+24h after T1, still no tour): anchored to
  `t1.sent_at`. CTA routes to `/tour/` and the click ATTACHES the $45 waiver by creating the single
  `enroll_fee_waivers` row (first-writer-wins). Offer code `enroll-waiver`, its OWN allowlist distinct
  from the $65 `WAIVER_OFFER_CODES`. HOLD until the $45 choke point + `reserve-agreement-v4.ts` land.
- **T4 "reserve by 5PM, we waive the $45"** (slot_end +1h, not no-show): booking-anchored, resolves
  back to an application (token link first, else `visitor_email`=`parent1_email`; no app = excluded).
  `slot_end` is stored, so +1h is a pure UTC-safe WHERE clause (PT offset normalizes). One T4 per
  FAMILY via `lifecycle_sends` (F3: no `tour_followups` table). HOLD (same $45 gate as T3). Uses a
  DIFFERENT hero picture (Jarred's explicit requirement).

Suppression (a send passes only if ALL clear, first failing gate drops with a reason): (1) already
reserved (`deposit_paid=1`, terminal), (2) already toured (suppresses T1+T3, not T4), (3) unsubscribed/
bounced/complained (`email_suppressions`, pre-filtered in SQL AND re-enforced in `sendEmail`), (4)
max-3-timed-emails-ever via the `lifecycle_sends` PK, (5) one-campaign-per-24h anti-fatigue, (6) quiet
hours 20:00-08:00 PT (computed at send time; a deferred family stays due).

Waiver windows (D6 AMENDED, Jarred 2026-07-11, verbatim "They can book their tour within 2 weeks. The
$65 waitlist fee for that campaign is waived day of. If they do a tour, they can waive the $45
enrollment fee if they secure their space same day."). This SUPERSEDES the engine lane's expiry
constants and its 5PM/next-business-day roll:
- **$65 waitlist waiver:** 14-day window to BOOK AND COMPLETE the tour; forfeit at 14 days (the old
  3-day tour sub-window is DEAD). Waived day-of-tour on attendance (activation on the attendance mark).
- **$45 enrollment waiver:** waived when the family RESERVES the SAME CALENDAR DAY as their tour. The
  "5PM today / next-business-day roll / completion+48h" designs in lifecycle-engine.md are all
  superseded by this single same-day rule. `enroll_fee_waivers.expires_at` = the same-day cutoff, so the
  email promise and the charged window are ONE value. ONE open reconciliation (in the inquiry): does
  "same day" mean by 5:00 PM PT or by 11:59 PM PT end of the tour's calendar day? Recommend end-of-day
  (honest for afternoon tours whose T4 fires ~4:30 PT, and matches D6's literal "same day").

$45 waiver precedence (the T3/T4/V3 collision, resolved): the $45 is a SINGLE fee inside the deposit PI
read via `enrollmentFeeDue(row, waiver)` (returns 0 or 45). "Two waivers" is never a double discount
(the fee is $0 once); the risk was CONTRADICTORY deadlines. Resolution: **one waiver STATE per family,
first-writer-wins** (`enroll_fee_waivers`, `INSERT ... ON CONFLICT DO NOTHING`), and under D6 they now
share ONE deadline (same-day) so the collision is largely dissolved. Writers by journey order: T3 at
tour-BOOK, V3 at reserve entry, T4 at send IF no row. Whoever attaches FIRST owns the same-day deadline;
a later trigger RESTATES it, never overwrites or shortens. T4 READS when a waiver exists, WRITES only
when none does. Every parent-facing "$45" promise stays truthful and single-valued.

### 2.4 The three emails + the T2 winback popup (reconciled single spec)

All three emails ship as new `CAMPAIGNS` registry entries sent through a shared tracked-send helper
(NOT a bare `sendEmail`), so each writes a `campaign_sends` row and inherits the open pixel + wrapped
click + `campaignFunnel` for free (the grid's hard dependency). All reuse `emailShell` chrome + the
community-photo "picture style", team voice ("With love, The Growing Mindfully team", never Jarred),
no em dashes, marketing kind (auto suppression-gated + CAN-SPAM footer). Per D5, no dollar figures on
LPs; the emails may name the $45/$65 with the condition in the same sentence (the dollar rule is scoped
to LP copy, not the emails, and D5's LP-omit does not force dollars out of the emails; kept calm here).

- **T1 "Reserve Your Space"** (`design/email-reserve.md`): two registry entries, Variant A (standard +
  table_day fee-settled) and Variant B (open_enrollment cohort). Hero `community.jpg` (A) / `joy.jpg`
  (B). CTA = wrapped `/c/:token` -> `/portal/<token>?gm_intent=reserve` (auto-opens Secure Your Space).
  Hard ordering gate: T1 must NOT enable before `RESERVE_ENABLED='1'` (prod is DARK today) or clickers
  hit `403 reserve_disabled`.
- **T3 "Book a tour and waive your enrollment fee"** (`design/email-tour-nudge.md` section 1): hero
  `play.jpg`, CTA routes to `/tour/?offer=enroll-waiver` via a tracked redirect (needs the `/t/:token`
  offer-passthrough extension, verify F5). Names the $45 with its condition. HOLD until the general
  `enrollmentFeeDue` choke point lands (the tour-waiver-cohort $45 path is built; the general lifecycle
  audience path is not; see build phases).
- **T4 "reserve by [same-day], we waive the $45"** (`design/email-post-tour.md`): the DIFFERENT picture
  (`seated.jpg` or `walk.jpg`, distinct from T1-B's `joy.jpg` per C-10). Honest-urgency discipline: a
  real dated same-day deadline + full downside disclosure ("after that the fee applies, tour still
  counts, place unchanged, no penalty"), no countdown GIF, no seat-scarcity, one send per family. The
  5PM framing is reconciled to D6 same-day (see 2.3 open question). 2-arg builder with render-time
  deadline (verify F1); routed through the shared tracked-send helper (verify F2), not a bespoke
  `runTourFollowups`.
- **T2 reserve-exit winback popup** (`design/winback-popup.md`, the reconciled single spec; C-1
  resolution): a PLAIN book-a-tour popup, NO $45, no `?offer=` waiver code. The `email-tour-nudge.md`
  T2 section (which conflated T2 with T3's $45 offer) is dropped. Net-new: fires on reserve MODES (not
  the pay/child steps the existing fee-exit popup covers) via `onUserDismiss` + desktop mouseout +
  mobile back-intent + scroll-to-top heuristics, all funneling through one eligibility gate, once per
  session/family. Primary button routes to `/tour/?t=<token>` (family-stitched via a new
  `POST /api/portal/:token/tour-invite` reusing `ensureTourToken`; GA-only fallback if absent). Fires
  `gmwl_reserve_exit_winback_*` events (NOT the old `gmwl_fee_exit_winback_*`; the grid must query the
  new family, verify C-2/F6). REQUIRED FIX before ship: scrub "Book a free tour" -> "Book a tour" (the
  house "no free tour" rule, verify MED-2).

### 2.5 Kindred campaign grid + comparative OPEN ENROLLMENT view (`design/campaign-grid.md`)

New READ-ONLY admin page `/campaign-grid`: rows = waitlist families, columns = lifecycle campaigns
(T1/T2/T3/T4 + manual), cells colored by state (`not_targeted` / `received` / `engaged` / `converted`
/ `suppressed` / `failed`, precedence failed > suppressed > converted > engaged > received). Click a
cell -> drill panel (sent/delivered/opened xN/clicked xN/converted timeline + rendered-email preview).
Below the grid, a comparative card pits the OPEN ENROLLMENT cohort head-to-head vs standard (families /
received / engaged / tour booked / tour completed / reserved / conv rate), directional-labeled at n<20.

- ONE new worker endpoint `GET /api/crm/campaign-grid` (+ `/preview/:token`), SELECT-only, mirrors
  `ads-funnel.ts`, copies the file-local `crmAuthed` helper (verify F10: not exported, plain `===`),
  reached via the `/crm-api` direct-tokened lane (zero solace-api change). Four SELECTs joined in JS;
  optional tables (`tour_waivers`, `tour_outcomes`, `offer_variants`) wrapped in try/catch so the grid
  renders before those migrations land (cohort falls back to `standard`, completed shows "pending
  instrumentation", never a misleading zero).
- Conversion signal fixes adopted: reserve detection = `applications.deposit_paid_at` (real column),
  NOT the phantom `gmwl_reserve_confirmed` (verify C-5; use `gmwl_reserve_deposit_paid` as the event
  name where an event is read). Tour completed = `tour_outcomes.outcome='attended'` (verify C-7, the
  canonical single representation). T2 column synthesized from `gmwl_reserve_exit_winback_*` funnel rows
  (verify C-2), which requires the overlay to write a durable server row, not only client gtag (F6).
- Portal build follows the enforced view/helpers split (`CampaignGridView.tsx` + `campaignGridHelpers.ts`
  + Vitest), new route + Sidebar nav item, reuses `Card`/`Pill`/`SortTh`/`useGet` verbatim. Grid is
  Tier 0/1 (read-only); prod deploy of the portal is the only Tier-2 gate.

---

## 3. Ad variant matrix + the wave pipeline (`design/ad-variants.md`)

Each variant is a distinct creative concept = its own RSA + message-matched LP + `?offer=` param, NOT
five headlines in one ad. The load-bearing recommendation, forced by the 43-58 clicks/week volume
reality: **this is a PIPELINE, not a parallel launch. Max 2 concepts live at once (prefer 1 during a
probe), 2-3 week waves, everything else on the bench.** Splitting a thin slice five ways learns nothing
about any variant; at realistic ~8-12 clicks/week per new tour campaign, each wave is a 3-6 week
DIRECTIONAL probe with wide Wilson CIs, and the full 5-7-concept sweep is a Q3-Q4 program. Report every
wave winner with its CI; do not promise clean July A/B verdicts the volume forbids.

The seven concepts:

| # | Hook | Offer mechanic | Backend gate | Policy risk |
|---|---|---|---|---|
| V1 | OPEN ENROLLMENT! | $65 waitlist waived on tour (brand-framed) | tour-waiver stack (BUILT, gated) | med |
| V5 | $65 waitlist fee waived | same mechanic as V1, dollar-framed | same as V1 | med |
| V3 | $100+ / up to $110 in fees waived | $65 waitlist (tour) + $45 enrollment (same-day) STACKED | V1 gates PLUS general $45 choke point + urgency rotation | high (HOLD) |
| V4 | No-obligation tour | none (pure tour) | NONE (ready-now) | low |
| V2 | Back to School | seasonal wrapper, tour-only first cut | none if tour-only | low-med |
| V6 | Infant openings (proposed) | audience cut of the wave-1 winner | inherits winner | med |
| V7 | State employees (proposed) | audience cut of the wave-1 winner | inherits winner | med |

Structural facts: V1 and V5 are the SAME $65 mechanic, different HOOK (brand vs dollar) = the cleanest
same-audience A/B in the matrix. V6/V7 are audience cuts of a proven winner (Infant = emptiest/highest
rate $2,074/mo FT; State = the segment that produced the account's first fee-paid), not new wave-1 gambles.

THE WAVE PIPELINE:
- **WAVE 0 - PROBE, launches FIRST at the 7/16 batch: V4 "No-obligation tour", SOLO.** The only concept
  with zero backend gate. Three jobs nothing else can do: (1) validate tour-ad demand at acceptable CPC
  before any waiver plumbing, (2) COLD-START the tour events (`gmwl_tour_booked` / `gmwl_tour_completed`
  have NEVER fired, so GA4 has not observed them, so they cannot be key events or imported; V4 fires
  them first - this unblocks tour events for EVERYTHING downstream), (3) give Ashley live no-show/
  completion-marking reps before waiver economics ride on the mark. Owns the whole tour ad group; reaches
  a read fastest.
- **WAVE 1 - HERO (after the tour-waiver stack merges): V1 vs V5, CONCURRENT.** One ad group, two RSAs,
  different final URLs, ad rotation "Do not optimize: rotate evenly" (verify it did not silently revert),
  distinct `?offer=` codes. Resolves (a) does the $65 waiver convert at all vs standard, (b) brand vs
  dollar framing. Note D4: launches on the existing `waitlist-v1.ts` clickwrap (owner accepted the
  conditional-fee tension; no v2 counsel pass).
- **WAVE 2 - SCALE-OR-SEASON (conditional on the wave-1 winner):** take the winning hook and do ONE of
  V2 Back to School (real August cohort window), V6 Infant / V7 State audience cuts, or V3 "$100+" ONLY
  if the general $45 choke point + honest urgency rotation are solved. Max 2 live at once.

One-line sequence: `V4 solo (probe + cold-start) -> V1 vs V5 (hero A/B) -> winner scaled via V2 season /
V6-V7 audience; V3 last, only if $45 general path + rotation ship.`

**V3 stays on HOLD from the first batch.** D6 now approves the same-day $45 mechanic, which narrows the
blocker, but V3 still needs (a) the general `enrollmentFeeDue` choke point across all 7 deposit sites
(the tour-waiver-cohort path is built; the general path is not) and (b) an honest time-boxed urgency
rotation. Interim: descope V3 to $65-only (collapses into V5) or cut.

Keyword + negative wall: tour-mechanic variants (V1/V5/V3/V4) share ONE 22-keyword tour-intent pool
(B-lane); V1 vs V5 share one ad group with two RSAs; V4 solo owns the group; V2 gets its own seasonal
set; V6/V7 narrow to infant / state terms. The bidirectional negative wall ("GM Tour-Cannibalization
Guard") protects the four never-drop campaigns from the test and vice-versa.

---

## 4. LP factory + variant registry + isolation mandate (`design/lp-factory.md`)

Every variant LP is the SAME file with a handful of slots swapped. The FIXED spine (head gtag +
track.js + fonts + noindex + self-canonical, `:root` brand tokens, reset, header lockup, reviews band,
footer, instrumentation) is stamped identically; the VARIANT layer is a short manifest (slug, title/
meta, hero kicker+H1+sub+condition-line, CTA architecture, `?offer=` code, hero photo, chips). Built V1
mockup: `design/lp-open-enrollment-mockup.html`.

THE ONE CANONICAL REGISTRY (verify C-3/F4, BLOCKER, resolved - `lp-factory.md` is canonical over
`ad-variants.md`; `ad-variants.md` harmonizes to this). Slug, `?offer=`, and `WAIVER_OFFER_CODES` must
be byte-identical across the LP file, the server allowlist, the grid resolver, and the Ads Final URL or
the waiver silently no-ops:

| V | Slug `/lp/<slug>/` | `?offer=` code | CTA | Class | In `WAIVER_OFFER_CODES`? |
|---|---|---|---|---|---|
| V1 | `open-enrollment` | `open-enrollment` | tour-calendar | WAIVER-BEARING ($65) | yes |
| V5 | `fee-waived-65` | `fee-waived-65` | tour-calendar | WAIVER-BEARING ($65, same as V1) | yes |
| V3 | `fees-waived` | `fees-waived` | tour-calendar | WAIVER-BEARING (stacked, gated) | yes ($65) + $45 path |
| V4 | `free-tour` OR `book-a-tour` | `free-tour` OR `tour` | tour-calendar | TRACKING-ONLY | no |
| V2 | `back-to-school` | `back-to-school` | overlay-flow | TRACKING-ONLY | no |
| V6 | `infant-tour` | `infant-tour-waiver` | tour-calendar | WAIVER-BEARING (wave 2) | on deploy |
| V7 | `state-tour` | `state-tour-waiver` | tour-calendar | WAIVER-BEARING (wave 2) | on deploy |

- `WAIVER_OFFER_CODES = {open-enrollment, fees-waived, fee-waived-65}` at launch (+ infant/state on V6/V7).
  Everything else is charged the standard fee. `back-to-school` / V4 are tracking-only and MUST NOT be
  in the allowlist. The $45 `enroll-waiver` code is a SEPARATE allowlist (reserve-step mechanic), never
  mixed with the $65 codes (verify C-11).
- **V4 slug is the one open naming call** (verify F4): the direct instruction gave `free-tour`, but
  `book-a-tour`/`tour` keeps "free" out of the Final URL a Google reviewer sees and matches the LP copy
  that scrubs "free tour". Recommendation: `book-a-tour`/`tour`. In the inquiry.
- The phase-1 LP branch built `/lp/tour-offer/` (V1's ancestor); the grid's stale `OFFER_VARIANTS` map
  keyed on `/lp/tour-offer/` must be rebuilt from this registry (verify C-4).

D5 (settled): **NO dollar figures anywhere on the LPs** (owner overruled the policy lane's price-
disclosure recommendation). The LP `.condition-line` states the condition in DOLLAR-FREE language
("book a tour and complete it, and we waive the waitlist fee that normally holds your place"). Ad copy
MAY carry figures for the sanctioned variants (V5 "$65", V3 "$100+"). Update the LP factory heroes +
condition-lines to remove every `$65`/`$45`/`$100+` string; the ad RSA decks keep theirs.

Licensing (settled): the CDSS badge is STRIPPED from the new test-LP footers (the phase-1 LP branch
already caught + fixed this - hero chip + footer "Licensed by California CDSS" removed as net-new
licensing on ad infra). New LPs carry copyright + "Family-founded 2018" + "Nut-free facility" only.
This is a build rule, not a decision (the "add nothing licensing, ever" rule is absolute).

Isolation mandate (per variant): `noindex, follow` + self-canonical, absent from `sitemap.xml` /
`robots.txt`, ZERO internal marketing links, ad-click-only entry, waiver flag only via `?offer=`.
Header logo rendered as a non-linked `<span>` on test LPs (D-LP-1); footer "More" = `/privacy/` +
`/terms/` only (D-LP-2, a blessed legal-links exception to "zero internal links", documented so the
per-slug grep does not flag it as a regression). Per-deploy verification: for EACH slug,
`grep -rn "lp/<slug>" growingmindfully/` returns only the LP's own dir; and grep every LP for `fee`
confirming each hit is conditioned and dollar-free.

Urgency rotation (V3 + any time-boxed claim): must carry a REAL `[[EXPIRY]]` date driven by
`offer_variants.expires_at` and actually rotate; never a hardcoded evergreen "this week only". The V3
hero must bind its "this week" kicker/H1 to the flight gate, not a static string (verify MED-4).

---

## 5. GA4 / gtag wiring summary (`design/data-tracking.md` section 4)

Two mechanisms reach GA4: client gtag `G-QK5VPGREL8` (present on EVERY ad LP, verified; the overlay's
"homepage + rates only" comment is stale) and server Measurement Protocol from the worker
(`sendGa4Event`, default-off + sandbox-gated, enhanced conversions via SHA-256 email/phone). GTM
container was purged 2026-06-24; dataLayer pushes are no-ops.

New events to register (all `gmwl_` prefix, segment by `offer` param, do NOT fragment into per-variant
conversion actions):

| Event | Fires | Key event? | Ads import |
|---|---|---|---|
| `gmwl_lp_view` | LP load, `offer=<code>` + `lp=<slug>` | no | no (the per-variant DENOMINATOR, currently missing - dependency #1) |
| `gmwl_tour_booked` | booking (EXISTS, server MP) | STAR after V4's first real fire | SECONDARY ~$25 |
| `gmwl_tour_booked_from_offer` | booking from an offer LP | no | no |
| `gmwl_tour_completed` | T4 sweep, not no-show, param `offer`+`waiver` | STAR after first fire | SECONDARY (Purchase-class on volume) |

`gmwl_lp_view` is a small inline script on the already-gtag-tagged LPs: read `offer` from
`location.search`, stash `gmwl_offer_ctx` in sessionStorage (the key overlay.js + the tour IIFE read),
fire the event. The `offer` value is validated server-side against `offer_variants` before use as any
attribution label (unknown -> `standard`). Tour-booking fan-out adds an optional `offer` field to
`/api/tours/book` (gap-7) + `gmwl_tour_booked_from_offer`. Any new event is starred as a GA4 key event
BEFORE Ads import. Cold-start reality: booked/completed cannot be starred until they fire once -> V4's
wave-0 job. Do NOT emit opens to GA4 (MPP-polluted); email engagement stays D1-only.

Attribution carries redundantly: `?offer=` (authoritative cohort/waiver key), `utm_content` (mirror),
`utm_campaign`, `gclid`, and the distinct `landing_path` per slug. Cohort resolution order:
`tour_waivers.offer_code` -> `landing_path` -> `utm_content`/`utm_campaign` -> `standard`; PLUS the
table-day `fee_grandfathered` cohort (code-based, not `?offer=`, so a fourth attribution surface the
resolver buckets explicitly).

---

## 6. Measurement framework v2 (`design/measurement-v2.md`)

Cohort = `?offer=` code (canonical registry, section 4). Read PER-WAVE against the ad-variant pipeline,
not a five-way parallel launch. Comparative funnel = variant x [LP view (S0, denominator) -> tour
booked (S1) -> tour completed (S2, PRIMARY success) -> application (S3) -> reserved (S4,
`deposit_paid_at`) -> enrolled (S5, qualitative)]. Waiver cohorts run S0->S1->S3(`pending_tour`)->S2
(flips to `waiting` + activates waiver)->S4; V4 is S0->S1->S2; standard is S3->S4. Every rate carries an
n-flag: n<20 = "directional" (Wilson CI straddles hypotheses).

Decision rules per wave (2-week boundary OR 100 LP sessions, whichever first; one extension to 3-6 weeks
if under ~100 sessions):
- **Wave 0 (V4):** SCALE if >=8 tours booked, completed-rate >=50%, CPC within ~1.5x Core tour-term CPC.
  ITERATE (build T-24h/T-2h reminders) if >=8 booked but completion <50%. KILL if <3 booked.
- **Wave 1 (V1 vs V5):** SCALE the mechanic if >=8 tours completed across both arms AND (>=1 waiver-LP
  reserve OR >=3 standard fee-paids off the same traffic). PICK a framing only if one arm leads beyond
  its CI half-width (else keep the branded `open-enrollment`, brand equity compounds).
- **Wave 2:** inherits Wave-1 thresholds per audience cohort, cannibalization guardrail elevated.

Email KPIs (T1-T4): anchor on the verified CLICK (opens are MPP noise), 7-day-click conversion window;
delivery-rate floor 95%; unsubscribe rate is a fatigue GUARDRAIL. The Kindred grid is the closed-loop
evidence surface; the weekly scorecard (`scorecards/2026-Wxx.md`) is the SINGLE batched update.

OPEN ENROLLMENT vs standard (directive #4): reported at two levels - framing read
(`open-enrollment` vs `fee-waived-65`, same keywords) and mechanic read (union of both $65-waiver codes
vs `standard`). Cannibalization guardrail (checked WEEKLY): if non-waiver fee-paid starts from Core/
Infant/Preschool fall to zero for 2+ weeks AND spend share did not itself drop -> PAUSE the live waiver
concept. Qualitative at ~0.5 non-waiver paid/week baseline; catches a large obvious reroute, not a
subtle one.

Build dependencies (ranked): (1) `gmwl_lp_view` denominator - without it no per-variant rate has a base;
(2) `gmwl_tour_completed` + `tour_outcomes` attendance - the primary metric; (3) tour events cold-start
(V4); (4) lifecycle emails on the `campaign_sends` ledger; (5) T2 durable `gmwl_reserve_exit_winback_*`
row; (6) Local-actions demotion before any import.

---

## 7. Compliance requirements (`design/policy-compliance.md`, updated for D4/D5/D6/D7)

Per-variant verdicts (Google Dishonest Pricing / Unreliable Claims / Unavailable Offers / Editorial all
still bind even though the internal "no $65 in ad copy" rule was lifted):

| Variant/component | Verdict | Note |
|---|---|---|
| V1 OPEN ENROLLMENT | CLEAR WITH FIXES | editorial (sentence case, no "!"); "Open Enrollment" implies availability -> frame as "join the waitlist, fee waived when you tour", add truthful availability line; condition-in-asset |
| V2 Back to School | CLEAR WITH FIXES | run in-season; any deadline real; no school-calendar guarantee |
| V3 $100+/up to $110 | HOLD (from first batch) | general $45 choke point + honest urgency rotation still needed; descope to $65-only interim; prefer "up to $110" phrasing |
| V4 no-obligation tour | CLEAR WITH FIXES | reword "free tour" -> "no obligation"; drop "!" ; the safest variant, launches first |
| V5 $65 waitlist waived | CLEAR WITH FIXES | condition-in-asset ("$65 waitlist fee waived when you complete a tour"); drop "!" |
| T1 Reserve Your Space | CLEAR | marketing kind, truthful subject, no fee claim |
| T2 reserve-exit popup | CLEAR | on-site UI (CAN-SPAM does not reach it); scrub "free tour" |
| T3 waive enrollment fee | build-staged | general $45 choke point still to build; copy authored, not cleared to fire |
| T4 post-tour same-day | build-staged | same $45 gate; honest same-day deadline server-enforced |

Standing rules that survive: every "$ waived" ad asset carries its condition in the SAME string (the
two near-bare assets are dropped); "free tour" is banned house-wide (tours were never priced);
editorial scrub (no all-caps except acronyms, no gimmicky "!"); "this week only" must genuinely expire/
rotate; CAN-SPAM (unsubscribe + physical address + suppression) is already wired and satisfied for
T1/T3/T4 by keeping them marketing kinds. CA Bus. & Prof. Code 17529.5 satisfied by truthful headers +
first-party sends.

CLICKWRAP (D4, settled): **NO `waitlist-v2.ts` / `reserve-agreement-v4.ts` counsel pass.** The waiver
variants launch on the existing `waitlist-v1.ts` / `reserve-agreement-v3.ts`. The owner accepted the
conditional-fee / "non-refundable regardless" tension; it is flagged once here and closed. RESIDUAL-RISK
NOTE (one line, not a blocker): a family who completes a tour and is waived signs clickwrap text that
still describes a non-refundable fee they were not charged; owner-accepted, monitor for confusion.

The prior HOLD-until-clickwrap gates are REMOVED. The remaining real build gate for T3/T4/V3 is the
general `enrollmentFeeDue` $45 choke point across all 7 deposit sites (incl. the hardcoded
`docusign.ts:117`) so a waived family's charge, quote, refund math, abandon email, and agreement all
read $0 consistently. Do not SEND a "$45 waived" promo to the general lifecycle audience while site 2
still bills the full $45. D7 (settled): the `/state-employees/` "no application fee" fix already SHIPPED
site-wide (5 pages); drop it from the dependency list.

---

## 8. HOOTL governance (every component: autonomy class / evidence trail / escalation / kill switch)

Per the CONTEXT-PACK2 mandate. Autonomous by default (the system owns every deadline; Ashley's no-show
mark is an OPERATING INPUT, not an approval); closed-loop evidence (every act writes verifiable rows at
act time, the grid drill-down IS the spot-check); single update (weekly scorecard) + single inquiry
(section 11); hard gates only where they belong (Tier-2 human items); kill switches, not permission slips.

| Component | Autonomy class | Evidence at act time | Escalation target | Kill switch |
|---|---|---|---|---|
| `runLifecycleSweeps` dispatch leg | AUTONOMOUS, agent-owned deadlines | each sub-sweep's rows | `#biz-gm-ads` on repeated exception | `LIFECYCLE_ENABLED=0` |
| T1 sweep (A + B + table_day) | AUTONOMOUS, fires at fee_settled+24h | `lifecycle_sends` T1 + `campaign_sends` + `campaign_events` | `#biz-gm-ads` on send-fail streak | `LIFECYCLE_ENABLED=0` |
| T2 reserve-exit popup | AUTONOMOUS (client, once/session) | `gmwl_reserve_exit_winback_*` + durable server row | none | overlay `?v=` rollback |
| T3 sweep | AUTONOMOUS, fires at T1+24h | `lifecycle_sends` T3 + `campaign_sends` + `enroll_fee_waivers` | `#biz-gm-ads` | `LIFECYCLE_ENABLED=0` (+ $45 gate) |
| T4 sweep | AUTONOMOUS, fires at slot_end+1h | `lifecycle_sends` T4 + GA4 `gmwl_tour_completed` + waiver row | `#biz-gm-ads` | `LIFECYCLE_ENABLED=0` / per-stage config |
| No-show mark | OPERATING INPUT (Ashley) | `tour_outcomes` row (marked_by/at) | none | unmarked = attended default |
| `enroll_fee_waivers` write | AUTONOMOUS (first-writer-wins) | the row + `expires_at` | none | choke point returns full fee if row absent |
| tour-booking fan-out | AUTONOMOUS | booking row + GA4 + funnel_events + email + calendar | `#biz-gm-ads` on write fail | `TOURS_KILL=1` / `TOURS_ENABLED=0` |
| campaign-grid endpoint | AUTONOMOUS (read-only) | the scorecard/grid render | none | n/a (read-only) |
| LP serve + `?offer=` capture | AUTONOMOUS (static) | `gmwl_offer_ctx` + `gmwl_lp_view` + `landing_path` | none | pause/remove the Ads campaign |
| waiver-flag application branch | AUTONOMOUS, allowlist-gated | `tour_waivers` row + `waiver:true` payload | `#biz-gm-ads` on mismatch/abuse | `WAIVER_OFFER_CODES` emptied / per-code |
| `offer_variants` rotation/expiry | AUTONOMOUS (expiry is data) | change-log per date flip | `#biz-gm-ads` on stale-date | `active=0` per variant |
| weekly scorecard generation | AUTONOMOUS (the single update) | the committed scorecard file | n/a (it IS the update) | n/a |
| decision-rule eval at wave boundary | AUTONOMOUS to compute + recommend | scorecard Block D | recommendation -> `#biz-gm-ads`; ACTION -> the inquiry | pausing the TEST campaign is agent-owned |
| cannibalization guardrail | AUTONOMOUS weekly | scorecard Block C | `#biz-gm-ads` (agent-owned pause of the test concept) | pause the waiver concept via status |
| anomaly triage | AUTONOMOUS self-heal | `error_log` + scorecard note | `#biz-gm-ads`, NEVER Jarred's inbox | the owning instrument's flag |
| conversion-action config (promote/import) | GATED (Tier 2) | change-log + GAQL verify | the numbered inquiry | remove import |

---

## 9. Build phases (dependency order; S <=0.5d, M ~1-2d, L ~3-5d)

PHASE 1 IS ALREADY BUILT (2026-07-11, both branches pushed, NOT merged/deployed, gated for 7/16):
- BACKEND (gm-waitlist branch `tour-waiver-backend-0711`, tip f6c87cca): `tour_waivers` side table +
  `src/server/tour-waiver.ts` (intake eligibility, $65 waive-on-attendance, $45 same-day-reserve waiver
  LA-tz gated, day-10 reminder + day-14 forfeit crons per D6), `POST /api/crm/families/:key/tour-attended`
  (bearer). Waived = `fee_paid=0` (no fake Stripe). Position at ACTIVATION (D3). Excluded from
  archive/winback/campaign double-ask. `TOUR_WAIVER_ENABLED=1` sandbox / `0` prod dark. 492 tests pass.
  NOTE: this branch numbered the table `051_tour_waivers` but `051_table_day_waivers` is already on main
  -> RENUMBER to 052 at merge (verify F0a collision).
- LP (growingmindfully branch `worktree-agent-a9f5c147ecad4ff85`, tip f62182ed): `/lp/tour-offer/`
  noindex+isolated, no dollar figures (D5), D6 copy, design QA passed, CDSS licensing violation
  caught+fixed. Two backend judgment calls flagged: (1) marking attended on an already-forfeited row
  un-forfeits it (human wins); (2) verify-email suppresses the "$65 paid" receipt for the waived cohort.
- REMAINING before 7/16 launch: Ads Scripts campaign build (login ready), `gmwl_tour_booked` wiring on
  `/tour/`, then gated merge+deploy of both branches together with the mandatory design-QA gate + preview
  links to Jarred (D8).

PHASE 1b - what can build NOW in sandbox (against a COPY of `solace-mirror.db`), all Tier 0/1, no parent
send:
- migrations 052-057 (the 6 side tables) - S (copy `reservation_reminders` shape). Renumber the phase-1
  tour_waivers into this sequence.
- `campaign_events` append on the existing pixel + `/c/:token` handlers - S.
- `offer_variants` seed + the `offer` validation helper + tour-book `offer` param (gap-7) - M.
- `sendTrackedCampaignEmail` shared helper factored out of `runCampaignWave` (verify F2) - M.
- `runLifecycleSweeps` + sweepT1/T3/T4 + the `*/10` cron leg + caps + quiet hours - M.
- `gmwl_lp_view` client add on the LPs (the measurement denominator) - S.
- campaign-grid endpoint (`campaign-grid.ts`) + Kindred view/helpers/tests - M.
- Kindred no-show toggle UI (the `tour-attended` endpoint exists; the React toggle is the piece) - S.

PHASE 2 - unblocked by V4 wave-0 (V4's first real tour fires the cold-start events for EVERYTHING):
- star + import `gmwl_tour_booked` / `gmwl_tour_completed` as GA4 key events (Tier 2) - S.
- T1 (A + B) registry entries + enable behind `LIFECYCLE_ENABLED` once `RESERVE_ENABLED='1'` - S/M.
- T2 reserve-exit popup (overlay branch + `POST /api/portal/:token/tour-invite`) - M.

PHASE 3 - the general $45 path (gates T3/T4/V3 for the non-tour-waiver audience):
- `enrollmentFeeDue(row, waiver)` choke point through all 7 deposit sites + `docusign.ts:117` - L (Tier 2).
- T3 + T4 registry entries + `enroll_fee_waivers` writes + the `/t/:token` offer passthrough (F5) - M.
- V3 LP + honest urgency rotation - M.
- V6/V7 audience-cut LPs (wave 2, after a winner) - S each.

Critical path to a dark-shippable engine (no parent send): migrations 052+ + shared helper +
`runLifecycleSweeps` + guards + grid. Everything parent-facing rides the Tier-2 QA gate + preview links.

---

## 10. Settled constraints (D1-D9, rendered by Jarred 2026-07-11, commit 646cb7c - NOT re-open)

Fold these in as fixed; do NOT re-ask:
- **D1 GO** on the waiver stack. **D2 GO** budget +$6-8/day ($115 -> $121 enabled). **D3** waitlist
  position at ACTIVATION (`application_effective_at`). **D9** Test B ($45 standalone) parked as Phase 2.
- **D4** NO clickwrap v2/v4 counsel pass; launch on existing v1/v3; owner accepted the conditional-fee
  tension (residual-risk note only). All HOLD-until-clickwrap blockers removed.
- **D5** NO dollar figures anywhere on the LPs; ad copy MAY carry figures for sanctioned variants; LP
  condition language is dollar-free.
- **D6 AMENDED:** 14-day window to BOOK AND COMPLETE the tour (3-day sub-window DEAD; forfeit at 14
  days); $65 waived day-of-tour on attendance; $45 enrollment fee waived when the family reserves the
  SAME CALENDAR DAY as their tour. Supersedes the engine lane's 5PM/next-business-day/completion+48h
  windows. (The 5PM-vs-end-of-calendar-day cutoff is the one residual reconciliation, in the inquiry.)
- **D7** DONE (fee copy shipped, 5 pages). **D8** GO for 7/16 with a mandatory DESIGN QA gate (hero
  image, text, symmetry) + preview links to Jarred pre-launch.
- Same session: winback ARMED in prod (existing families excluded); the tour-waiver Phase 1 is BUILT on
  branches (section 9). Licensing on new LPs: STRIP CDSS (already applied on the LP branch).

---

## 11. THE SINGLE INQUIRY (numbered, one line each, recommendation folded in - genuinely NEW only)

1. **Wave sequencing:** approve V4 solo (wave 0) -> V1 vs V5 (wave 1) -> scale the winner (wave 2), max
   2 live at once, 3-6 week directional probes. Rec: approve.
2. **V3 "$100+" hold:** keep V3 out of the first batch; ship only at wave 2 IF the general $45 choke
   point + honest urgency rotation land, else descope to $65-only (== V5) or cut. Rec: hold V3.
3. **Email cadence/count:** T1 -> T3 nurture (2 emails) + the T4 tour arm; hard cap 3 timed lifecycle
   emails/family ever and ~2 marketing emails/family/week across lifecycle + winback + campaigns. Rec: approve.
4. **5PM-vs-same-day reconciliation (D6):** the same-day $45 waiver cutoff = 5:00 PM PT vs 11:59 PM PT
   end of the tour's calendar day. Rec: end of calendar day (honest for afternoon tours; kills the
   next-business-day roll).
5. **T1 window:** 24h nurture delay (fire at fee_settled+24h) vs "promptly within 24h" (delay=1).
   Rec: 24h delay.
6. **T4 no-show default:** unmarked tour = SEND T4 (Ashley's mark is an operating input) vs hold until
   attended is marked. Rec: unmarked = send.
7. **Budget for the ADDITIONAL variants** beyond the approved +$6-8/day ($121): wave-2 audience cuts
   (V6/V7) + a seasonal flight (V2) need their own line; max-2-live caps concurrent spend. Rec: hold at
   $121 through wave 1, add a wave-2 line only when a winner is proven.
8. **Grid scope:** render cohort as a row-attribute + comparative card (recommended) vs cohort-as-grid-
   columns (the literal directive reading). Rec: row-attribute + comparative card.
9. **Local-actions conversion pollution:** demote the 3 GBP Local-actions PRIMARY conversions
   (Directions/Other/Website visits) to SECONDARY before importing any tour/lifecycle conversion.
   Rec: demote now.
10. **Conversion-action discipline:** keep every new tour/lifecycle conversion action SECONDARY at
    launch; protect `gmwl_fee_paid_confirmed` PRIMARY $65 as the uncontaminated headline. Rec: approve.
11. **V4 canonical slug/offer:** `free-tour`/`free-tour` (the instruction) vs `book-a-tour`/`tour`
    (keeps "free" out of the Final URL, policy-safer). Rec: `book-a-tour`/`tour`.
12. **Parent-facing sign-off + the D8 design-QA gate:** batched approval (at the QA gate, with preview
    links) of all V1-V7 ad creative + LP copy, T1/T3/T4 email bodies, and the T2 popup copy. Rec: batched approval.

---

## 12. Open risks (10 lines max)

1. Volume: 43-58 clicks/week means most wave reads are DIRECTIONAL (wide CIs), not significant; do not over-read a 3-click gap.
2. No-show is the single biggest execution risk; T-24h/T-2h reminders + `.ics` invites do not exist yet (build before scaling any waiver).
3. Migration collision: the phase-1 `051_tour_waivers` branch must renumber to 052 at merge (051_table_day_waivers is on main).
4. The table-day `fee_grandfathered` cohort silently gets no lifecycle email unless T1/T3 predicates use the OR (verify F0b).
5. T3/T4 for the GENERAL audience are blocked on the L-effort `enrollmentFeeDue` choke point; only the tour-waiver-cohort $45 path is built.
6. D4 residual: waived families sign clickwrap text describing a fee they were not charged (owner-accepted; monitor for confusion/chargebacks).
7. Cannibalization: a waiver "win" could be rerouted standard revenue, not net-new; the guardrail is qualitative at this volume.
8. Cold-start dependency chain: if V4 produces no tours, the tour events never fire, GA4 never observes them, and the whole waiver read stalls.
9. `RESERVE_ENABLED` is prod-DARK; T1 must not enable before it or clickers hit `403`.
10. Grid columns stay empty unless every lifecycle email routes through the shared tracked-send helper (not bare `sendEmail`).




## COUNSEL PANEL VERDICT (5 models, 2 adversarial rounds, 2026-07-11 - full ballots in COUNSEL-VERDICT.txt)
ENDORSED (adopt): P1 wave sequencing (+86..+95); P3 V3 hold (+75..+96); P5 deadline = end of
calendar day 11:59pm PT not 5pm (+60..+91, kills the afternoon-tour dark pattern); P7 grid
row-attribute (+35..+60); P9 cohort predicate fix (unanimous +82..+100: the literal fee_paid=1
trigger SKIPS the fee-waived Open Enrollment + grandfathered cohorts - a test-defeating bug,
fix in build); P2 V4-first amended per grok/codex to a SHORT canary (run to first bookings,
1-2 weeks, not a long solo wave); P10 HOOTL (+35..+48) with an incident-escalation exception
for parent-facing send failures (#biz-gm-ads immediately, not the weekly batch).
PANEL REVERSED the draft recommendations on three:
- P8: send T1 PROMPTLY after fee settlement (peak intent), quiet hours only - not +24h.
- P4: keep the weekly cap, DROP the lifetime-3-email cap (too tight for months-long childcare
  decision cycles); add inventory-reopen re-touch legs later.
- P12: NEVER send T4 on an unmarked tour (unanimous negative, -10..-70: unmarked is not
  attended). Default = suppress + auto-ping Ashley at tour-end+1h; T4 fires on her mark.
PANEL'S TOP FLAGGED RISK: P11 clickwrap-as-is (-44..-80 across all five): a waived family
signs terms describing a non-refundable fee they never paid. Panel notes the fix is one
conditional sentence, not a counsel pass. Owner ruling D4 stands unless Jarred adopts the
one-line middle path (surfaced in the inquiry).
PANEL ADDITIONS adopted as build items: offline-tour instrumentation (phone/walk-in/Ashley
bookings into funnel events - measurement must not be hostage to the never-fired online path);
pre-registered INCONCLUSIVE outcome in the decision rules (no SCALE/KILL on noise);
attack the volume ceiling itself (QS/bids/GBP local) in parallel - no lifecycle optimization
fixes a 50-click/week trickle; capacity-weighted routing (bias waves to Infant, the emptiest
room at $6.4-9.4k/week burn).
