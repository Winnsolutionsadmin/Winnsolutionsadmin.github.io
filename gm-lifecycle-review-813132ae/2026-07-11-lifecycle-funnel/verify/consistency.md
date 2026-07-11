# VERIFY: Internal-consistency attack on the lifecycle-funnel design set (2026-07-11)

Adversarial job: attack INTERNAL CONSISTENCY across the eight design files (and the ground they
lean on), not policy or feasibility. Do the emails link to URLs the LP/reserve designs define; does
every grid campaign have events the data lane emits; do `?offer=` params match across LP factory /
ad variants / waitlist flow; do the T3 and T4 $45 waivers interact sanely; does the OPEN ENROLLMENT
cohort actually get caught by T1. Every finding is cited to file + section.

No em dashes below. Verdict vocabulary: **BLOCKER** (ships wrong / silently broken), **HIGH**
(materially wrong, corrupts a read or a promise), **MEDIUM** (drift that will bite), **OK** (checked,
consistent).

Files audited: `design/{email-reserve, email-tour-nudge, email-post-tour, winback-popup,
campaign-grid, ad-variants, lp-factory, improvements}.md` + `design/lp-open-enrollment-mockup.html`,
against `ground/{waiver-package, enrollfee-noshow, tours-fees-code, email-infra, ga4-ads-state,
kindred-portal, d1-schema, site-lp-conventions}.md`.

---

## 0. Headline: the design set is NOT internally consistent

Nine real contradictions, three of them BLOCKER-class. The two most dangerous are (a) **T2 is
designed twice, incompatibly** (two files describe the same reserve-exit popup with different copy,
different offer, different destination URL, and one of them uses banned phrasing), and (b) **the
`?offer=` codes and LP slugs do not match between the ad-variant lane and the LP-factory lane for
V3/V4/V5**, so an ad would point at a page that does not exist or a waiver the server will not
honor. Separately, **the T3 and T4 $45-enrollment-fee waivers have no defined precedence and assert
contradictory deadlines for the same fee**, and **the campaign grid reads event names the data lane
does not emit** for both T2 and the reserve conversion.

---

## 1. Trigger x Cohort matrix (the map the directive asked for)

Cohorts a family can be in:
- **A. Standard fee-paid** - paid $65 via normal flow, no tour. (`applications.fee_paid=1`)
- **B. OPEN ENROLLMENT, tour completed** - entered via a waiver LP (V1/V5/V3), toured, $65 waived.
  `fee_paid=0`, `tour_waivers.waiver_state='waived'`.
- **C. OPEN ENROLLMENT, tour pending** - entered via waiver LP, tour booked, not yet completed.
  `fee_paid=0`, `waiver_state='pending_tour'`.
- **D. Email-only lead / tour visitor with no application.**

| Trigger (predicate) | A std fee-paid | B openenroll waived | C openenroll pending | D lead/no-app |
|---|---|---|---|---|
| **T1-A** (`fee_paid=1`, no tour, not reserved) | FIRES | no (fee_paid=0) | no (fee_paid=0) | no |
| **T1-B** (`fee_paid=0`, `waiver_state='waived'`, not reserved) | no | FIRES | no (state=pending) | no |
| **T2** reserve-exit popup (in reserve mode, no completed tour) | fires if they enter reserve | *should be excluded* (toured) but client check can false-fire (see C-8) | rarely (usually not in reserve yet) | no |
| **T3** (`fee_paid=1`, no tour booked, +24h post T1) | FIRES | no (has tour) | no (has tour) | no |
| **T4** (tour completed +1h, not no-show) | fires if they later tour | **FIRES** (they toured) | later, on completion | fires if visitor, but no app -> no-op |

**Two structural results fall out of this matrix:**

1. **Cohort B is caught by T1 (good) but converges with T4 and the waiver-confirm email at one
   instant** - see C-6.
2. **Cohort C (pending tour) is in a nurture dead zone** - it gets neither T1-A (no fee) nor T1-B
   (not yet `waived`) nor T3 (has a tour). If the tour expires/forfeits it silently never receives
   any lifecycle email. Probably acceptable (they have a booked tour), but no doc states it; flag as
   an intentional gap to confirm, not a contradiction.

---

## 2. BLOCKER findings

### C-1 (BLOCKER) T2 is specified twice, and the two specs contradict each other

Two design files both own the T2 reserve-exit popup and disagree on nearly everything material.

| Field | `winback-popup.md` (§4, §5) | `email-tour-nudge.md` §2 |
|---|---|---|
| Headline | `Come see us before you decide?` | `Not ready to reserve just yet?` |
| Primary button | `Book a free tour` | `Book a tour` |
| Offer carried | NONE (plain tour) | **$45 enrollment-fee waiver** (`?offer=enroll-waiver`) |
| Subtext | "Book a **free tour** ... reserve when you are ready" | "we will waive your **$45 enrollment fee** when you reserve after your visit" |
| Destination URL | `/tour/?t=<token>&utm_campaign=t2_reserve_exit_winback` (**no `?offer=`**) | `/tour/?offer=enroll-waiver` |
| Event names | `gmwl_reserve_exit_winback_shown/tour/stay/leave` | `gmwl_reserve_exit_winback_shown/tour/stay/leave` (same) |

These cannot both ship. The event names agree, but the copy, the offer, and the destination do not.
Concretely: if `winback-popup.md` wins, the T2 tour booking carries **no offer param**, so the $45
waiver never attaches - yet `email-tour-nudge.md` §2c promises "we will waive your $45 enrollment
fee." If `email-tour-nudge.md` wins, the popup dangles the un-automated $45 (a HOLD item per
`policy-compliance.md` §2) inside an on-site overlay.

Root cause: the directive (CONTEXT-PACK2 item 2) describes T2 as a plain "book a tour winback
popup" with **no $45 mention** (the $45 belongs to T3, item 9... item 3 line). `winback-popup.md`
followed the directive's scope (plain tour); `email-tour-nudge.md` conflated T2 with T3's offer.

**Fix:** pick one. Recommended: T2 = plain book-a-tour winback per the directive (no $45 promise on
an exit popup that fires before any tour), routing `/tour/?t=<token>&...` with NO `?offer=enroll-waiver`.
Then delete the $45 copy from `email-tour-nudge.md` §2 and have it defer entirely to `winback-popup.md`.
Also fix the banned phrasing in the winner (see C-9).

### C-2 (BLOCKER) The campaign grid reads T2 off the WRONG event family

`campaign-grid.md` §3c synthesizes the T2 column from `gmwl_fee_exit_winback_shown` /
`..._tour` / `..._stay`, and §2b query 3 selects exactly those names. But those are the **existing
fee-exit popup** events (`ground/tours-fees-code.md` §3: fires on the `pay`/`child` steps). The NEW
T2 reserve-exit popup fires `gmwl_reserve_exit_winback_shown/tour/stay/leave` (both T2 designs agree
on this). So the grid's T2 column will render the OLD fee-abandon popup's activity and show
`not_targeted` for every family that actually saw the reserve-exit popup. The two surfaces are
distinct by design (`winback-popup.md` §3: "SEPARATE flags on purpose").

**Fix:** `campaign-grid.md` §2b query 3 and §3c must query `gmwl_reserve_exit_winback_*`, not
`gmwl_fee_exit_winback_*`. Also add these names to the durable-`funnel_events` requirement already
flagged in §10 dep 3 (the popup fires client gtag today; the grid needs a server row).

### C-3 (BLOCKER) `?offer=` codes and LP slugs do not match across lanes

The ad-variant lane and the LP-factory lane assign **different slugs and different offer codes** to
V3, V4, and V5. An ad Final URL from one lane points at a page/param the other lane never builds.

| V | `ad-variants.md` §1/§4 slug + offer | `lp-factory.md` §1 slug + offer | Match? |
|---|---|---|---|
| V1 | `/lp/open-enrollment/` `open-enrollment` | `/lp/open-enrollment/` `open-enrollment` | OK |
| V2 | `/lp/back-to-school/` `back-to-school` | `/lp/back-to-school/` `back-to-school` | OK |
| V3 | `/lp/fees-waived/` **`fees-waived-100`** | `/lp/fees-waived/` **`fees-waived`** | offer MISMATCH |
| V4 | **`/lp/book-a-tour/`** **`tour`** | **`/lp/free-tour/`** **`free-tour`** | slug + offer MISMATCH |
| V5 | **`/lp/waitlist-fee-waived/`** **`waitlist-fee-waived`** | **`/lp/fee-waived-65/`** **`fee-waived-65`** | slug + offer MISMATCH |

`lp-factory.md` §1 even flags the disagreement out loud ("`fee-waived-65` here, not
`waitlist-fee-waived`") and claims the direct lane instruction wins, but `ad-variants.md` §4 was
never reconciled to it. This is load-bearing three ways:
- The server-side waiver allowlist `WAIVER_OFFER_CODES = {open-enrollment, fees-waived,
  fee-waived-65}` (`lp-factory.md` §1). If the ad ships `?offer=waitlist-fee-waived` (V5) or
  `?offer=fees-waived-100` (V3), the code is **not in the allowlist**, so the $65 waiver is silently
  NOT honored (treated as tracking-only) and the family is charged the full fee against an ad that
  promised it waived. That is the exact "unavailable offer" exposure `policy-compliance.md` §1.3
  warns about, produced by an internal naming drift.
- V4/V5 point at LP directories (`/lp/book-a-tour/`, `/lp/waitlist-fee-waived/`) the LP-factory
  build lane does not create (it builds `/lp/free-tour/`, `/lp/fee-waived-65/`) -> 404 on ad click.
- The per-slug isolation grep (both lanes mandate it) uses a slug list; two lists = one lane's grep
  misses the other lane's live slug.

**Fix:** one canonical registry. Recommended canonical (matches `lp-factory.md`, the lane that owns
the build + the server allowlist): V3 slug `fees-waived` / offer `fees-waived`; V4 slug `free-tour`
/ offer `free-tour`; V5 slug `fee-waived-65` / offer `fee-waived-65`. Update `ad-variants.md` §1,
§4, §8 to match, and update `campaign-grid.md` §4 (see C-4).

---

## 3. HIGH findings

### C-4 (HIGH) The campaign grid's cohort map uses stale/wrong offer codes and a dead LP path

`campaign-grid.md` §4 hardcodes `OFFER_VARIANTS` keyed on `landing_path`: `/lp/tour-offer/ ->
open_enrollment`, `/lp/back-to-school/ -> back_to_school`. But `/lp/tour-offer/` is the **2026-07-10
source-package LP** (`ground/waiver-package.md` §0), NOT V1's LP - V1 is `/lp/open-enrollment/` in
both design lanes. And §4 narrates the offer codes as "V3 $100+, V5 $65-waived", which match
neither `fees-waived`/`fees-waived-100` nor `fee-waived-65`/`waitlist-fee-waived`. So the grid's
cohort resolver will map real V1 traffic to `standard` (no `/lp/tour-offer/` hits) and undercount
every cohort. §10 dep 4 admits "if a variant LP ships without a mapped code its families fall into
standard," but the map as written is already wrong for V1/V3/V5.

**Fix:** derive `OFFER_VARIANTS` from the single canonical registry created in C-3; drop
`/lp/tour-offer/`.

### C-5 (HIGH) `gmwl_reserve_confirmed` is a phantom event - the data lane emits `gmwl_reserve_deposit_paid`

`email-reserve.md` §6 asserts "`gmwl_reserve_confirmed`, deposit already fire from the portal,"
`email-post-tour.md` §7 sets T4 "Conversion = the family's subsequent `gmwl_reserve_confirmed`," and
`campaign-grid.md` §2c/§3b maps T1 and T4 conversion to `gmwl_reserve_confirmed` and selects it in
§2b query 3. But the reserve flow does NOT emit that event. Per `ground/tours-fees-code.md` §4, the
reserve conversion funnel event is **`gmwl_reserve_deposit_paid`** (index.ts:3739), alongside
`gmwl_reserve_disclaimer_signed`. `gmwl_reserve_confirmed` appears nowhere in the ground. Three
design files agree with each OTHER on a name that the code does not produce.

Mitigation (why HIGH not BLOCKER): `campaign-grid.md` §3b has an "applications timestamp proxy
(reserve -> `deposit_paid_at`/`reserve_start_date`)" fallback, and the comparative view §6 uses
`deposit_paid_at`. `deposit_paid_at` is a real column (`ground/tours-fees-code.md` §4), so
conversions would still be detected via the proxy. But the named-event path is dead, and
`email-reserve.md`'s factual claim ("already fires") is false.

**Fix:** replace `gmwl_reserve_confirmed` with `gmwl_reserve_deposit_paid` everywhere (email-reserve
§6, email-post-tour §7, campaign-grid §2b/§2c/§3b/§6), or, if a distinct semantic "reserved"
milestone is wanted, define it as a NEW event to add in code and say so (do not describe it as
already firing).

### C-6 (HIGH) Cohort B gets three convergent emails at one completion instant, with no precedence

When an OPEN ENROLLMENT family completes their tour, three things become eligible simultaneously off
the same `tour_waivers.waiver_state='waived'` transition:
1. the waiver-complete "you're on the waitlist, no charge" email (`ground/waiver-package.md` §1a,
   fired by the `/tour-waiver/complete` route);
2. **T1-B**, whose audience predicate IS `waiver_state='waived'` (`email-reserve.md` §0);
3. **T4**, which fires 1h after the same tour's end (`email-post-tour.md` §1).

T1-B and T4 both drive to the reserve flow with overlapping "now reserve your space" messaging. The
72h anti-fatigue quiet window (`email-reserve.md` §1; `email-infra.md` §5) means whichever the
`*/10` sweep emits first SUPPRESSES the other for 72h - nondeterministically. That can silently eat
T4's time-boxed "5PM today" offer (the one with a real deadline) in favor of the evergreen T1-B, or
vice versa. No doc defines ordering. `email-post-tour.md` open-Q4 raises the audience overlap but
does not resolve the cadence collision or the T1-B interaction at all.

**Fix:** define precedence for cohort B at tour completion. Recommended: T4 (time-boxed, higher
intent) wins the completion window; T1-B suppresses for cohort B when a tour exists (it is really a
standard-cohort message). And confirm the waiver-confirm transactional email is allowed to co-send
(it is transactional, so it bypasses the marketing quiet window - verify it does not read as a third
redundant "reserve now" push).

### C-7 (HIGH) Tour-completion is modeled three incompatible ways; the grid reads a table nobody builds

The same fact ("this tour happened") has three representations across the set:
- `ground/enrollfee-noshow.md` C1.1 stores it as **columns on `tour_bookings`**: `attendance IN
  ('attended','no_show')`, migration `050_tour_attendance.sql`.
- `ground/waiver-package.md` §1b fires it as an **event** `gmwl_tour_completed_waiver` (only for the
  $65-waiver completion route).
- `campaign-grid.md` §2b query 4 + §6 reads a **table `tour_outcomes(booking_id, outcome)`** with
  `outcome='attended'`, called "migration 050 sibling table."

`tour_outcomes` is invented by the grid lane and matches neither the column design (attendance on
`tour_bookings`) nor any ground table. So the grid's "tour completed" query and the whole comparative
view §6 target a table that the no-show lane does not create. Additionally there is **no generic
`gmwl_tour_completed` event** for non-waiver tours (V4, or T3/enroll-waiver families) -
`ad-variants.md` §7 itself notes `gmwl_tour_completed` is MISSING, and the attendance-mark endpoint
in `enrollfee-noshow.md` C1.2 fires no funnel event.

**Fix:** one representation. Recommended: `tour_bookings.attendance` (the ground design) is the
system of record; the grid reads that (not `tour_outcomes`); the attendance-mark endpoint also fires
a generic `gmwl_tour_completed` funnel event so GA4/grid have an event, keeping
`gmwl_tour_completed_waiver` as the waiver-specific subtype.

### C-8 (HIGH) Migration number 050 is claimed by three different migrations

- `ground/waiver-package.md` §1a: `050_tour_waivers.sql` (the $65 waiver side table).
- `ground/enrollfee-noshow.md` C1.1: `050_tour_attendance.sql`, asserting "next number; 049 is
  latest."
- `campaign-grid.md` §2b: "`tour_waivers` ... migration 050" AND "`tour_outcomes` ... migration 050
  sibling."

Three distinct schemas cannot all be migration 050. The attendance lane appears unaware the waiver
lane already claimed 050. Whichever ships second under 050 will collide or be skipped.

**Fix:** sequence them (e.g. 050 = tour_waivers, 051 = tour_attendance) and update every reference,
including `campaign-grid.md`'s try/catch comments and `d1-schema` notes.

---

## 4. The T3 vs T4 $45-waiver interaction (the question, answered)

**Can a family get BOTH $45 waivers? Monetarily, no double benefit - but the two waivers assert
CONTRADICTORY deadlines for the same fee, and precedence is undefined. This is a real BLOCKER-adjacent
gap.**

Both T3 and T4 waive the SAME single `$45` enrollment fee, which lives inside the deposit
PaymentIntent (`ground/enrollfee-noshow.md` A1-A4). The planned choke point `enrollmentFeeDue(row,
waiverFlag)` returns 0 or 45 - it is a single fee, so "two waivers" just means the fee is $0 once.
There is no stacking/double-discount risk. The contradiction is in the **windows and the promises**:

| | T3 (`email-tour-nudge.md`) | T4 (`email-post-tour.md`) | `improvements.md` #3 |
|---|---|---|---|
| Offer code | `enroll-waiver` (§0) | derived server-side, no param (§7) | n/a |
| Attaches | at tour BOOK time (§1e) | at T4 send (post tour) (§7) | n/a |
| Applies | at deposit AFTER completed tour (open-Q2) | at reserve, if by 5PM PT same day (§5) | "within 24-48h of tour" |
| Deadline | **none stated** ("comes off going forward", §1f) | **5:00 PM PT the tour day** (hard, server-boxed) | **24-48h** |

Failure scenario: a Standard family gets T1-A -> gets T3 -> books a tour via `?offer=enroll-waiver`
(open-ended waiver attached) -> completes the tour -> now gets T4. T4 tells them "reserve by 5PM
today or the $45 applies." That statement is FALSE for this family: they already carry the
open-ended `enroll-waiver` from T3, which has no 5PM cutoff. Three docs describe three different
lifetimes for one fee waiver (indefinite / 5PM-today / 24-48h). Whichever the code actually enforces,
two of the three parent-facing promises are untrue.

There is also a **code-collision** risk: T3 attaches its waiver as `?offer=enroll-waiver` in
`gmwl_offer_ctx`, which the overlay reads and attaches to the application payload
(`ground/waiver-package.md` §1c). But `enroll-waiver` is NOT in `WAIVER_OFFER_CODES = {open-enrollment,
fees-waived, fee-waived-65}` (`lp-factory.md` §1), and lp-factory §1 mandates "do not waive on any
unknown offer." So an `enroll-waiver` code arriving at the $65 application-waiver branch is rejected
as not-a-waiver-code and silently dropped. `enroll-waiver` is a DIFFERENT mechanic ($45 at the
reserve/deposit step, not $65 at application), but no doc registers it anywhere the way the $65 codes
are registered - it exists only inside `email-tour-nudge.md`. See C-11.

**Fix (precedence, must be written down):**
1. Define ONE waiver window for the $45 enrollment fee. Recommended: honor it for a real dated window
   after a completed tour (the `improvements.md` #3 "24-48h" is the most defensible and makes T4's
   urgency truthful); T4's "5PM today" then becomes "by 5PM on {date}" where date is the window end,
   and T3's "going forward" is corrected to state the same window.
2. Make T3 and T4 share ONE waiver state (a `tour_completions`/waiver row keyed by `application_id`,
   `ground/enrollfee-noshow.md` A4), so a family who got T3's `enroll-waiver` and then T4 has ONE
   waiver record with ONE expiry. T4 must READ that state, not mint a second, contradictory one.
3. If a family already holds an active enroll-fee waiver, T4 must either suppress or restate the
   existing deadline, never impose a shorter one.
4. Register `enroll-waiver` as an enrollment-fee-waiver code in its own allowlist, distinct from the
   $65 `WAIVER_OFFER_CODES`, so `/tour/?offer=enroll-waiver` routes to the $45 reserve-step mechanic
   and is NOT rejected by the $65 application branch (C-11).

Note the further stack: a **V3 "$100+"** family already gets the $45 waived at reserve via the
`fees-waived` stacked code (`ad-variants.md` §4 V3). If that same family also receives T3 or T4, they
are offered the $45 waiver a second and third time on different deadlines. Same single-fee logic (no
double benefit) but the same contradictory-deadline problem, amplified.

---

## 5. The OPEN ENROLLMENT cohort vs T1 (the question, answered)

**Does the OPEN ENROLLMENT waiver cohort skip T1 because the T1 trigger says "fee-paid"? The literal
directive trigger WOULD skip them, but `email-reserve.md` already fixed this with Variant B. The fix
is correct in intent, but it introduces two secondary inconsistencies.**

- The directive's T1 trigger is "paid waitlist fee + NO tour done" (CONTEXT-PACK2 item 2). The OPEN
  ENROLLMENT cohort paid NO fee (waived) and already toured, so both clauses exclude them.
- `email-reserve.md` §0 resolves this by shipping T1 as TWO registry entries: Variant A
  (`fee_paid=1`) and **Variant B** (`fee_paid=0 AND tour_waivers.waiver_state='waived'`). So T1 does
  NOT skip cohort B. This is the right call and directly answers the directive's worry. OK.

Two secondary inconsistencies the Variant B design creates:

- **(MEDIUM) Variant B breaks the "within 24h" timing.** The directive frames T1 as "within 24h of
  landing on the waitlist." Variant B's predicate is `waiver_state='waived'`, which only becomes true
  AFTER Ashley marks the tour attended (`ground/waiver-package.md` §1a) - which can be days after the
  family landed (the tour is scheduled in the future). So Variant B is really a post-tour-completion
  welcome, not a 24h nurture. Defensible, but the doc calls both "T1 within 24h" without noting the
  timing for B is completion-anchored, not landing-anchored. And completion-anchoring is exactly what
  collides with T4 (C-6).
- **(MEDIUM) Cohort C (pending tour) is uncovered by any T1** - see §1 result 2. Neither variant's
  predicate matches `waiver_state='pending_tour'`.

---

## 6. MEDIUM findings

### C-9 (MEDIUM) The surviving T2 popup uses banned "free tour" phrasing

`winback-popup.md` §4 renders headline-adjacent copy "Book a **free tour** of our downtown Sacramento
space" and button "Book a **free tour**." The house rule bans "free tour" (`ground/waiver-package.md`
§1f: '"free tour" is banned phrasing'; `policy-compliance.md` §2 V4). `email-tour-nudge.md` §2c
carefully avoids it ("Book a tour," "nothing to pay to come see us"). So whichever T2 wins C-1, the
`winback-popup.md` copy must be de-"freed." (The EXISTING fee-exit module also says "Book a free
tour" per `ground/tours-fees-code.md` §3 - that is pre-existing debt, but T2 is new copy and should
not inherit the violation.)

### C-10 (MEDIUM) `joy.jpg` is assigned to BOTH T1-B and T4, so cohort B sees the same hero twice

`email-reserve.md` §3 gives T1 Variant B the hero `joy.jpg`. `email-post-tour.md` §2 recommends
`joy.jpg` for T4. `email-tour-nudge.md` §1d explicitly asks that "T1/T3/T4 each carry a different
picture" and reserves a third distinct asset for T4. A cohort-B family receives T1-B (joy.jpg) and T4
(joy.jpg) around the same completion window (C-6), so they get the identical image twice - violating
the "different picture per email" intent the set otherwise polices. Directive strictly requires only
that T4 differ from the `community.jpg` hero, so this is intent-drift, not a directive breach.

**Fix:** give T1-B and T4 distinct heroes (e.g. T1-B `joy.jpg`, T4 `seated.jpg` or `walk.jpg`), and
verify alt text vs asset (both docs flag the alt is unverified).

### C-11 (MEDIUM) `enroll-waiver` offer code is defined in exactly one file and registered nowhere

`enroll-waiver` (the $45 code) appears only in `email-tour-nudge.md`. It is absent from
`lp-factory.md`'s `WAIVER_OFFER_CODES` allowlist, from `campaign-grid.md`'s `OFFER_VARIANTS`, and
from `ground/waiver-package.md`'s offer-code contract (which only knows the $65 `tour-waiver`
family). As written, `/tour/?offer=enroll-waiver` flows into `gmwl_offer_ctx` and, per the waiver
contract, gets attached to the application payload where the $65 waiver branch will reject it as an
unknown non-waiver code. The $45 mechanic is a separate reserve-step concern and needs its own
registration path. Covered in the C-4 fix list; called out separately because it is the seam where
the email lane and the waitlist-flow lane never met.

---

## 7. Cross-checks that PASSED (verified consistent, for fairness)

- **T1 / T4 CTA -> reserve flow.** Both use the wrapped `/c/:token` redirect with
  `portalIntent:'reserve'` -> `gm_intent=reserve`, and `ground/email-infra.md` §6 + `tours-fees-code.md`
  §4 confirm `/c/:token` 302s to the portal with `gm_intent=reserve`, which boots the reserve flow.
  The link target the emails name is real. OK.
- **`emailShell` signature.** `email-reserve.md` §4 and `email-post-tour.md` §8 both call
  `emailShell(heading, body, cta, url, undefined, afterCta)`; `ground/email-infra.md` §3a confirms the
  6-arg signature `emailShell(heading, bodyInner, ctaText, ctaUrl, footer?, afterCta?)`. OK.
- **Suppression / CAN-SPAM classification.** All four emails keep marketing kinds OUT of
  `TRANSACTIONAL_KINDS`; `ground/email-infra.md` §4 confirms the allowlist gate then covers them. OK.
- **`campaign_sends` as the grid substrate.** `campaign-grid.md` §10 dep 1 requires T1/T3/T4 to send
  via the `CAMPAIGNS` engine so they write `campaign_sends`; all three email designs register as
  `CAMPAIGNS` entries. Internally consistent (the T4 `runTourFollowups` path in `email-post-tour.md`
  §1 explicitly writes a `campaign_sends` row). OK.
- **T3 conversion event.** `campaign-grid.md` maps T3 -> `gmwl_tour_booked`; `email-tour-nudge.md`
  §1e fires `gmwl_tour_booked` (+ new `gmwl_tour_booked_from_offer`). The event exists
  (`ground/tours-fees-code.md` §1). OK (unlike the reserve event, C-5).
- **T2 excludes already-toured families.** `winback-popup.md` §2b gates on "no completed tour," so
  cohort B is intended to be excluded - consistent with the funnel logic (caveat C-8 below is the
  client-vs-D1 edge, not a design contradiction).
- **Piggyback-cron / 5-trigger limit.** Every automated leg (T1 sweep, T3, T4 `runTourFollowups`)
  piggybacks `*/10` rather than adding a trigger; consistent across email-reserve §7, email-tour-nudge
  §1a, email-post-tour §1, and `ground/email-infra.md` §5. OK.

Edge to note under C-8-style scrutiny (not a contradiction): `winback-popup.md` §2b checks "no
completed tour" via `gmwl_offer_ctx.tour_booking_id` in the browser. A cohort-B family who toured on
one device and later opens the reserve flow on another (or after clearing session) has an empty
`gmwl_offer_ctx`, so the client check can FALSE-fire T2 at a family that already toured. The D1 truth
(`tour_waivers.tour_booking_id`) disagrees with the client signal. Recommend the eligibility gate
also consult a server flag, not only sessionStorage.

---

## 8. Ranked fix list (what to reconcile before build)

1. **C-1** Resolve the double-specified T2 (pick plain-tour per directive; delete the $45 copy from
   email-tour-nudge §2). BLOCKER.
2. **C-3** Publish ONE canonical slug + `?offer=` registry; align `ad-variants.md` to `lp-factory.md`
   (fees-waived / free-tour / fee-waived-65). BLOCKER.
3. **C-2** Point the grid's T2 column at `gmwl_reserve_exit_winback_*`, not `gmwl_fee_exit_winback_*`.
   BLOCKER.
4. **C-4** Rebuild the grid `OFFER_VARIANTS` from the canonical registry; drop `/lp/tour-offer/`.
   Depends on C-3.
5. **C-5** Replace phantom `gmwl_reserve_confirmed` with `gmwl_reserve_deposit_paid` everywhere.
6. **T3/T4 $45 precedence (§4)** Define one waiver window + one shared waiver state; correct T3/T4
   copy to the same deadline; register `enroll-waiver` (C-11).
7. **C-6** Define cohort-B completion-window precedence (T4 vs T1-B vs waiver-confirm).
8. **C-7** One tour-completion representation (`tour_bookings.attendance`); grid reads it; add a
   generic `gmwl_tour_completed` event.
9. **C-8** Renumber the colliding migration 050s.
10. **C-9 / C-10 / C-11** Scrub "free tour" from the T2 winner; split joy.jpg across T1-B/T4; register
    `enroll-waiver`.

All copy/waiver items remain Tier-2 Jarred-gated; nothing here changes that. This pass found no
new licensing text and no em dashes introduced by the design set (spot-checked); the inconsistencies
above are structural, not hard-rule violations, except C-9 (banned "free tour" phrasing).
