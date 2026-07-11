# E - Measurement Design: Tour-Waiver Test
Lane: MEASUREMENT. Written 2026-07-10 PM. Companion to CONTEXT-PACK.md and the other 4 build lanes.
Nothing here executes anything. Every number is a plan input, not a live config.

## 0. TL;DR (see final summary at bottom for the 10-line version)
Primary metric = tour-completed rate per LP session, not fee-paid, for the duration of the test.
Recommended structure = a dedicated campaign + dedicated LP (per Jarred's directive), with keywords
mirrored from Core High-Intent/Infant rather than new "tour-intent" keywords, to minimize the
audience confound. At 5-15 clicks/day this reaches a directionally-readable n (about 100 LP
sessions) in roughly 1-3 weeks, but a statistically clean read on booking-rate lift (10% vs 25%)
needs about 200 total sessions (about 2-6 weeks), and the enrollment-level true-north metric will
NOT be statistically significant in 30 days at this budget - it will be read qualitatively against
the LTV economics instead.

## 1. Hypothesis, primary metric, secondary metrics

**Hypothesis:** Waiving the $65 waitlist fee, conditional on completing a tour, converts more
LP visitors into tour completions than the standard flow (fee due at application), because the
current data shows the fee step - not interest - is the binding constraint (2 of the last 2
applications stalled at payment; 38% app-to-fee is the whole-funnel ceiling).

**Primary metric (recommend):** tour-completed rate = tour_completed / LP sessions, tracked both
per LP session and per paid click (the two will diverge slightly on bounce; report both, lead with
per-session). This is the metric closest to the mechanic being tested (fee waived ONLY IF tour
completes) and is the first metric with enough volume to move inside 30-60 days.

**True-north lagging metric:** enrollment / reservation rate from waiver-LP-attributed sessions.
This is the metric that actually matters financially but will not have a statistically meaningful
n in the test window (see section 3). Track it, report it, do not gate the go/no-go decision on it
alone unless n is separately large enough.

**Secondary metrics (all per LP session unless noted):**
- Application starts (gmwl_application_submitted) - are people applying at all off this LP.
- Pending-tour applications - applications sitting in the fee-deferred state waiting on a tour
  (a new state this test introduces; see section 5).
- Waiver-to-activation rate = (tour completed AND fee waived) / (tour booked) - measures whether
  the waiver actually converts bookings into completions, i.e. is the offer pulling people through
  or just getting empty calendar holds.
- No-show rate = 1 - (tour completed / tour booked). This is the single biggest execution risk of
  the whole test (see section 4, tighten branch) - a free perk with no cost to no-show invites
  exactly this failure mode.
- Cannibalization check: fee-paid (non-waiver) application volume from Core/Infant/Preschool during
  the test window vs. the trailing 4-week baseline. Are we creating NEW conversions or just moving
  people who would have paid anyway onto the free path.

## 2. Test structure options (scored)

| Option | What it isolates | What it confounds / costs | Ops complexity |
|---|---|---|---|
| (a) Dedicated campaign + dedicated LP | Clean structural separation; easy to report, easy to budget-cap, easy to kill | Confounds AUDIENCE with OFFER - tour-intent keywords ("tour preschool sacramento," "visit daycare before enrolling") skew toward people already close to a decision, vs money keywords ("daycare cost," "waitlist"). A lift here could be keyword-quality, not offer-quality | Low - new campaign is a known pattern in this account |
| (b) Ad-variant test inside existing campaigns (same ad group/keywords, rotate waiver-offer ad copy vs control ad copy) | AUDIENCE (same searchers, same keywords) - cleanest read on whether the OFFER MESSAGE alone moves CTR/apply rate | Needs "Do not optimize: rotate indefinitely" set on the ad group (Google's default auto-optimize will not hold an even split); still needs matching Final URLs per ad variant if the LP differs, which reintroduces LP-routing complexity anyway | Medium - correct rotation setting must be verified live, easy to silently revert to auto-optimize |
| (c) LP-level test, same ads (rotate Final URL / a variant param between waiver LP and control LP) | AUDIENCE AND ad copy both held constant; isolates the LP/offer variable directly | Needs a small amount of app-side engineering (50/50 assignment + variant tagging on events) rather than Ads-console configuration | Low-medium - the site already has the attribution plumbing (migration 012, GA4 custom params) to tag a variant per session cheaply |

**Google's native tooling check (why this account can't lean on it):** Google Ads "Drafts and
Experiments" custom experiments split a percentage of a campaign's traffic to a draft version for a
set duration and are built for campaigns already carrying meaningful volume on standard/automated
bidding; this account is six campaigns at Stage 0 capped Max Clicks doing 43-58 clicks/WEEK total,
under a tuning freeze until 7/16 and a never-drop constraint. Splitting that little traffic further
inside a formal Experiment would halve an already-thin sample and take months to read, and Max
Clicks experiment reporting is unreliable at this volume. Ad rotation ("Optimize: Prefer best
performing" vs "Do not optimize: rotate evenly") is a real, usable lever for option (b) but is a
manual setting per ad group that silently reverts to Google's preference if anyone touches the ad
group's serving settings later - a known footgun, note it in the build lane if (b) is ever used.

**Recommendation:** Jarred's directive already specifies a dedicated LP (and, from the phrasing, a
dedicated campaign) - that is structurally option (a). Rather than re-litigate the directive,
CONSTRAIN option (a) to minimize its own biggest weakness: mirror the exact keyword list from
Search - Core High-Intent (and optionally Infant) into the new campaign instead of writing new
"tour-intent" keywords. This makes the test behave like a hybrid of (a) and (b) - same searchers
as the money campaigns, different ad copy (waiver offer) and different LP (waiver mechanic) - which
is the cleanest read achievable without new engineering. Do NOT also stand up option (c)'s LP
randomizer for Test A; save that pattern for Test B or a future round if Test A's directional signal
is promising enough to formalize.

## 3. Sample-size honesty (binomial power sketch)

Assume the test campaign runs $10-15/day and holds a typical account CTR (about 4-5%, per the
scorecard), yielding roughly 5-15 clicks/day dedicated to the test, i.e. about 35-105 LP
sessions/week. All numbers below are alpha=0.05 two-sided, 80% power, two-sample proportion test
(z_alpha/2=1.96, z_beta=0.84).

**To distinguish a 10% vs 25% tour-booking rate (a big, "yes this obviously works" gap):**
n approx 100 per arm, approx 200 total sessions. At 5-15 clicks/day that is roughly 1.3-5.7
weeks to collect (200 sessions / (35 to 105 per week)).

**Smaller, more realistic gaps take much longer:**
- 10% vs 20% (a moderate lift): approx 200/arm, approx 400 total - roughly 4-11 weeks.
- 15% vs 30%: approx 120/arm, approx 240 total - roughly 2.3-6.9 weeks.
- 5% vs 15% (near the true baseline given today's fee-step friction): approx 140/arm, approx
  280 total - roughly 2.7-8 weeks.

**What n=30/50/100 actually buys you (95% Wilson CIs on the OBSERVED rate, no control arm needed -
useful for "is this at least directionally healthy," not for proving a specific lift):**

| n | observed rate | 95% CI |
|---|---|---|
| 30 | 0% (0/30) | 0% - 11.4% |
| 30 | 20% (6/30) | 9.5% - 37.3% |
| 50 | 10% (5/50) | 4.4% - 21.4% |
| 50 | 20% (10/50) | 11.2% - 33.0% |
| 100 | 10% (10/100) | 5.5% - 17.4% |
| 100 | 20% (20/100) | 13.3% - 28.9% |
| 100 | 25% (25/100) | 17.6% - 34.3% |

Reading this plainly: at n=30 (about 2-6 days of test traffic), a 0-for-30 result is a real signal
(true rate is very likely under about 11%) but any nonzero result has a CI so wide it cannot
distinguish "this is fine" from "this is great." At n=100 (about 1-3 weeks), the CIs finally
separate enough to tell a 10% world from a 25% world with reasonable confidence, but NOT a 10% world
from a 15-18% world - those still overlap.

**What CANNOT be learned in 30 days at $10-15/day:**
- Whether the true tour-booking lift is a modest 5-10 points (vs a dramatic 15+ point swing) -
  the confidence intervals will straddle both hypotheses.
- Anything statistically defensible about enrollment/reservation rate. Expected volume at a 15-25%
  booking rate and a generous 50% show rate and a 10-20% tour-to-enrollment rate is roughly
  0.4-2 enrollments in 30 days off this LP alone. That is a real business outcome (see section 7
  break-even) but it is an n of 1-2, not a rate estimate.
- No-show rate with tight confidence unless bookings clear about 20-30 in the window; below that,
  one or two no-shows swing the observed rate by 5-10 points on their own.
- Whether any observed lift survives once the campaign leaves Stage 0 / Max Clicks and the account
  unfreezes 7/16 - bidding-strategy changes are a separate confound this test cannot control for
  if they land mid-test.

## 4. Decision rules (pre-register before launch)

Decision point: **100 LP sessions on the waiver LP, OR 6 weeks elapsed, whichever comes first.**
(100 sessions is the point where the Wilson CIs in section 3 start actually separating hypotheses;
6 weeks is the outer bound given never-drop and the 7/16 unfreeze changing account conditions.)

- **SCALE** if: at least 8 tours COMPLETED (not just booked) in the window, AND at least one of
  (i) at least 1 paid reservation/enrollment traced to the waiver LP, or (ii) at least 3 fee-paid
  (non-waiver-path) applications generated from the same LP traffic (i.e. some visitors convert
  the standard way even when shown the offer, showing the LP/audience is healthy beyond just the
  waiver mechanic). Justification for "8 completed": at n=100 sessions, 8 completions is an 8%
  completed-rate floor, which is already above the current 0-to-organic-only fee-paid reality and
  clears the noise floor in the CI table without requiring a formal p<0.05 result (see section 7 -
  the payoff asymmetry means we do not need statistical certainty to justify continuing).
  Action: increase test-campaign budget share, propose extending the waiver offer to Infant/
  Preschool LPs (Tier 2 budget + parent-facing-copy gates apply).
- **TIGHTEN** if: at least 8 tours BOOKED but completed-rate is under 50% (heavy no-show). This is
  the free-perk-with-no-cost failure mode. Action: add a confirmation/reminder cadence (T-24h,
  T-2h - does not exist today, see section 5) and/or convert the waiver from "free with any
  booking" to "waived only after a small refundable hold," then re-run 2 more weeks before a
  scale/kill call.
- **KILL** if: under 3 tours booked by the decision point, OR bookings happen but completions stay
  near zero even after one reminder-cadence fix cycle. Action: revert LP to the standard (no-waiver)
  version, keep the campaign's keyword/audience learnings for the broader account, document why
  in the scorecard so the idea is not silently re-proposed.
- **GUARDRAIL (cannibalization, check weekly, not just at the decision point):** if fee-paid
  (non-waiver) application starts from Core/Infant/Preschool fall to zero for 2+ consecutive weeks
  during the test AND spend/impression share to those campaigns did not itself drop (ruling out a
  budget-reallocation cause) -> pause the waiver test immediately and reassess before the scheduled
  decision point. Honesty note: at today's baseline (about 0.5 non-waiver paid fee-paids/week
  account-wide, essentially all organic historically), this guardrail is more a qualitative flag
  than a statistically powered test - there is not enough baseline volume to compute a real
  before/after comparison. Treat any visible drop as a prompt to look, not as proof on its own.

## 5. Instrumentation checklist

**Already live, reuse, do not rebuild:**
- `gmwl_tour_booked` - server-side GA4 Measurement Protocol event, fires on `POST /api/tours/book`
  (gm-waitlist `src/server/routes/tours.ts`), registered as a GA4 KEY EVENT (property 485324629,
  keyEvents/15224720160). Already carries `conversion_type: winback|direct` and
  `method: email_one_tap|page_picker`. ADD for this test: a `variant` or `offer` param
  (e.g. `offer: fee_waiver_test`) so waiver-LP bookings are separable from organic/winback bookings
  in the same event stream, rather than needing a new event name.
- Migration 012 attribution columns (utm_*/gclid/attribution_source/referrer/landing_path) on every
  application row - the waiver LP needs no new attribution plumbing, just to be a distinct
  `landing_path` value so it is filterable.
- `ads_daily` (migration 037) and the `/api/crm/ads-funnel` view (gm-waitlist
  `src/server/ads-funnel.ts`) - the Kindred `/ads` dashboard already has a `tour_requested` /
  `tour_invited` / `tour_clicked` ladder; extend the STAGE_ORDER / EVENT_STAGE maps (same file) with
  a `tour_booked` and `tour_completed` stage so the waiver-path funnel reads on the same dashboard
  as fee-paid, rather than as a one-off report.

**New for this test (does not exist today, build-lane work, not yet built):**
- `gmwl_tour_completed_waiver` - does NOT exist. Today the system tracks BOOKING
  (`gmwl_tour_booked`) but nothing marks a tour as actually happened vs a no-show. This is the
  single most important instrumentation gap for this whole test (the primary metric depends on
  it). Needs a completion-marking step - simplest version: Ashley (or the calendar bridge) marks
  `tour_bookings.status` -> a new value, e.g. `completed` or `no_show`, after the appointment time
  passes, either via a manual daily check or a bridge script that reads whether the calendar event
  still exists / was not cancelled. Fires the GA4 event server-side on that status transition, same
  pattern as `gmwl_tour_booked`.
- `gmwl_waiver_expired` - fires when a `pending_calendar`/booked tour's slot passes without a
  completion mark and the associated application's fee comes due (reverts to the standard $65
  charge). This is the event that operationalizes "the waiver test only takes effect if they
  finalize the tour" - it is the automatic fallback, not a manual chase.
- `gmwl_waiver_lp_view` (or reuse GA4's automatic `page_view` filtered by the waiver LP's path) -
  a plain LP-view event is the denominator for "tour-completed rate per LP session" in section 1;
  confirm whether standard GA4 page_view is sufficient (it likely is, filtered by landing_page) or
  whether a custom event is cleaner for de-duplication against the overlay's own view events.
- Reminder/no-show reduction (feeds the section 4 TIGHTEN branch): no T-24h/T-2h reminder cadence
  exists for ANY tour today (confirmed - only the immediate booking confirmation email exists,
  `tours.ts` line ~367). If the test shows a no-show problem, this needs building before a second
  test cycle, not during the first.

**Ads conversion-action config:**
- Recommend creating **NO new PRIMARY conversion action** during the test. The account's headline
  metric (`gmwl_fee_paid_confirmed` Purchase, PRIMARY $65) must stay protected and uncontaminated -
  this test is explicitly measuring a DIFFERENT, non-fee-paid path, and mixing it into the primary
  bidding signal would repeat the exact "$5-email-chasing trap" pattern already flagged in the
  account's bidding-gate framework (gm-ads brief.md).
- If a GA4 event needs a conversion action at all (e.g. so Ads UI segments show it), create
  `gmwl_tour_completed_waiver` as SECONDARY only, same treatment as `gmwl_application_submitted`
  today. Report the test's results via GA4 segments/explorations and the `/ads` dashboard, not
  via the Ads conversions column.

**ads_daily / dashboard additions:**
- Extend the Kindred `/ads` funnel view (ads-funnel.ts) with a `tour_booked` and `tour_completed`
  ladder stage (see above) and a `waiver_active: bool` flag per application row so the dashboard
  can filter waiver-path vs standard-path side by side without a separate report.
- No changes needed to `ads_daily` (migration 037) itself - it is campaign-level spend/click/impr,
  unaffected by the offer mechanic; the new campaign (if created per section 2) just adds a new
  `campaign_id` row, same as any other campaign.

**Weekly scorecard row format** (matching `gm-master/marketing/paid-ads/scorecards/2026-Wxx.md`
conventions - numbered rows, headline metric first, note column for caveats):

| # | Metric | Value (this week) | Note |
|---|---|---|---|
| 1 | Tour-completed rate (HEADLINE, this test) | X / Y LP sessions | flag n so readers don't over-read a small sample |
| 2 | Tours booked | N | |
| 3 | Tours completed | N | |
| 4 | No-show rate | N% | flag if n<20, CI is wide |
| 5 | Waiver-to-activation rate | N% | completed / booked |
| 6 | Applications from waiver LP (fee-paid vs waived-pending) | N / N | |
| 7 | Enrollments/reservations traced to waiver LP | N | qualitative at this n, see section 3 |
| 8 | Cannibalization check | non-waiver fee-paid apps this wk vs 4wk baseline | guardrail trigger status |
| 9 | Spend on test campaign | $ | vs $10-15/day envelope |
| 10 | Decision-point progress | N/100 sessions, N/6 weeks | |

## 6. Test B ($45 same-day-enroll waiver) - phase-2 measurement sketch

Test B only makes sense once the tour flow itself is proven out (Test A), because Test B's whole
premise - waiving the $45 enrollment fee if the family enrolls the SAME DAY as their tour - requires
tours to already be a working, measured funnel stage. Sequence it strictly after Test A produces a
decision (scale/tighten/kill), not in parallel.

**Baseline reality today:** tour-to-enrollment behavior is essentially UNMEASURED. The $45 fee is
managed externally in Brightwheel billing, manually, with no system link back to whether a tour
happened or when. There is no existing "tour_date vs enroll_date" delta anywhere in D1.

**Minimum viable instrumentation before Test B can be designed at all:**
1. Once `gmwl_tour_completed_waiver`-style completion tracking exists (section 5), add a
   `tour_completed_at` timestamp visible on the same application/child record that eventually
   reserves, so a `reserve_date - tour_completed_at` delta can be computed in D1 - today nothing
   joins tour records to reservation records at all.
2. Run that delta as a passive OBSERVATIONAL metric (no offer live yet) for at least a few weeks to
   establish the actual baseline distribution of tour-to-enroll timing. Without this baseline,
   "waived if same day" cannot be evaluated against anything - we would not even know what fraction
   of families enroll same-day TODAY, so we could not tell if the incentive changed behavior.
3. Only after that baseline exists, design Test B as a proper before/after or holdout comparison
   on same-day-enroll rate, with its own decision rules following the same power-analysis honesty
   as section 3 (same-day enrollments will be an even smaller n than tour completions here, so
   expect an even longer read window).

## 7. Cost of the test

**Spend envelope:** $10-15/day x up to 42 days (6-week outer bound) = **$420-630** in ad spend
(bounded, Max Clicks capped, never-drop does not apply to this NEW campaign's budget the way it
applies to the existing five, since this is Tier 2 budget-gated at creation anyway).

**Waived-fee exposure (worst case):** using the upper end of the section 3 booking-rate range
(25% of 100 sessions = 25 bookings) and assuming a generous 60% completion rate = 15 completions,
worst-case forgone fee revenue = 15 x $65 = **$975**. A more realistic midpoint scenario (12%
booking rate, 50% completion = about 6 completions) = 6 x $65 = **$390**.

**Staff cost (Ashley's tour time):** each tour runs about 30-45 minutes. At a placeholder internal
labor-cost rate of $25-30/hr (assumption - no actual wage figure was available in this pack; flag
for Jarred to correct if materially off), midpoint scenario of 6 completed tours x 0.625 hr avg x
$28/hr = **about $105**. Worst-case scenario of 15 completed tours = **about $260**. Note this is
an internal/opportunity cost, not new out-of-pocket cash, and Ashley would likely be running some
tour volume regardless (the tour page is already live and getting winback traffic).

**Total cost of the test:**
- Midpoint scenario: $420-630 spend + $390 waived fees + $105 staff = **roughly $915-1,125**.
- Worst-case scenario: $420-630 spend + $975 waived fees + $260 staff = **roughly $1,655-1,865**.

**Break-even arithmetic:** monthly enrollment LTV ranges $1,436-$2,074 (Preschool to Infant/Toddler
rate card), BEFORE accounting for multi-year retention, which the CONTEXT-PACK notes as typical.
Dividing the worst-case total cost ($1,865) by the LOW end of monthly LTV ($1,436) gives **1.3
months of ONE enrollment's revenue** to fully cover the entire test, worst case, spend + waived
fees + staff time included. The midpoint scenario ($1,125) needs less than one month of one
enrollment ($1,125 / $1,436 = 0.78). Because retention is multi-year, a single net-new enrollment
attributable to this test - even a fraction of one, weighed against the section 3 honest estimate
of roughly 0.4-2 likely enrollments in 30 days - overwhelmingly pays for the whole experiment many
times over across its lifetime value. This is the core argument for why section 4's decision
thresholds do not require statistical significance to justify continuing: the payoff is asymmetric
enough that "not obviously zero" is sufficient to keep testing, while a hard kill trigger (section 4)
still exists to bound the downside if it truly is zero.

---

## Summary (10 lines)

Recommended structure: dedicated campaign + dedicated LP (per Jarred's directive), keyword list
mirrored from Core High-Intent/Infant rather than new tour-intent keywords, to minimize the
audience-vs-offer confound; Google's formal Drafts-and-Experiments tooling does not fit this
account (too little volume, Max Clicks, active freeze).
Weeks to signal: a directional read (n about 100 LP sessions) arrives in roughly 1-3 weeks at
5-15 clicks/day; a statistically clean 10%-vs-25% booking-rate comparison needs about 200 sessions,
roughly 2-6 weeks; anything below a 10-point gap, or any enrollment-level rate, cannot be read with
confidence inside 30 days at this budget.
Decision rules: 100 sessions or 6 weeks, whichever first; scale on 8+ tours completed plus at least
one enrollment or 3+ non-waiver fee-paids off the same LP; tighten (reminders/hold) if bookings
exist but completion is under 50%; kill under 3 bookings or persistent zero completions; weekly
cannibalization guardrail on non-waiver fee-paid volume.
Break-even: worst case total cost about $1,655-1,865 (spend + waived fees + Ashley's tour time),
covered by roughly 1.3 months of a single enrollment's revenue before multi-year retention is even
counted - the asymmetry is why the decision bar in section 4 is deliberately low.
Biggest instrumentation gap: tour COMPLETION (vs booking) is not tracked anywhere today; building
`gmwl_tour_completed_waiver` / `gmwl_waiver_expired` is the prerequisite for the primary metric.
