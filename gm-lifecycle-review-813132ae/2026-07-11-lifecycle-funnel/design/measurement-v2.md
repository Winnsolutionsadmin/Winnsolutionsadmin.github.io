# DESIGN: Measurement v2 - Multi-Variant Lifecycle Funnel (2026-07-11)

Lane: MEASUREMENT. Extends `2026-07-10-tour-waiver-test/E-measurement.md` (the single-test frame)
into the multi-variant, lifecycle-email, per-family-grid world of CONTEXT-PACK2. Owns: per-variant
cohort definitions, the comparative funnel table (variant x stage), per-wave decision rules, the
Kindred grid metric definitions, lifecycle-email KPIs (7-day-click attribution), the OPEN ENROLLMENT
vs standard comparison, and the cannibalization guardrail. Nothing here executes. Every number is a
plan input.

Hard rules honored: no em dashes, no licensing language, no unconditioned fee-waived claims.
Conversion-action changes, budget, and parent-facing copy stay Tier 2 Jarred gates.

**Reconciliation note (load-bearing):** this doc adopts the CANONICAL names from
`verify/consistency.md` (the audit that ran after the sibling design lanes), NOT the pre-audit drift.
Specifically: the canonical `?offer=` registry (C-3), the real reserve signal (C-5), the single
tour-completion representation (C-7), and the correct T2 event family (C-2). Where two ground docs
disagree on an event name, this doc names the authoritative D1 column as the detection signal and
flags the event name as a verify item, so no phantom event propagates into a bidding or grid decision.

---

## 0. The one thing v2 changes about measurement

E-measurement sized ONE test: one campaign, one LP, one waiver mechanic, primary metric =
tour-completed rate per LP session. v2 keeps that spine and adds three axes:

1. **Cohort axis** - five to seven acquisition variants (V1-V7), each a distinct `?offer=` code that
   is the SOURCE OF TRUTH for which cohort a family belongs to. The comparative read (directive #4)
   is per-cohort, not one blended funnel.
2. **Lifecycle axis** - T1-T4 automated emails add post-acquisition stages (reserve nurture, tour
   nudge, tour-completion promo) that need their own delivery / click / conversion KPIs.
3. **Surface axis** - the Kindred campaign grid becomes the always-on audit surface (the HOOTL
   closed-loop evidence trail); the weekly scorecard becomes the single batched update to Jarred.

The volume reality that governed E is UNCHANGED and governs v2 harder: **43-58 paid clicks/week
account-wide** (ga4-ads-state, gaql-0711.json). Splitting that across five live variants learns
nothing about any of them. v2's measurement design is therefore built around the ad-variant lane's
PIPELINE (max 2 concepts live at once, 2-3 week waves), not a parallel five-variant launch. Read
`design/ad-variants.md` section 2 first; the decision rules here are per-wave to match it.

---

## 1. Canonical cohort registry (offer param = source of truth)

Every family's cohort is resolved by the worker in this order (campaign-grid.md section 4, reconciled):

1. `tour_waivers.offer_code` if the family is on the $65-waiver path -> that code.
2. else the `offer_variants` registry (or hardcoded `OFFER_VARIANTS` constant) keyed on
   `applications.attribution_landing_path` + `utm_campaign` -> the variant code.
3. else `standard`.

The `?offer=` value written to `gmwl_offer_ctx` at LP load and persisted into
`applications.attribution_landing_path` / `attribution_json` IS the cohort key. No new attribution
plumbing per variant (migration 012 columns already carry it). This is the canonical registry all
lanes must share (C-3 fix; lp-factory owns the build + the server allowlist):

| Variant | Public hook | LP slug | `?offer=` code | Mechanic | Cohort key | In `WAIVER_OFFER_CODES`? |
|---|---|---|---|---|---|---|
| V1 | OPEN ENROLLMENT! | `/lp/open-enrollment/` | `open-enrollment` | $65 waitlist waived on tour | `open-enrollment` | yes ($65) |
| V5 | $65 waitlist fee waived | `/lp/fee-waived-65/` | `fee-waived-65` | $65 waitlist waived on tour (SAME as V1) | `fee-waived-65` | yes ($65) |
| V3 | $100+ in fees waived | `/lp/fees-waived/` | `fees-waived` | $65 waitlist (tour) + $45 enroll (same-day) STACKED | `fees-waived` | yes ($65) + $45 path |
| V4 | No-obligation tour | `/lp/free-tour/` | `free-tour` | none (pure tour) | `free-tour` | no (tracking only) |
| V2 | Back to School | `/lp/back-to-school/` | `back-to-school` | seasonal wrapper (tour-only first cut) | `back-to-school` | no (first cut) |
| V6 | Infant openings (proposed) | `/lp/infant-tour/` | `infant-tour-waiver` | inherits wave-1 winner | `infant-tour-waiver` | inherits |
| V7 | State employees (proposed) | `/lp/state-tour/` | `state-tour-waiver` | inherits wave-1 winner | `state-tour-waiver` | inherits |
| control | Standard flow | existing Core/Infant/RTO LPs | (none) | fee due at application | `standard` | n/a |

Two structural facts that shape every read:

- **V1 and V5 are the SAME $65 mechanic, different HOOK.** Cohort-level, they are one economic test
  (does waiving the $65 waitlist fee on tour completion beat standard). Variant-level, they are a
  clean brand-framing (`open-enrollment`) vs dollar-framing (`fee-waived-65`) A/B on identical
  keywords. Report BOTH: the mechanic read (union of `open-enrollment` + `fee-waived-65` vs
  `standard`) AND the framing read (`open-enrollment` vs `fee-waived-65` head to head).
- **The `enroll-waiver` $45 code is a SEPARATE mechanic** (reserve-step, not application-step) and
  its own allowlist, NOT in `WAIVER_OFFER_CODES` (C-11). T3 and V3 both touch the $45 fee; measure
  the $45-waiver activation separately from the $65-waiver activation so the two do not blend.

---

## 2. The comparative funnel table (variant x stage)

The directive (#4) wants each variant tracked independently and compared. The stage ladder, with the
authoritative D1 detection signal and the GA4/funnel event per stage:

| # | Stage | Denominator/numerator role | D1 authoritative signal | Event (reconciled) |
|---|---|---|---|---|
| S0 | **LP view** | DENOMINATOR (per offer) | `funnel_events` gmwl_lp_view row OR GA4 page_view by landing_path | **`gmwl_lp_view`** keyed on offer param - NEW, see 6 |
| S1 | **Tour booked** | numerator | `tour_bookings` row (subject match) / `tour_invites.tour_booked_at` | `gmwl_tour_booked` (exists, server MP) + `gmwl_tour_booked_from_offer` |
| S2 | **Tour completed** | numerator (PRIMARY success) | `tour_bookings.attendance='attended'` (C-7 system of record) | **`gmwl_tour_completed`** (NEW generic) + `gmwl_tour_completed_waiver` (waiver subtype) |
| S3 | **Application** | numerator | `applications` row carrying the offer code (waiver cohort = `status='pending_tour'` then `'waiting'`) | `gmwl_application_submitted` (exists) |
| S4 | **Reserve** | numerator | `applications.deposit_paid_at` set (real column, both ground docs agree) | name DISPUTED - see note | 
| S5 | **Enrolled** | true-north LAGGING | manual mark (Solace `enrollment_status` / Kindred), joined by application_id | none (manual, Ashley/Jarred-gated) |

**Stage-order caveat by mechanic (do not read the ladder as strictly linear for every cohort):**
- **Waiver cohorts (V1/V5/V3):** S0 -> S1 tour booked -> S3 application enters `pending_tour` (fee
  deferred, Stripe skipped) -> S2 tour completed flips `pending_tour` -> `waiting` and activates the
  waiver -> S4 reserve -> S5 enrolled. So for waiver cohorts, S2 (completed) is the load-bearing
  conversion and is the DENOMINATOR gate for the fee actually being waived.
- **V4 (pure tour):** S0 -> S1 -> S2. No application-in-pending-tour required; a booking can exist
  without an application. V4's job is S1/S2 volume plus cold-starting the tour events (6).
- **Standard control:** S3 application -> fee_paid=1 -> S4 reserve. No S1/S2 (no tour in the mechanic).
  Standard's S3->S4 is the baseline the waiver cohorts are compared against.

**S4 reserve event-name note (C-5, honest):** `ga4-ads-state.md` section 2 lists a server-MP
`gmwl_reserve_confirmed` (staged for a $1,839 Ads import, never fired). `tours-fees-code.md` section 4
+ `verify/consistency.md` C-5 name the D1 funnel row `gmwl_reserve_deposit_paid` (index.ts:3739) and
say `gmwl_reserve_confirmed` appears nowhere in code. These two ground docs conflict. **Resolution for
measurement: use `applications.deposit_paid_at` (a real column) as the authoritative "reserved"
detection signal for the funnel and the grid.** Treat the GA4 event NAME as a verify item: confirm the
exact string emitted at the reserve step in `index.ts` before wiring any Ads import or grid
event-name query. Do not report a "reserved" count off a phantom event.

### 2a. The comparative table as rendered (weekly, per live cohort)

| Cohort (offer) | LP views | Tour booked | Tour completed | Application | Reserved | Enrolled | Completed rate | Reserve rate |
|---|---|---|---|---|---|---|---|---|
| open-enrollment (V1) | Y | n | n | n | n | n (qual) | S2/S0 | S4/S0 |
| fee-waived-65 (V5) | Y | n | n | n | n | n (qual) | S2/S0 | S4/S0 |
| fees-waived (V3) | Y | n | n | n | n | n (qual) | S2/S0 | S4/S0 |
| free-tour (V4) | Y | n | n | (n/a) | (n/a) | n (qual) | S2/S0 | n/a |
| standard | (Core LP views) | (n/a) | (n/a) | n | n | n (qual) | n/a | S4/S3 |

Rates carry an n-flag: `n<20` -> label "directional" (Wilson CI straddles hypotheses; E-measurement
section 3). Enrolled is qualitative at every realistic n (0.4-2 enrollments/30 days off one LP,
E-measurement section 3) and is read against LTV, never used to gate a wave decision alone.

---

## 3. Per-wave decision rules (the 2-week wave boundary)

Decision cadence follows the ad-variant PIPELINE, not a five-way parallel launch. Each wave has a
pre-registered checkpoint at the **2-week wave boundary OR 100 LP sessions on the live concept,
whichever comes first**; a concept that has not reached ~100 sessions by 2 weeks gets ONE extension
to the 3-week (ad-variants) / 6-week (E outer bound) mark before a forced call. The 100-session floor
is where the Wilson CIs in E-measurement section 3 begin separating a 10% world from a 25% world.

### WAVE 0 - V4 "No-obligation tour", SOLO (launches first, 7/16 batch)

Purpose: validate tour-ad demand at an acceptable CPC, cold-start `gmwl_tour_booked` /
`gmwl_tour_completed` (they have NEVER fired, ga4-ads-state section 5), give Ashley live no-show
marking reps before waiver economics ride on the mark. V4 owns the whole tour ad group, so it reaches
a read fastest.

| Outcome | Threshold at the wave boundary | Action (autonomy) |
|---|---|---|
| **SCALE** | >=8 tours BOOKED and completed-rate (`attended`/booked) >=50% and CPC within ~1.5x Core tour-term CPC | Proceed to Wave 1 (build waiver stack); V4 stays live as the ready-now floor. Budget change = Jarred (single inquiry). |
| **ITERATE** | >=8 booked but completed-rate <50% (no-show problem) | Build T-24h / T-2h reminder cadence (does not exist today, E section 5) BEFORE Wave 1 ships any waiver. Re-read 2 weeks. Reminder build = agent-owned. |
| **KILL** | <3 tours booked by the boundary, or bookings but persistent zero completions after one reminder cycle | Pause V4; the tour-ad thesis is falsified cheaply. Keep the keyword/audience learnings. Document in scorecard. Pause of the test campaign = agent-owned kill switch (not Jarred). |

### WAVE 1 - V1 vs V5, CONCURRENT (after clickwrap v2 + migration + completion-mark land)

One ad group, two RSAs, different final URLs, ad rotation "Do not optimize: rotate evenly" (verify it
did not silently revert - the known footgun, ad-variants section 2). Distinct `?offer=` codes give
each variant its own S0-S4 funnel. Resolves two questions in one wave: (a) does the $65-waiver mechanic
convert at all vs standard, (b) does brand framing or dollar framing pull harder.

| Outcome | Threshold at the wave boundary (per the mechanic, union of both arms) | Action |
|---|---|---|
| **SCALE the mechanic** | >=8 tours COMPLETED across V1+V5 AND (>=1 reserve traced to a waiver LP OR >=3 standard fee-paids off the same LP traffic) | Proceed to Wave 2 scale (audience cuts / season). Budget = Jarred. |
| **PICK a framing** | mechanic clears SCALE and one arm leads the other by more than its Wilson CI half-width | Retire the losing hook; the winner becomes the OPEN ENROLLMENT umbrella for Wave 2. If the gap is inside the CI, report "directional, no winner" and keep the branded `open-enrollment` as default (brand equity compounds). |
| **ITERATE** | tours booked but completion <50% | Same reminder-cadence fix as Wave 0 ITERATE; re-read 2 weeks before scale/kill. |
| **KILL the mechanic** | <3 tours booked across both arms, or zero completions after a reminder cycle | Revert waiver LPs to standard; V4 (tour-only) may continue if Wave 0 scaled. Document so the idea is not silently re-proposed. |

### WAVE 2 - SCALE-OR-SEASON (conditional on the Wave-1 winner)

Take the winning hook and do ONE (max 2 concepts live at once):
- **V2 Back to School** seasonal flight into the real August cohort window (honest urgency by
  construction). Measure as a THEME layer over the winning offer; its own `back-to-school` cohort.
- **V6 Infant / V7 State** audience cuts of the winner. Measure per-cohort; the read question is
  "does the proven offer convert BETTER on the emptiest/highest-value seat (Infant, $2,074/mo FT) or
  the proven-converting segment (state employee)".
- **V3 "$100+"** runs here ONLY if the $45 automation/SOP is solved (enrollfee-noshow ground);
  otherwise it ships $65-only (collapses into V5) or is cut. Do not advertise an un-automated $45.

Wave-2 decision rules inherit the Wave-1 SCALE/ITERATE/KILL thresholds, applied per audience cohort,
with the cannibalization guardrail (5) elevated because audience cuts overlap the never-drop
campaigns' sheds most directly.

---

## 4. Lifecycle-email KPIs (T1-T4) with 7-day-click attribution

All four lifecycle emails send through the `campaigns.ts` engine as new `CAMPAIGNS` registry entries
(email-infra section 2; campaign-grid dep 1) so they write `campaign_sends` rows and inherit the open
pixel + wrapped-link click tracking. That is what makes them measurable at all. Per email:

| KPI | Definition | Source | Role |
|---|---|---|---|
| **Delivery rate** | `delivered_at` set / `sent` | campaign_sends + Postmark/Resend Delivery webhook | health floor; <95% -> anomaly |
| Open rate | `opened_at` set / delivered | open pixel `/c/:token/o.gif` | DIAGNOSTIC ONLY. Apple MPP inflates opens; NOT a trust metric |
| **Click rate (CTR)** | verified `clicked_at` / delivered | wrapped `/c/:token` + verified-click heuristic (>60s post-send, non-scanner UA) | **THE trust metric** - the honest engagement stage |
| **Conversion rate** | conversion event within the 7-day-click window / `sent` | funnel_events / D1 column proxy, gated on `clicked_at` | the outcome; see attribution model below |
| Click-to-conversion | conversions / verified clicks | same | efficiency of the click once earned |
| **Unsubscribe / suppression rate** | new `email_suppressions` rows attributable to the send / sent | email_suppressions | GUARDRAIL - a spike is a fatigue/relevance anomaly |

### 4a. Attribution model: 7-day click (task-specified)

An email touch is CREDITED a conversion when the family reaches that campaign's conversion event
within **7 days of a verified click** on that email. Formally, for a `(family, campaign)` send with
`clicked_at = tc`, the send is `converted` if the conversion event `occurred_at` in `[tc, tc + 7d]`.

- **Click-based, not open-based.** Opens are MPP-polluted; a conversion window anchored on opens
  would over-credit. Anchor on the verified click.
- **Fallback for no-click conversions** (family converts within 7 days of SEND but never registered a
  click): count it at LOWER confidence, labeled "view-through", reported separately, NOT folded into
  the headline click-conversion rate. This keeps the trust metric clean.
- **Campaign -> conversion event map** (the CAMPAIGN_CONVERSION constant, reconciled):
  - T1 "Reserve Your Space" -> reserved (S4, `deposit_paid_at`).
  - T2 reserve-exit popup -> tour booked (S1, `gmwl_tour_booked`). T2 fires
    **`gmwl_reserve_exit_winback_*`** (NOT the old `gmwl_fee_exit_winback_*` - C-2 fix); its cell is
    synthesized from those events, not from a campaign_sends row (it is a popup, not an email).
  - T3 "Book a tour and waive your enrollment fee" -> tour booked (S1).
  - T4 tour-completion promo -> reserved (S4).
- **Cohort-B precedence (C-6):** an OPEN ENROLLMENT family completing a tour makes T1-B (predicate
  `waiver_state='waived'`) and T4 (1h post tour-end) eligible at nearly the same instant, and the 72h
  anti-fatigue quiet window means whichever the `*/10` sweep emits first suppresses the other. The
  email lanes define T4 (time-boxed "by 5PM {date}", higher intent) as WINNING the completion window;
  T1-B suppresses for a family that has a completed tour. Measurement consequence: credit the
  completion-window reserve to T4, not T1-B, so the time-boxed offer's read is not stolen by the
  evergreen nurture. Report T1-B and T4 conversion rates on DISTINCT audiences accordingly.

### 4b. Per-stage lifecycle read (the journey KPIs)

| Stage | Numerator | Denominator | What it answers |
|---|---|---|---|
| T1 -> reserve | reserved within 7d-click of T1 | fee-resolved families with no tour | does the reserve nurture move fee-paid families off the fence |
| T2 popup -> tour | `gmwl_tour_booked` after `gmwl_reserve_exit_winback_shown` | reserve-exit popups shown | does the exit-intent save recover abandoning reservers |
| T3 -> tour | tour booked within 7d-click of T3 | still-no-tour families +24h post T1 | does the $45-waiver nudge produce bookings |
| T4 -> reserve | reserved by the stated deadline | completed-tour families (not no-show) | does the post-tour promo close the reserve within its window |

---

## 5. OPEN ENROLLMENT vs standard + the cannibalization guardrail (directive #4 + E guardrail)

### 5a. The independent comparison

"OPEN ENROLLMENT" (V1, `open-enrollment` code) is tracked as its own funnel and compared head to head
against `standard`. Because V1 and V5 share the $65 mechanic, report at two levels:

- **Framing read** (variant): `open-enrollment` vs `fee-waived-65`, same keywords, same mechanic. The
  cleanest same-audience A/B in the matrix.
- **Mechanic read** (cohort union): all $65-waiver families (`open-enrollment` + `fee-waived-65`) vs
  `standard`. This is the "does tour-first-with-waiver beat apply-then-pay" question, and it is the
  one with enough pooled n to move first.

The head-to-head surfaces in the Kindred grid comparative card (6) and the scorecard (7). Rate
significance is NOT asserted at 43-58 clicks/week; label "directional" until n is meaningful.

### 5b. Cannibalization guardrail (from E section 4, checked WEEKLY not just at wave boundaries)

The risk: the waiver LPs move families who would have paid the $65 the standard way onto the free
path, so a "win" is really rerouted revenue, not net-new conversions.

- **Metric:** non-waiver fee-paid application starts from Core / Infant / Preschool during the test
  window vs the trailing 4-week baseline.
- **Trigger:** if non-waiver fee-paid starts from those campaigns fall to zero for 2+ consecutive
  weeks AND spend/impression share to those campaigns did NOT itself drop (ruling out a
  budget-reallocation cause) -> PAUSE the live waiver concept and reassess before the scheduled wave
  boundary.
- **Net-new confirmation:** track waiver-LP families who pay the $65 the STANDARD way even when shown
  the waiver (healthy-LP signal) separately from waiver activations. A win = net-new tours/reserves,
  not standard families rerouted.
- **Honesty:** at ~0.5 non-waiver paid fee-paids/week account-wide baseline, this is a QUALITATIVE
  flag, not a powered before/after test. Treat any visible drop as a prompt to look, not proof. The
  guardrail's value is catching a large, obvious reroute, not a subtle one.

---

## 6. Kindred grid metrics (what each cell + rollup MEANS)

The grid (`design/campaign-grid.md`) is the always-on measurement surface. Measurement owns the
DEFINITIONS behind its cells and comparative rollup; the grid lane owns the render.

- **Cell states** (per family x campaign): `not_targeted` (no send row) / `received` (delivered, no
  open/click) / `engaged` (opened or clicked, no conversion) / `converted` (reached the campaign's
  conversion event within the 7-day-click window after the send) / `suppressed` / `failed`.
  Precedence `failed > suppressed > converted > engaged > received > not_targeted`.
- **Conversion test per cell:** the reconciled per-campaign conversion event (4a map), detected via
  funnel_events OR the D1 column proxy (reserve -> `deposit_paid_at`; tour -> `tour_bookings`;
  fee -> `fee_paid_at`), with `occurred_at` inside the click window. Per-touch, not global: a family
  who converted by another path does not light a `not_targeted` cell.
- **Comparative card rollup** (cohort x mini-funnel): families / received / engaged / tour booked /
  tour completed / reserved / conv rate. Deduped at the FAMILY level (furthest milestone) so the
  rollup is honest even though per-cell credit can overlap across T3/T4 (grid tension #5). Tour
  completed reads `tour_bookings.attendance='attended'`; if the attendance instrumentation has not
  shipped, the cell shows "pending instrumentation", never a misleading zero.
- **The grid IS the closed-loop evidence surface** (HOOTL, 8): every autonomous send, open, click,
  and conversion is auditable here with drill-down (sends / opens / clicks / timestamps) without
  anyone asking. Drill = the verifier/spotcheck path.

---

## 7. The weekly scorecard v2 (the single batched update - HOOTL)

Extends E-measurement's 10-row scorecard for the multi-variant world. This file (written to
`gm-master/marketing/paid-ads/scorecards/2026-Wxx.md`) is the SINGLE batched update to Jarred
(HOOTL requirement 3). It is generated autonomously; it asks nothing. Decisions that are genuinely
Jarred's (budget, copy, conversion-action promotion) collect into the numbered inquiry at the bottom,
one line each - never as drip questions mid-week.

**Block A - live-concept funnel (one sub-table per live variant this wave):**

| # | Metric | Value | Note |
|---|---|---|---|
| 1 | LP views (this variant) | n | denominator; flag if `gmwl_lp_view` not yet firing |
| 2 | Tours booked | n | |
| 3 | Tours completed | n | attendance-marked |
| 4 | No-show rate | n% | flag n<20, CI wide |
| 5 | Completed rate (HEADLINE) | S2/S0 | primary metric; Wilson CI if n>=30 |
| 6 | Applications | n | pending_tour + waiting for waiver cohorts |
| 7 | Reserved | n | via `deposit_paid_at` |
| 8 | Spend | $ | vs the wave's daily envelope |
| 9 | Wave-boundary progress | n/100 sessions, d/14 days | the pre-registered checkpoint |

**Block B - lifecycle-email KPIs (T1-T4):** delivery %, CTR (trust metric), 7-day-click conversion %,
unsubscribe % - one row per active lifecycle campaign.

**Block C - comparative + guardrail:**
- OPEN ENROLLMENT vs standard head-to-head (framing read + mechanic read), directional-labeled.
- Cannibalization guardrail status: non-waiver fee-paid starts this week vs 4-week baseline; trigger
  fired yes/no.

**Block D - decision-rule status:** for each live concept, the current SCALE / ITERATE / KILL standing
against section 3 thresholds, plus days/sessions to the wave boundary. This is the pre-computed
recommendation; the ACTION on it (budget/pause/scale) is the Jarred inquiry line, not an auto-execute.

---

## 8. HOOTL governance mapping (measurement components)

Per the CONTEXT-PACK2 mandate, every measurement component mapped to autonomy class / evidence trail /
escalation target / kill switch:

| Component | Autonomy class | Evidence trail | Escalation target | Kill switch |
|---|---|---|---|---|
| Per-variant instrumentation (`gmwl_lp_view`, tour events, offer stamping) | AUTONOMOUS | funnel_events + GA4 + campaign_sends rows written at act time | #biz-gm-ads if an event stops firing | env flag per event family; LP `?offer=` decode is client-guarded |
| Lifecycle-email tracking (pixel + wrapped links + campaign_sends) | AUTONOMOUS | campaign_sends open/click/delivered stamps + Postmark webhooks | #biz-gm-ads on delivery <95% or unsub spike | `CAMPAIGNS_ENABLED=0` disarms all; per-campaign wave gate |
| Weekly scorecard generation | AUTONOMOUS (the single update) | the scorecard file itself, committed | n/a (it IS the update) | n/a - read-only report |
| Decision-rule evaluation at wave boundary | AUTONOMOUS to COMPUTE + RECOMMEND | Block D of the scorecard | the recommendation goes to #biz-gm-ads; the ACTION (budget/pause/scale) is the numbered Jarred inquiry | pausing the TEST campaign is agent-owned; budget change is Jarred |
| Cannibalization guardrail | AUTONOMOUS weekly check | Block C status line | #biz-gm-ads if triggered (agent-owned pause of the test concept) | pause the live waiver concept via campaign status |
| Anomaly triage (event stopped, delivery failed, unsub spike, Local-actions pollution) | AUTONOMOUS self-heal | error_log + scorecard note | #biz-gm-ads, NEVER Jarred's inbox (feedback_no_automated_performance_emails_to_jarred) | the owning instrument's flag |
| Conversion-action config (promote to PRIMARY, import) | GATED | change-log + GAQL verify | the numbered Jarred inquiry | n/a - a Tier-2 human gate by design |

**The single batched inquiry (measurement's contributions, numbered for the master plan):**
1. Demote the 3 Local-actions PRIMARY conversions (Directions / Other engagements / Website visits) to
   SECONDARY before importing any tour/lifecycle conversion - they pollute the Conversions column and
   dirty the comparative read from day one (ga4-ads-state section 3).
2. Keep every new tour/lifecycle conversion action SECONDARY at launch; protect
   `gmwl_fee_paid_confirmed` PRIMARY $65 as the uncontaminated headline metric. Promotion to PRIMARY
   is a later volume-earned, Jarred-gated step (as fee-paid earned it).
3. Confirm the reserve event name (`gmwl_reserve_confirmed` vs `gmwl_reserve_deposit_paid`, section 2
   S4 note) before wiring the $1,839 reserve import - a code read, not a guess.
4. Budget envelope per wave (E sized one $12/day test; the pipeline caps concurrent spend at 2 live
   concepts but Wave 2 audience cuts + a seasonal flight need their own line).

---

## 9. Measurement build dependencies (ranked, what my lane needs before a read exists)

1. **`gmwl_lp_view` keyed on the offer param** - the ONLY missing per-variant DENOMINATOR. Without it
   every S2/S0 and S4/S0 rate has no base and the whole comparative read is impossible. Small client
   add on the already-gtag-tagged LPs (ga4-ads-state section 5; ad-variants section 7). Mirror to
   `funnel_events` for the grid. This is dependency #1.
2. **`gmwl_tour_completed` generic event + `tour_bookings.attendance` as system of record** (C-7).
   The PRIMARY success metric (completed rate) does not exist without the attendance mark. V4's Wave-0
   job is to generate the first real completions and give Ashley the marking reps.
3. **Tour events cold-start** - `gmwl_tour_booked` / `gmwl_tour_completed` have never fired, so GA4
   has not observed them, so they cannot be made key events or imported. V4 lights them up first;
   until then they cannot enter the Ads bidding surface (only the D1 + GA4-event surface).
4. **Lifecycle emails on the `campaigns.ts` ledger** (campaign_sends), not a bespoke `sendEmail` path,
   or their grid columns and every email KPI in section 4 are permanently empty (campaign-grid dep 1).
5. **T2 fires a durable `gmwl_reserve_exit_winback_*` funnel_events row** (server-recorded, not only
   client gtag), or the T2 grid column and the T2 popup KPI cannot render (C-2; campaign-grid dep 3).
6. **Local-actions demotion** (inquiry #1) before any import - measurement hygiene precondition.

---

## 10. One-line summary for the synthesizer

Cohort = `?offer=` code (canonical registry section 1, reconciled to lp-factory + the server
allowlist). Read per-wave against the ad-variant pipeline (V4 solo -> V1 vs V5 -> scale), decision at
the 2-week/100-session boundary with E's SCALE/ITERATE/KILL thresholds (8 completed to scale, <50%
completion tightens, <3 booked kills). Comparative funnel = variant x [LP view, tour booked, tour
completed, application, reserve, enrolled] with `deposit_paid_at` and `tour_bookings.attendance` as
authoritative signals and every rate directional-labeled under n=20. Email KPIs anchor on the verified
CLICK (opens are MPP noise) with a 7-day-click conversion window; the Kindred grid is the closed-loop
evidence surface and the weekly scorecard is the single batched update. Biggest build gap: the
per-variant `gmwl_lp_view` denominator event (nothing measures per-variant conversion without it),
then the generic `gmwl_tour_completed` + attendance signal the primary metric depends on. Clear the
Local-actions conversion pollution before importing anything.
