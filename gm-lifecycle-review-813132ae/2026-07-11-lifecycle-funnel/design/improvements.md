# DESIGN: Brainstorm - Ways to Improve the Lifecycle Funnel Concept (2026-07-11)

Lane: "what other ways can we improve upon this concept?" 15 concrete improvements, ranked by
leverage/effort. Grounded in the live system (ground/ briefs + CLAUDE.md capacity facts). No em
dashes. Nothing here executes; every parent-facing, budget, waitlist-mutation, or clickwrap item is
Tier 2 (Jarred-gated). This is idea supply for the design lanes, not a build order.

## Economic anchors that set "leverage" (from CONTEXT-PACK2 + grounds)
- Empty seats cost $6,400-9,400 PER WEEK. Infant is emptiest (10-11 open). Toddler is FULL until
  August. Preschool 6-9 open plus a Feb 2027 wave. FT LTV $1,436-2,074/mo.
- Paid volume is thin: 43-58 clicks/WEEK account-wide. Anything that depends on retargeting-scale
  audiences is premature; anything that squeezes more value per existing click/tour is high leverage.
- Tour COMPLETION rate is the true-north metric of the whole waiver concept, and no-show is named the
  single biggest execution risk. Tour reminders (T-24h/T-2h) DO NOT EXIST today.
- 12 fee-paid families are already waiting: a warm, owned, zero-CAC asset the acquisition-only design
  never mines.

## Ranked summary (leverage / effort)

| # | Improvement | Leverage | Effort | Gated? |
|---|---|---|---|---|
| 1 | Capacity-aware budget steering (stop paying for full Toddler) | Very high | M | Budget (T2) |
| 2 | Tour show-rate optimizers (T-24h/T-2h reminder + .ics calendar invite) | Very high | S-M | Parent copy (T2) |
| 3 | On-tour / same-day reserve escalator + Ashley close playbook | High | S-M | Parent copy (T2) |
| 4 | Post-tour review-generation loop (GBP reviews) | High | S | Parent copy (T2) |
| 5 | Live-capacity honest scarcity on LPs (real seats from forecast feed) | High | M | none (data read) |
| 6 | Referral incentive for the 12 waiting fee-paid families | High | M | Brightwheel credit (T2) |
| 7 | GBP offer posts + Local-actions conversion cleanup | Med-high | S | none |
| 8 | Seasonal offer-rotation engine (satisfies the "this week only" expiry need) | Med-high | M | Budget/copy (T2) |
| 9 | No-show rebook path (recover the expired->forfeited dead window) | Med | S-M | Parent copy (T2) |
| 10 | Waitlist-position transparency as a conversion/retention lever | Med-high | L | Position compute |
| 11 | SMS lifecycle layer (TCPA-consented) for T2/tour reminders | High ceiling | L | TCPA + transport (T2) |
| 12 | Cold-click warm-up lead magnet ("A Day in the Life" / tour-prep) | Med | M | Parent copy (T2) |
| 13 | Abandoned-calendar-view recovery nudge | Med | M | Parent copy (T2) |
| 14 | Owned-audience re-marketing wave (lapsed / aging-up / sibling) | Med | M | Parent copy (T2) |
| 15 | RLSA/retargeting lists from LP visitors | Low NOW (volume) | M | Park until volume |

---

## 1. Capacity-aware budget steering  (leverage: very high, effort: M)
Toddler is full until August, yet the account can still serve and pay for toddler/generic-daycare
clicks. Every full-room click is pure waste against a $6.4-9.4k/week empty-seat cost that is entirely
Infant/Preschool. Build a weekly (or nightly) job that reads the Solace forecast feed
(`projected_demand` per band, never memory) and (a) shifts budget toward the emptiest band, (b) auto
pauses or negative-keywords a band's ad group when it crosses ~95% projected, (c) re-enables when a
transition frees a seat. Start as a Jarred-gated weekly reallocation playbook (effort S), graduate to
automated pause/enable (effort M). Dependency: Solace forecast read (already used elsewhere), Ads
change-log discipline, never-drop rule (pause/negative, do not delete).

## 2. Tour show-rate optimizers  (leverage: very high, effort: S-M)
The entire waiver economics (and T4) hinge on tours actually happening, and reminders do not exist. A
booked-but-no-show tour costs a click, a waived fee expectation, and Ashley's blocked time. Add two
automated pre-tour touches on the existing */10 cron leg (no new cron trigger; account is at the
5-trigger cap): T-24h and T-2h reminder emails, plus a real .ics calendar invite attached at booking
(a calendar hold is the strongest no-show reducer known). America/Los_Angeles timing. This is exactly
the "TIGHTEN" action E-lane pre-registered for completion <50%; ship it proactively rather than after
a bad read. Dependency: `tour_bookings.slot_end` (already stored), sendEmail chokepoint, parent-copy
Tier 2.

## 3. On-tour / same-day reserve escalator + Ashley close playbook  (leverage: high, effort: S-M)
T4 already emails "reserve by 5PM today," but the warmest moment is the parent standing in the room.
Give Ashley a one-page tour-conversion playbook plus a same-day reserve handoff: a short unique
reserve link/QR she hands or texts at tour end that lands directly on the family's prefilled reserve
step, with the enrollment-fee-waiver context already attached. Converts intent while it peaks instead
of waiting for an email that competes with the drive home. Escalator idea: waiver honored only if
reserved within 24-48h of tour, reinforcing the T4 urgency truthfully. Dependency: reserve deep-link
with `?sdo=` prefill (exists), the tour-completion mark (design 1b), parent-copy Tier 2.

## 4. Post-tour review-generation loop  (leverage: high, effort: S)
On a low-volume paid account, organic trust compounds harder than one more click. Add a post-tour
(and post-enroll) ask that routes happy families to a Google review, feeding GBP, which lifts both
organic Maps and the Local-actions surface. One templated email/text 1-2 days after a completed tour,
suppression-aware, never incentivized (review-for-pay violates Google policy). Highest ROI trust asset
per dollar in the whole plan. Dependency: tour-completion signal (design 1b) as the trigger, GBP
review link, CAN-SPAM footer, parent-copy Tier 2. Note: keep this separate from any offer so it is
never a "review in exchange for" claim.

## 5. Live-capacity honest scarcity on LPs  (leverage: high, effort: M)
The LP variants can state real, current openings pulled from the forecast feed ("Infant: a few spaces
for August") instead of generic urgency. Honest scarcity is both a strong conversion lever AND the
compliant alternative to evergreen "this week only" claims (which CONTEXT-PACK2 flags as a policy
risk). Because it is truthful and self-updating, it sidesteps the expiry/rotation burden entirely for
the scarcity angle. Render server-side or via the existing availability widget
(`gm-availability.js`), band-specific per LP variant. Dependency: forecast feed read (no schema
change), copy discipline (numbers must be true at render, refresh cadence defined), Tier 2 copy.

## 6. Referral incentive for the 12 waiting fee-paid families  (leverage: high, effort: M)
Twelve families have already paid the fee and are emotionally invested but not enrolled. A referral
ask ("bring a friend to the waitlist") is the cheapest acquisition channel available and doubles as a
retention/engagement touch for a segment the funnel currently lets sit idle. Reward via a
future-dated Brightwheel tuition credit (money op = Bw* skills, dry-run -> confirm -> execute ->
verify) or a fee waiver for the referred family, tracked with a per-family referral code so it flows
into the campaign grid. Dependency: referral code plumbing, Brightwheel credit path (Tier 2, gated),
CAN-SPAM, and a fraud guard (one reward per real enrolled referral).

## 7. GBP offer posts + Local-actions conversion cleanup  (leverage: med-high, effort: S)
Two cheap wins bundled. (a) Publish the "OPEN ENROLLMENT!" and seasonal offers as Google Business
Profile posts so the free organic surface mirrors the paid message (zero incremental CAC). (b) Clear
the live measurement defect first: 3 auto-created Local-actions PRIMARY conversions (Directions/Other/
Website visits) are polluting the Conversions column and will corrupt any Max-Conversions switch.
Demoting them to SECONDARY makes every downstream read in this plan (V1-V5 comparison, tour_booked
import) trustworthy. Dependency: GBP access (2FA relay), the already-pending Jarred demote approval.

## 8. Seasonal offer-rotation engine  (leverage: med-high, effort: M)
CONTEXT-PACK2 requires "this week only" claims to actually expire and rotate or they become a policy
risk. Turn that obligation into an asset: a small offer-calendar registry (JSON of offer_code ->
{headline, start, end, LP variant}) that drives ad scheduling and LP copy, so V2 "Back to School" ->
Fall -> New Year waves swap automatically on real dates. Each rotation gets its own `?offer=` code and
`landing_path`, so the comparative V1-V5 read the directive wants comes for free. Prevents evergreen
false-urgency by construction. Dependency: the `offer_variants` registry (flagged in d1-schema
ground), ad-schedule or scripted swaps, Tier 2 copy/budget.

## 9. No-show rebook path  (leverage: med, effort: S-M)
The waiver state machine sends a pay-or-rebook email at expiry (N=3d) then forfeits at M=11d, but that
window is otherwise dead air. Make it an active recovery: a one-tap rebook link in the expiry email
that re-books a tour and re-arms the waiver (one re-arm max, abuse-guarded), plus surfacing no-shows
on Ashley's Kindred task list so she can personally text a reschedule. Recovers tours already paid for
with a click. Dependency: no-show mark (design 1b/enrollfee-noshow Path 1 migration 050), tour rebook
deep-link, one-re-arm guard on `tour_waivers`, parent-copy Tier 2.

## 10. Waitlist-position transparency  (leverage: med-high, effort: L)
Position is not computed today but CLAUDE.md marks it as unblocked future work now that our system is
the sole record. Showing a family "you are #3 for Infant, est. August" is a documented conversion AND
retention lever: it makes the intangible waitlist concrete, justifies the fee, and reduces silent
churn. Could also power a "move up the list by completing a tour" mechanic that ties directly into the
tour funnel. Effort is L because it needs a real, defensible position algorithm (activation-time
ordering per D3) and careful copy (never over-promise a date). Dependency: position compute engine,
forecast feed, Tier 2 copy, legal care on estimates.

## 11. SMS lifecycle layer  (leverage: high ceiling, effort: L)
SMS open/response rates dwarf email, and the highest-value touches here are time-sensitive (T-2h tour
reminder, T2 reserve-exit, T4 same-day 5PM offer) where SMS wins most. But it is the heaviest lift:
new transport (Twilio/httpx), TCPA prior-express-written-consent capture at fee/reserve, STOP/HELP
handling, quiet-hours, and a suppression store parallel to email_suppressions. Recommend scoping it to
transactional/expected messages first (tour reminders the family opted into by booking), where consent
is cleanest, before any promotional SMS. Dependency: consent capture + clickwrap update (Tier 2
counsel), SMS provider, new suppression plumbing, LA-timezone quiet hours.

## 12. Cold-click warm-up lead magnet  (leverage: med, effort: M)
Some ad clicks are not ready to book a tour on first visit. A low-friction lead magnet ("A Day in the
Life at Growing Mindfully" gallery/video, or a tour-prep one-pager) captures the email at a lower
commitment than a tour, then feeds them INTO the T1-T4 sequence. Turns a bounce into a nurturable
lead, improving yield on the thin 43-58 clicks/week. Must stay on the noindex/isolated LP posture per
variant and route captured emails through suppression/consent gating. Dependency: a capture form on
the LP template, lead -> lifecycle enrollment, CAN-SPAM/consent, Tier 2 copy.

## 13. Abandoned-calendar-view recovery nudge  (leverage: med, effort: M)
Today the funnel tracks tour BOOKED but nothing recovers a parent who opened the calendar and left
without picking a slot (a high-intent drop-off). Fire a lightweight event on calendar-view-without-book
(the reserve leg already has `gmwl_calendar_viewed`/`gmwl_calendar_empty` beacons to model it on),
and if an email is known, send a short "still want to visit? here are this week's times" nudge. Mirrors
the existing fee-exit winback pattern one stage earlier. Dependency: a view-without-book signal on
`/tour/`, known-email match, the */10 cron leg, parent-copy Tier 2.

## 14. Owned-audience re-marketing wave  (leverage: med, effort: M)
Beyond the 12 waiting families, there are lapsed leads, families aging up between bands (Infant ->
Toddler as they turn), and enrolled families with younger siblings (the sibling-order policy already
exists in priorities.ts). A periodic, segmented re-marketing wave via the campaigns.ts engine (which
already has open/click tracking, unlike the winback path) re-touches these zero-CAC segments with the
right band offer at the right life-stage. Dependency: segment queries over leads/applications,
campaigns.ts engine armed (CAMPAIGNS_ENABLED), suppression + CAN-SPAM, Tier 2 copy.

## 15. RLSA / retargeting lists from LP visitors  (leverage: low NOW, effort: M)
Building remarketing audiences from V1-V5 LP visitors is standard practice and cheap to set up, but at
43-58 clicks/week the lists will not reach Google's ~1,000-user serving threshold for a long time, so
the payoff is deferred. Recommendation: START COLLECTING the audiences now (so the clock runs) via the
existing gtag on every LP, but do NOT budget for retargeting delivery until volume supports it. Parked,
not dropped. Dependency: GA4/Ads audience definitions on the tagged LPs, volume trigger before spend.

---

## Cross-cutting notes for the design lanes
- Highest-leverage cluster is TOUR EXECUTION (#2, #3, #4, #9): the concept already spends to book
  tours; the cheapest wins are making booked tours happen, convert, and generate reviews. These
  protect the metric the whole waiver test is judged on.
- Highest-leverage MEASUREMENT/SPEND win is #1 (stop paying for full Toddler) + #7b (Local-actions
  cleanup): together they stop wasting budget AND stop corrupting the numbers used to judge V1-V5.
- Two items double as COMPLIANCE de-riskers: #5 (live honest scarcity) is the truthful substitute for
  evergreen "this week only," and #3's 24-48h waiver window makes T4 urgency real instead of arbitrary.
- Everything promotional (T1-T4, #4, #6, #9, #12, #13, #14) shares one new surface: CAN-SPAM
  (unsubscribe + physical address + suppression) and quiet-window overlap with the existing 72h
  winback rule. Design that once, centrally, not per-feature.
