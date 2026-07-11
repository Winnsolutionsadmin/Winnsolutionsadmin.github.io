# DESIGN: Ad Variant Matrix - GM Lifecycle Funnel (2026-07-11)

Lane: AD-VARIANT-MATRIX. Builds on the B-lane campaign architecture
(`2026-07-10-tour-waiver-test/B-campaign-architecture.md`), the LP factory template
(`ground/site-lp-conventions.md`), the measurement frame (`ground/ga4-ads-state.md` +
`2026-07-10-tour-waiver-test/E-measurement.md`), and the waiver package distillation
(`ground/waiver-package.md`). Nothing here executes. Every RSA asset below is machine-counted
against the account's hard limits (headlines <=30, descriptions <=90). Zero em dashes. Zero
licensing language. Every "$ waived" claim carries its condition in the SAME asset.

Parent-facing copy + prod deploy + budget + clickwrap = Tier 2 Jarred gates. This is a staged plan.

---

## 0. What this lane decides (and the one thing it gets right that the directive under-specifies)

The directive lists V1-V5 as if they are five ads to launch. They are not five ads. Each is a
distinct **creative concept = its own RSA + its own message-matched LP + its own `?offer=` param**,
because they carry different offers and route to different landing pages. Google serves at the ad
level with the ad's final URL, so "running V1-V5" means standing up five separate ad-group/LP units,
not five headlines in one ad.

That distinction collides head-on with the account's volume reality, and reconciling the two is the
core deliverable of this lane:

> **Account-wide paid traffic is 43-58 clicks per WEEK, total, across all six campaigns**
> (E-measurement, verified against gaql-0711.json). A new tour/offer campaign at $8-12/day realistically
> commands a slice of that. Splitting a slice across five or seven live creative concepts starves every
> one of them below the ~100-session directional-read threshold. You would spend six weeks and learn
> nothing about any variant.

So the matrix is not a parallel launch. **It is a pipeline: at most two concepts live at once, most
of the roster on the bench, sequenced by readiness and conviction.** Sections 1-2 are that sequence;
sections 3-9 are the per-variant creative. Read section 2 first - it governs everything else.

---

## 1. The seven concepts at a glance

| # | Public hook | Offer mechanic | LP + `?offer=` | CTA type | Backend gate | Policy risk |
|---|---|---|---|---|---|---|
| V1 | **OPEN ENROLLMENT!** | $65 waitlist fee waived on tour completion | `/lp/open-enrollment/` `open-enrollment` | calendar (6b)+offer (6c) | clickwrap v2 + mig 050 + completion-mark | med |
| V5 | **$65 waitlist fee waived** | same as V1, dollar-led | `/lp/waitlist-fee-waived/` `waitlist-fee-waived` | calendar+offer | same as V1 | med |
| V3 | **$100+ in fees waived** | $65 waitlist (tour) + $45 enrollment (same-day enroll) STACKED | `/lp/fees-waived/` `fees-waived-100` | calendar+offer | V1 gates PLUS $45 automation/SOP | **high** |
| V4 | **No-obligation tour** | none (pure tour, no fee waiver) | `/lp/book-a-tour/` `tour` | calendar (6b) | **none** (ready-now) | low |
| V2 | **Back to School** | seasonal wrapper (tour, waiver optional) | `/lp/back-to-school/` `back-to-school` | calendar or overlay | none if tour-only | low-med |
| V6 | **Infant openings** (proposed) | audience cut of the winning offer, infant-targeted | `/lp/infant-tour/` `infant-tour-waiver` | calendar+offer | inherits winner's gate | med |
| V7 | **State employees** (proposed) | audience cut of the winning offer, commuter-targeted | `/lp/state-tour/` `state-tour-waiver` | calendar+offer | inherits winner's gate | med |

Two structural facts that shape the whole roster:

- **V1 and V5 are the SAME offer** (waive the $65 waitlist fee on tour completion), differing only in
  HOOK: V1 rebrands it as the welcoming "OPEN ENROLLMENT!" brand Jarred named for independent tracking;
  V5 leads with the raw dollar figure. Run concurrently on identical keywords, they are a clean
  brand-vs-dollar framing A/B on one mechanic. This is the highest-value single comparison in the matrix.
- **V6 and V7 are audience cuts, not new offers.** They take whichever HOOK wins wave 1 and narrow it
  to the emptiest/highest-value room (Infant, 10-11 open, top rate $2,074/mo) and the segment that
  produced the account's first real fee-paid (state employee, Flynn 7/7). They are how you SCALE a
  proven winner, not additional wave-1 gambles.

---

## 2. THE TESTING SEQUENCE (the load-bearing recommendation)

**Rule: maximum 2 concepts live at once; prefer 1 during the probe. 2-3 week waves. Everything else
waits on the bench.** Launch order is set by readiness gradient first, conviction second.

### Why not concurrent

At 43-58 clicks/week account-wide, a $8-12/day tour campaign might pull ~15-40 clicks/week of its own
(tour-intent CPCs run cheaper than Core's money terms, so a dollar buys more clicks than Core sees).
Even at the top of that range, one variant needs ~2-3 weeks to reach the 100-LP-session directional
threshold (E-measurement section 3). Two variants sharing one keyword pool can co-exist only because
they split the SAME queries and you read them as an A/B, not as two independent tests. A third live
concept means single-digit weekly clicks each = permanently unreadable. This is not conservatism; it
is the binomial-power math in E-measurement section 3 applied honestly.

**Volume reconciliation (hard data, read this before trusting the "2-3 week" figure).** The ~15-40
clicks/week and 2-3-week estimates above are the OPTIMISTIC bound inherited from E-measurement, which
assumed 5-15 clicks/DAY. The live account data is harsher: **W28 (6/30-7/6) = 43 clicks/week total**,
**14-day (6/22-7/5) = 58 clicks**, at a **~$10-11 CPC** on the money terms, and the account spends
only ~$61/day of its $115 budget (it is rank/impression-limited, 18 money kws still LOW_QUALITY 1-2,
36 RARELY_SERVED). A brand-new $12/day tour campaign starts at the BOTTOM of Quality Score on thinner
tour-intent inventory, so realistic delivery is **~8-12 clicks/week**, not 15-40, and lower for the
first 2-3 weeks while QS climbs. At that rate the E-measurement decision point (100 sessions OR 6
weeks, whichever first) almost always lands on the **6-week TIME bound at only ~40-60 sessions** - a
DIRECTIONAL read with wide Wilson CIs, NOT a clean 100-session statistical read (which would take
~8-12 weeks per concept). Practical consequence: treat each wave as **a 3-6 week directional probe**,
expect the full 5-7-concept sweep to be a **Q3-Q4 program (~4-6 months)**, and report every wave
winner with its CI. Do not promise Jarred five clean A/B verdicts in July; the volume forbids it.
This strengthens, not weakens, the sequence-don't-parallelize conclusion.

### The waves

**WAVE 0 - PROBE (launch FIRST, at the 7/16 batch): V4 "No-obligation tour", SOLO.**
V4 is the only concept with **zero backend gate** - no waiver, so no clickwrap v2, no `tour_waivers`
migration, no completion-mark dependency. It can launch the day the freeze lifts. It does three jobs
nothing else can do yet:
1. **Validates tour-first ad messaging pulls clicks** at an acceptable CPC before a dollar of waiver
   plumbing is built. If tour ads produce no tour demand, the entire waiver stack is de-risked away
   for the cost of one 2-week campaign.
2. **Unblocks the cold-start on the tour events.** `gmwl_tour_booked` and `gmwl_tour_completed` have
   NEVER fired (ga4-ads-state section 5), so GA4 has never observed them, so they cannot be made key
   events or imported to Ads. V4 generates the first real bookings that light them up - the exact
   prerequisite every downstream waiver variant AND the T4 lifecycle email depend on.
3. **Gives Ashley live no-show / completion-marking reps** on the Kindred admin task BEFORE the waiver
   economics ride on that mark being reliable. No-show is the single biggest execution risk of the
   whole waiver thesis (E-measurement section 4); practice it on the cheap variant first.

Run V4 solo for 2-3 weeks. It owns the entire tour ad group's clicks, so it reaches a read fastest.

**WAVE 1 - HERO (after clickwrap v2 + migration 050 + completion-mark land): V1 vs V5, CONCURRENT.**
The two-RSA framing test on the identical $65-waiver mechanic. Same ad group, same keywords, two RSAs
with different final URLs, ad rotation set to "Do not optimize: rotate evenly" (the known footgun -
verify it did not silently revert to auto-optimize; see B-lane and E-measurement option-b note),
distinct `?offer=` params for clean per-variant attribution. This resolves in one wave: (a) does the
$65-waiver offer convert at all, and (b) does brand framing (OPEN ENROLLMENT) or dollar framing ($65
waived) pull harder. V1 is the independently-tracked hero the directive names (item 4); V5 is the
dollar-led challenger Jarred explicitly requested ("One should be 65 waitlist fee waived"). 2-3 weeks.
Honesty flag: at true volume the framing split may only reach *directional*, not significant - report
the winner with its Wilson CI, do not over-read a 3-click gap.

**WAVE 2 - SCALE-OR-SEASON (conditional on the wave-1 winner):**
Take the winning hook and do ONE of:
- **Seasonal booster:** overlay V2 "Back to School" as a genuinely time-boxed flight into the August
  enrollment window (Toddler 1 opens seats from August; real calendar anchor). V2 is a THEME layer
  over the winning offer, timed to a real season - not a fifth independent mechanic.
- **Audience scale:** deploy V6 (Infant) and/or V7 (State employee) as narrowed cuts of the winning
  creative + LP, on infant / state-employee keyword sets. These chase the emptiest, highest-value seat
  and the proven-converting segment. Still max 2 live at once.
- **V3 "$100+" runs ONLY here and ONLY if the $45 automation/SOP is solved** (section 5). If the $45
  enrollment-fee waiver is still a manual Brightwheel process at wave 2, V3 ships as $65-only (which
  collapses it into V5) or is cut. Do not advertise an un-automated $45 waiver - it is the A-lane
  "unavailable offer" exposure, unchanged by the dollar-copy supersession.

### One-line sequence

`V4 solo (probe + cold-start unblock) -> V1 vs V5 (hero framing A/B) -> winner scaled via V2 season / V6-V7 audience, V3 only if $45 automated.`

---

## 3. Shared asset pools (reused across variants, stamped once)

Every variant deck = **shared pool + its own offer assets**. This mirrors how the account already
works (trust/location claims are constant; only the offer changes) and keeps the RSAs maintainable.
All counts machine-verified.

### Shared HEADLINES (drop 3-5 into every variant's 15, no offer claim, never need a condition)

| id | headline | len |
|---|---|---|
| S1 | Downtown at 750 N Street | 24 |
| S2 | 5 Min Walk From the Capitol | 27 |
| S3 | Top-Rated by Sac Families | 25 |
| S4 | Rated 5.0 on Google | 19 |
| S5 | Mindful Infant to Preschool | 27 |
| S6 | 1:3 Infant Ratios | 17 |
| S7 | Family-Founded in 2018 | 22 |
| S8 | A Calm Place to Grow | 20 |
| S9 | Nut-Free, Organic Snacks | 24 |
| S10 | Mon-Fri, 7 AM to 6 PM | 21 |

### Shared DESCRIPTIONS (drop 1-2 into every variant's 4)

| id | description | len |
|---|---|---|
| SD1 | See the rooms, meet the teachers, ask every question. A 5 minute walk from the Capitol. | 87 |
| SD2 | Mindfulness-based care from 6 weeks to kindergarten, in downtown Sacramento. | 76 |
| SD3 | Family-founded in 2018. Top-rated by Sacramento families. Book a tour to see it yourself. | 88 |
| SD4 | 1:3 infant ratios, nut-free organic snacks, sun-filled rooms. Come see it in person. | 84 |

**Trust chips (LP hero, pick 4 per site-lp-conventions section 8):** `Family-founded 2018`,
`6 weeks to kindergarten`, `Mon-Fri 7:00 AM-6:00 PM`, `5 minutes from the Capitol`,
`Top rated on Google`. (Keep the existing `Licensed by California CDSS` badge if used; add no NEW
licensing text.)

---

## 4. Per-variant RSA decks (offer assets; combine with the shared pool for the full 15+4)

Each variant ships **15 headlines = ~8 offer headlines below + ~7 from the shared pool** and
**4 descriptions = ~2-3 offer descriptions below + 1-2 shared**. Pinning: account default is
pin-nothing; the one testable exception is the dollar variants (see section 9 brainstorm).

### V1 - OPEN ENROLLMENT! (brand-framed $65 waiver)

**Hook:** rebrand the fee waiver as a warm, seasonal-sounding *open door*. "OPEN ENROLLMENT!" says
the school is welcoming families now; the mechanic underneath (complete a tour, waitlist fee waived)
lives in the supporting copy and on the LP. This is the concept tracked independently and compared
head-to-head vs the standard flow (directive item 4). Brand name is deliberately decoupled from the
dollar figure so it can later wrap whichever offer wins.

Offer headlines:
- Open Enrollment in Sacramento (29)
- Now Open: Tour and Join (23)
- Tour Us, Fee Waived (19)
- Waitlist Fee Waived on Tour (27)
- Open Enrollment, Book a Tour (28)
- Come Tour, Skip the Fee (23)
- Your Spot Starts With a Tour (28)
- Now Welcoming New Families (26)

Offer descriptions (+ SD1 or SD3):
- Welcoming families in downtown Sacramento. Tour with us and your waitlist fee is waived. (88)
- Open enrollment now. Book a tour, meet our teachers, and we waive your waitlist fee. (84)
- Come see the rooms in person. Complete a tour and your waitlist fee is waived. (78)

**LP:** `/lp/open-enrollment/`, `?offer=open-enrollment`. Calendar-first (6b) + offer handoff (6c).
Hero H1 e.g. `Now enrolling. <em>Tour us, fee waived.</em>` (teal `<em>` tail per house signature).
`.condition-line` REQUIRED: states the $65 once (Google Dishonest-Pricing policy) + the tour condition.

### V5 - $65 waitlist fee waived (dollar-framed, same mechanic as V1)

**Hook:** lead with the number. Jarred's explicit request. The dollar figure is now allowed in ad
copy (7/11 supersession); every asset that names the $65 also names the tour condition in the same
string, so no bare "fee waived" claim ever ships.

Offer headlines:
- $65 Fee Waived When You Tour (28)
- Waive Your $65 Fee, Tour Us (27)
- Tour and Save $65 (17)
- Tour to Skip the $65 Fee (25)
- Book a Tour, Waive the Fee (26)
- Your $65 Fee, Waived on Tour (28)
- Tour First, $65 Fee Waived (26)
- Skip the $65 Waitlist Fee (25)  *(pair with a tour-conditioned partner; do not run isolated - see note)*

Offer descriptions (+ SD1 or SD2):
- Book a tour in downtown Sacramento and we waive the $65 waitlist fee. See the rooms first. (89)
- Your $65 waitlist fee is waived when you complete a tour. Meet our teachers, ask anything. (89)
- Tour our downtown location, then join the waitlist with the $65 fee waived. No pressure. (88)

**LP:** `/lp/waitlist-fee-waived/`, `?offer=waitlist-fee-waived`. Same calendar + same waiver backend
as V1; hero leads with the dollar figure: `Your $65 waitlist fee, <em>waived when you tour.</em>`
Message-match discipline: the LP hero must state the condition beside the dollar, and the
`.condition-line` states the $65 once with the tour condition.

*Note on the one near-bare asset:* "Skip the $65 Waitlist Fee" names a dollar without a condition in
the string. Google rotates assets independently, so it *could* surface alone. Keep it ONLY if the
account is comfortable that the LP + the 7 conditioned partners carry the disclosure; otherwise drop
it. Conservative call: drop it and run 7 offer headlines + 8 shared. Flagged for the policy lane.

### V3 - $100+ in fees waived (stacked $65 + $45) -- HIGHEST RISK, LAST TO LAUNCH

**Hook:** stacked value. "$100+" = the $65 waitlist fee (waived on tour) plus the $45 enrollment fee
(waived on same-day/qualifying enrollment) = $110 real, truthfully expressed as "$100+". The two
halves have DIFFERENT conditions, so no single 30-char headline can fully condition both; the offer
headlines condition what they can, and the LP `.condition-line` + descriptions carry the full split.

Offer headlines:
- Tour and Enroll, Save $100+ (27)
- Up to $110 in Fees Waived (25)
- Tour + Enroll, Fees Waived (26)
- Save on Waitlist + Enroll Fees (30)
- $100+ in Fees Waived (20)  *(bare - LP must carry both conditions; policy-lane call)*
- This Week: Tour and Save (24)  *(URGENCY - only in the time-boxed flight, see section 5)*

Offer descriptions (+ SD1):
- Complete a tour to waive the $65 waitlist fee, and enroll to waive the $45 enrollment fee. (89)
- Over $100 in fees waived: $65 waitlist when you tour, $45 enrollment when you join. (82)
- Tour our downtown Sacramento location and save on both fees. See it in person. (78)

**LP:** `/lp/fees-waived/`, `?offer=fees-waived-100`. Calendar-first + offer handoff.
`.condition-line` MUST spell out both conditions and both dollar figures separately.

**Two hard gates before V3 runs (do not launch without both):**
1. **The $45 enrollment-fee waiver must be automated or backed by a verified SOP** (enrollfee-noshow
   ground doc: 7 call sites, no waiver plumbing today, Brightwheel is collection-of-record). Advertising
   an un-automated same-day $45 waiver is the A-lane "unavailable offer" exposure. Interim fallback:
   ship V3 as $65-only (== V5) until the $45 path exists.
2. **The urgency claim must be honestly time-boxed** (section 5).

### V4 - No-obligation tour (pure tour, no waiver) -- READY NOW, LAUNCHES FIRST

**Hook:** remove the money entirely and sell the visit. "Come see it, no pressure, no obligation."
Lowest policy risk, no backend gate, no clickwrap. The `.condition-line` is not required (no $ claim).

Copy tension to resolve: A-lane bans "free tour" phrasing because, next to a fee-waiver, it manufactures
a SECOND "free" claim. V4 has NO fee waiver, so "free" is merely redundant (tours were never priced),
not deceptive. Recommendation: LEAD with "no obligation" / "no pressure" (clean, and the emotionally
valuable part), use "free" sparingly (one asset), and let the wave-0 data say whether "free" or "no
obligation" pulls better. Both provided:

Offer headlines:
- Book a Tour, No Obligation (26)
- Visit Us, No Pressure (21)
- See Our School in Person (24)
- Tour Before You Decide (22)
- Come See the Rooms (18)
- Meet the Teachers First (23)
- Book Your Visit Today (21)
- Book a Free Visit Online (24)  *(the one "free" asset; flagged, drop if policy prefers)*

Offer descriptions (+ SD1 or SD4):
- Book a no-obligation tour of our downtown Sacramento school. See the rooms and meet staff. (89)
- The best way to choose is to walk through it. Book a visit, no pressure, no obligation. (86)
- Tour our sun-filled rooms 5 minutes from the Capitol. Reserve a time that works for you. (88)

**LP:** `/lp/book-a-tour/`, `?offer=tour`. Calendar-first (6b), lifts the `/tour/` booking IIFE +
`.cal-*` CSS by reference. NO waiver flag, NO clickwrap. Note: do NOT point the ad at bare `/tour/` -
it lacks the ad-LP hero/brand framing and the offer-param plumbing; stamp a proper message-matched LP.

### V2 - Back to School (seasonal wrapper)

**Hook:** seasonal enrollment urgency tied to a REAL calendar (August cohort; Toddler 1 opens seats
from August; a new preschool room is under consideration for January). "New school year, new room."
Scope for the first cut: **tour-first, no fee mechanic required** (so it is ready-now like V4), then
optionally carry the winning waiver offer once wave 1 resolves. Because "back to school" is genuinely
seasonal, its urgency is honest by construction as long as it runs in the actual back-to-school window.

Offer headlines:
- Back to School Openings (23)
- Enroll for Fall in Sacramento (29)
- Fall Spots, Book a Tour (23)
- New School Year, New Room (25)
- Start the School Year Here (26)
- Fall Enrollment Is Open (23)
- Tour for the Fall Term (22)
- Now Enrolling for Fall (22)

Offer descriptions (+ SD1 or SD3):
- Now enrolling for the new school year in downtown Sacramento. Book a tour to see it. (84)
- Fall spots are opening for infants through preschool. Visit us 5 minutes from the Capitol. (90)
- Start the school year at a calm, mindful school. Book a tour and meet our teachers. (83)

**LP:** `/lp/back-to-school/`, `?offer=back-to-school`. Calendar-first, or overlay-flow (6a) if scoped
as "check availability" for the season. Run only during the actual Aug/fall window; pause after.

### V6 - Infant openings (PROPOSED audience cut, wave-2 only)

**Hook:** point the winning offer at the room that is actually empty and most expensive to leave empty
(Infant, 10-11 open, top FT rate $2,074/mo; empty seats cost $6.4k-9.4k/week). Highest revenue-per-seat
in the matrix. Not a new offer - the wave-1 winner's mechanic, narrowed to infant searchers.

Offer headlines:
- Infant Openings in Sacramento (29)
- Infant Care From 6 Weeks (24)
- Openings for Infants Now (24)
- 1:3 Infant Ratios, Tour Us (26)
- Tour Our Infant Room (20)
- Infant Spots, Tour and Save (27)

Offer descriptions (+ SD1):
- Infant openings now in downtown Sacramento, with 1:3 ratios. Book a tour to see the room. (89)
- Care from 6 weeks in a calm, sun-filled infant room. Tour us 5 minutes from the Capitol. (88)

**LP:** `/lp/infant-tour/`, `?offer=infant-tour-waiver`. **Slug-collision warning:** a live
`lp/infant-openings/` already exists (an overlay-flow waitlist LP). Do NOT clobber it - use a distinct
`infant-tour` slug for the tour-waiver cut, or fold the offer into the existing LP deliberately (Tier 2).

### V7 - State employees (PROPOSED audience cut, wave-2 only)

**Hook:** the segment that produced the account's first real fee-paid (Flynn, state employee, 7/7).
Priority rates for four nearby state buildings; 5-minute Capitol walk is a commute feature. Point the
winning offer at the state-employee / RTO commuter shed.

Offer headlines:
- State Employee Rates, Sac (25)
- Childcare Near the Capitol (26)
- For State Employees, Downtown (29)
- Tour Near Your Office (21)
- Priority State Rates (20)
- Steps From State Buildings (25)

Offer descriptions (+ SD1):
- Childcare steps from the state buildings downtown. Priority rates for state employees. (86)
- Tour near your office by the Capitol. Mindful care with state employee rates. (77)

**LP:** `/lp/state-tour/`, `?offer=state-tour-waiver`. **Slug-collision + bug warning:** a live
`lp/state-employees/` already exists and carries the "No application fee" self-contradiction bug (D7,
4 instances) that must be fixed in the same push regardless. Use a distinct `state-tour` slug for the
tour-waiver cut to avoid clobbering the live LP and to keep the test isolated.

---

## 5. V3 urgency: the honest rotation design (directive requires this)

"$100+ in fees waived **this week only**" is a policy landmine if it runs evergreen: a deadline that
never arrives is deceptive urgency (Google + FTC + CA BPC 17500). The directive itself flags it. Three
ways to make it honest; recommendation combines A + C.

**A. Default state = NO fake deadline.** V3's steady-state copy drops "this week only" and states the
offer as ongoing-and-conditioned: "$100+ in fees waived when you tour and enroll." The value is real
and needs no manufactured clock. This is what runs 90% of the time.

**B. Rejected: evergreen "this week only."** Never. An always-on "this week" claim is the violation.

**C. Genuine time-boxed FLIGHT, anchored to a REAL deadline, swapped by schedule.** Only when a true
deadline exists - an actual enrollment-cohort close (the August Toddler cohort; the January preschool
room if it opens) or a real limited-slot week - run the urgency creative ("This Week: Tour and Save",
V3 headline) for exactly that window, then rotate it OUT on the stated date via Google ad scheduling
or a scripted swap. The urgency asset is a separate ad (or a scheduled ad) that goes live and dark on
real dates; it is never left running past its stated expiry. Anchor "this week" to something literally
true - **this week's tour slots**, which genuinely refill on the live 45-day calendar feed - rather
than to a fake offer expiry. "Book this week's tour" is true because the slots are literally this week.

**Rotation mechanic:** two ad states in the V3 ad group - `V3-evergreen` (default, always eligible) and
`V3-flight` (urgency, scheduled to a real dated window only). Ad scheduling turns V3-flight on/off on
the true dates; when off, only V3-evergreen serves. No script needed if the deadline is known in
advance (use Ads ad-scheduling); a script is only needed for recurring weekly slot-scarcity framing.
Document the real deadline in the change-log every time V3-flight is armed.

---

## 6. Keyword + negative-wall strategy across variants

The keyword architecture is inherited from B-lane section 1-2 and applied per wave. Key rules:

- **Tour-mechanic variants (V1, V5, V3, V4) share ONE keyword pool** - the 22 tour-intent keywords in
  B-lane section 2 (AG1 Tour Intent 14 + AG2 High-Intent Overlap 8). They do NOT get distinct keywords;
  differentiation is RSA copy + LP, never a second campaign bidding the same terms.
- **When two share a wave (V1 vs V5): one ad group, two RSAs, rotate-evenly.** Both feed off the
  identical query stream, so the read is a clean same-audience framing A/B. This is the most
  sample-efficient structure at this volume. Verify the rotation setting did not revert (the footgun).
- **V4 in its solo probe wave owns the whole tour ad group alone** - maximum clicks to one concept,
  fastest read.
- **V2 Back to School gets its OWN seasonal keyword set** (`fall enrollment daycare sacramento`,
  `back to school daycare`, `august daycare openings sacramento`, `new school year childcare`) in its
  own ad group, negative-cross-blocked against the evergreen tour set so the two do not self-compete.
- **V6 Infant** narrows to infant tour terms (`infant daycare tour sacramento`, `infant care tour`,
  `infant openings sacramento`; `infant care tour sacramento` is already in B-lane AG1). **V7 State**
  narrows to `state employee daycare tour`, `childcare near capitol tour`, `daycare near state buildings`
  (`state employee daycare tour` already in B-lane AG2). Each its own ad group when deployed.
- **The bidirectional negative wall (B-lane section 1.3) applies campaign-wide regardless of which
  variant is live:** the new tour campaign negates Core's exact money terms; Core/Infant/RTO/State
  negate tour-flavored terms. This is the cannibalization guard - it protects the four proven
  never-drop campaigns from the test, and vice-versa. Reuse the "GM Tour-Cannibalization Guard" shared
  list; existing `GM Master Negatives` (109) attaches normally.

---

## 7. Per-variant measurement hooks (how the comparative read works)

The comparative tracking the directive demands (item 4: "OPEN ENROLLMENT tracked independently,
converts comparatively") is bought cheaply by the `?offer=` param already in the front-end contract
(site-lp-conventions 6c). Each variant's distinct `?offer=` value produces a distinct `landing_path`
and a distinct `gmwl_offer_ctx.offer`, giving every variant its own funnel numerator/denominator with
no new plumbing per variant.

- **Denominator per variant:** `gmwl_lp_view` keyed on the offer param (a small client add on the
  gtag-tagged LP; ga4-ads-state section 5 lists this as the one missing per-variant view event). Without
  it, per-variant LP-view -> conversion has no numerator base. Owned by the measurement build lane; this
  lane just declares each variant needs it fired with its offer param.
- **Mid-funnel:** `gmwl_tour_booked` (exists, server MP) + a `gmwl_tour_booked_from_offer` carrying the
  offer param (site-lp-conventions 6c). V4's wave-0 job is to fire these for the first time.
- **Success:** `gmwl_tour_completed` (MISSING today - the T4 / waiver-activation dependency) + the
  B-lane `gmwl_tour_completed_waiver`. Segment by offer param, not by separate conversion actions.
- **Conversion actions: do NOT create per-variant Ads conversion actions.** That fragments an already
  sparse signal. Reuse B-lane's two SECONDARY actions (`gmwl_tour_booked` ~$25, `gmwl_tour_completed_waiver`
  Purchase) and segment in GA4/the Kindred grid by offer param. Protect `gmwl_fee_paid_confirmed`
  PRIMARY $65 as the uncontaminated headline metric. Keep new tour/lifecycle actions SECONDARY until
  volume + a Jarred-gated promotion earns primary, exactly as fee-paid did.
- **Clear the live defect first:** the 3 Local-actions PRIMARY conversions (Directions / Other / Website
  visits, auto-created by GBP) are polluting the Conversions column (ga4-ads-state section 3). Demote
  them to SECONDARY before importing any tour/lifecycle conversion, or the comparative read is dirty
  from day one.

---

## 8. Isolation + hard-rule checklist (verify before every Tier-2 gate)

- **Per-variant isolation grep** (the pre-deploy check must now cover ALL live slugs, not one):
  `grep -rn 'open-enrollment\|waitlist-fee-waived\|fees-waived\|book-a-tour\|back-to-school\|infant-tour\|state-tour'`
  returns only each LP's own dir + `_redirects`/`_headers`. Zero nav/footer/homepage/sitemap links.
  Each LP: `noindex, follow` + self-canonical, absent from sitemap.xml, ad-click-only entry, waiver flag
  only via `?offer=`.
- **Slug collisions:** `lp/infant-openings/` and `lp/state-employees/` are LIVE. V6/V7 use `infant-tour`
  / `state-tour` slugs to avoid clobbering them.
- **No em dashes** anywhere (verified: 0 in this doc's copy). **No new licensing text** (existing CDSS
  footer badge stays; add nothing). **Every "$ waived" asset carries its condition in the same string**
  (verified per variant above; the 2 near-bare assets are flagged for drop).
- **`.condition-line` REQUIRED** on V1/V3/V5 LPs (states the $ once + the condition; Google Dishonest-
  Pricing policy requires the full price at the destination).
- **clickwrap v2 (`waitlist-v2.ts`, counsel, SHA-256 bump)** must land before ANY fee-deferring variant
  (V1/V3/V5/V6/V7) goes live. V4 and tour-only V2 do not need it.
- Reuse `/tour/` calendar + overlay.js by reference; never fork the widget.

---

## 9. Brainstorm - further improvements on the whole concept (directive item 8)

1. **Sequence, do not parallelize - this IS the biggest improvement.** The directive's implicit
   "launch V1-V5" would split 40-60 weekly clicks five ways and learn nothing. The pipeline in section 2
   is the single highest-leverage change to the plan.
2. **Decouple the "OPEN ENROLLMENT!" brand from the $65 mechanic.** Let it become an umbrella that wraps
   whichever offer wins, so the brand equity compounds across waves instead of being welded to one price.
3. **Vary AUDIENCE after a hook wins, not many hooks at once.** V6/V7 (infant, state-employee) are the
   right second move: same proven creative, aimed at the emptiest/highest-value seat and the
   proven-converting segment. This chases revenue-per-seat, not novelty.
4. **Build the T-24h / T-2h tour reminder cadence BEFORE scaling any waiver variant.** It does not exist
   today (E-measurement section 5). No-show is the failure mode that kills waiver economics - a "free
   perk with no cost to skip" invites it. Reminders are cheap insurance the waiver test depends on.
5. **Keep the existing fee-exit winback popup as the in-flow safety net.** It already fires
   (`gmwl_fee_exit_winback_*`) and already offers a tour on fee abandon. Every variant's non-converters
   fall into it, so even a "losing" ad still routes intent to the tour. Fold this into the wave read.
6. **The standard Core flow is the implicit control** for the "does tour-first beat apply-then-pay"
   question. Track waiver-LP fee-paids vs Core fee-paids over the same window (cannibalization guardrail,
   E-measurement section 4) so a "win" is net-new conversions, not moved ones.
7. **Light, testable pin on the dollar variants only.** B-lane recommends pin-nothing account-wide, and
   that stands - but for V5/V3 the dollar IS the whole message, so pinning ONE conditioned offer headline
   to position 1 guarantees the promise always shows and matches the LP hero. Propose it as an A/B within
   the variant, not a default. Flagged, not committed.
8. **Re-evaluate the Promotion asset now that dollars are allowed.** A-lane advised against it only
   because it forced a dollar figure; that objection weakens post-supersession. A "Money off / special
   offer" Promotion asset ("$65 waitlist fee waived when you tour") is now a candidate for V5/V3 - still
   Tier-2 parent-facing gated + platform policy review, but worth a look for the dollar variants.

---

## 10. Open items this lane flags to other lanes / Jarred

- **Budget:** V1-V5-plus is materially more than the single $12/day test B-lane sized; D2's "+$6-8/day"
  no longer covers a multi-wave pipeline. The pipeline mitigates this (max 2 live at once caps concurrent
  spend), but wave-2 audience cuts + a seasonal flight need their own budget line. Jarred decision.
- **$45 automation gates V3 and the T3/T4 lifecycle emails** (enrollfee-noshow ground doc) - resolve
  before any $45-touching creative runs; interim is $65-only.
- **clickwrap v2** blocks every fee-deferring variant - counsel + SHA-256 bump (D4).
- **The 2 near-bare dollar assets** ("Skip the $65 Waitlist Fee", "$100+ in Fees Waived") - policy lane
  confirms keep-or-drop given LP disclosure carries the condition.
- **"free" in V4** ("Book a Free Visit Online") - copy/policy lane confirms keep-for-test or reword.
- **Slug collisions** (V6/V7 vs live `lp/infant-openings`, `lp/state-employees`) + the live
  `/state-employees/` "No application fee" bug (D7) - site lane fixes in the same push.
- **Local-actions conversion pollution** must be demoted before importing tour/lifecycle conversions.
