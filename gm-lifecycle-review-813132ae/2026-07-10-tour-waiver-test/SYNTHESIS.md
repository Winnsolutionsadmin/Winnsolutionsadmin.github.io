# SYNTHESIS: Tour-Waiver Test Decision Brief (2026-07-10)

Five parallel lanes (policy, campaign, LP, waitlist-flow, measurement) built from one context
pack. All deliverables in this directory. This file is the single read for go/no-go.

## Verdict
Test A ($65 waitlist fee waived on tour completion) is BUILDABLE and COMPLIANT WITH CONDITIONS.
Test B ($45 same-day-enroll waiver) is designed but PARKED as Phase 2 (no standalone $45 charge
exists in code today; Brightwheel handoff design done; not ready for paid media).

## The stack (all four pieces ship together or the ads violate "unavailable offers")
1. Backend (gm-waitlist): tour_waivers side table (migration 050; the applications table is at
   99/100 D1 columns, closed - side table is the design), status=pending_tour, Ashley
   marks-attended in Kindred -> waived+activated; 3-day expiry -> pay-or-rebook email; 14-day
   forfeit. Effort: several S/M pieces.
2. Clickwrap waitlist-v2.ts: v1's "non-refundable regardless" language contradicts a conditional
   fee. Counsel-review + SHA-256 version bump REQUIRED before launch.
3. LP /lp/tour-offer/: spec + brand-matched mockup done (lp-tour-offer-mockup.html). noindex,
   dark-launch pattern like /tour/. Every waiver claim carries its condition in-sentence.
   Front-end contract: ?offer=tour-waiver + sessionStorage bundle mirroring the attribution pattern.
4. Campaign "Search - Tour Offer | Fee Waiver Test": 2 ad groups / 22 kws, bidirectional negative
   wall vs Core/Infant/RTO/State, Max Clicks $8.50 ceiling, RSA deck drafted (condition in ad
   copy per policy), conversion actions gmwl_tour_booked + gmwl_tour_completed_waiver BOTH
   secondary. No Promotion asset (renders a dollar figure). Launch at 7/16 batch.

## Measurement (pre-registered)
Primary: tour-completed rate per LP session. Decision at 100 LP sessions or 6 weeks:
scale if 8+ completed tours AND (1 enrollment OR 3+ fee-paids); tighten if completion <50%;
kill under 3 bookings. Cannibalization guardrail: weekly non-waiver fee-paid watch.
Worst-case total test cost ~$1.9k = ~1.3 months of ONE enrollment. Enrollment-level
significance impossible in 30 days; the bar is deliberately practical.

## Lane conflict, resolved with recommendation
C-lane recommends omitting the literal $65 from the LP fine print; A-lane (policy) says Google
Dishonest Pricing Practices requires actual price disclosure at the destination. RECOMMENDATION:
policy wins - state the $65 once in the condition fine-print block on the LP (never in ads).
Jarred may overrule.

## Jarred decision list (nothing executes without these)
D1. GO/NO-GO on building the Test A stack.
D2. Budget: +$6-8/day explicit raise ($115->$121 enabled) vs stacked trims. Lanes recommend raise.
D3. Queue fairness: pending_tour applications take position at ACTIVATION (recommended,
    protects paying families) vs submission.
D4. Clickwrap v2 language approval (Tier 2, counsel pass).
D5. LP fine print states $65 once (policy recommendation) - approve or overrule.
D6. Expiry constants: 3-day tour window, 14-day forfeit - approve or adjust.
D7. /state-employees/ "no application fee" fix (4 instances) ships in the same push - approve copy.
D8. Launch timing: 7/16 batch (recommended) vs freeze waiver now.
D9. Test B: confirm parked as Phase 2.

## Build order once approved
Phase 1 (can start immediately, sandbox): gm-waitlist migration+endpoints+cron+GA4 events;
clickwrap v2 draft to counsel; LP built dark on preview; /state-employees/ fix staged.
Phase 2 (needs Ads login, blocked on lpass): staged campaign build via Scripts slot; verify
conversion imports; launch 7/16 with the review batch.
Phase 3 (later): Test B build + Brightwheel Bw*-gated billing handoff.

## ISOLATION MANDATE (Jarred, 2026-07-11, non-negotiable)
This is a conversion TEST. The LP and campaign must be fully isolated so the read is clean:
- /lp/tour-offer/ carries meta robots noindex,nofollow AND X-Robots-Tag noindex via _headers.
- ZERO internal links from any page on www.growingmindfully.org (no nav, no footer, no sitemap,
  no cross-links from /tour/ or any LP). Verify with a full-site grep for "tour-offer" before
  every deploy: the ONLY inbound path is the ad click.
- Excluded from sitemap.xml; canonical self-referencing; not submitted to IndexNow.
- The waiver flag activates ONLY via the ?offer=tour-waiver param arriving on THIS page: organic
  visitors to the main site or /tour/ never see or receive the offer.
- Campaign side: the bidirectional negative wall (already designed) plus dedicated UTM
  (utm_campaign=tour-waiver-test) so every session in the cohort is ad-attributed.
- Add a pre-deploy checklist line to the LP lane build: "grep -r 'tour-offer' across the site
  returns only the LP directory itself and _redirects/_headers entries."

## DECISIONS RENDERED (Jarred, 2026-07-11, in-chat)
- D1 GO. D2 GO (+$6-8/day raise, $115->$121 enabled). D3 "ignore" = proceed with recommendation (position at ACTIVATION). D4 "ignore" = NO clickwrap v2 counsel pass; launch on existing v1 (owner accepts the conditional-fee/non-refundable tension; flagged once, closed).
- D5 OMIT: the LP fine print does NOT state the $65 figure (owner overrules the policy lane's price-disclosure recommendation). No dollar figures on the LP at all.
- D6 AMENDED (owner verbatim): "They can book their tour within 2 weeks. The $65 waitlist fee for that campaign is waived day of. If they do a tour, they can waive the $45 enrollment fee if they secure their space same day." => 14-day window to book AND complete the tour (the 3-day sub-window is DEAD); forfeit at 14 days; $65 waived day-of-tour (activation on attendance, as designed); NEW: $45 enrollment fee waived when the family reserves the SAME DAY as their tour.
- D7 DONE 2026-07-11 (fee copy shipped site-wide, 5 pages, live).
- D8 GO for 7/16 batch, with a mandatory DESIGN QA gate on the LP (hero image, text, symmetry checks) + preview links to Jarred before launch.
- D9 GO: Test B stays parked as Phase 2.
- Same session: winback ARMED in prod (existing families excluded); Yelp BBB permanently held; ppcanalytics3 removed; 3 legacy click actions verified already REMOVED (7/3); Misconfigured goal flags ACCEPTED as cosmetic (item closed).

## PHASE 1 BUILT (2026-07-11, both branches pushed, NOT merged/deployed - gated for 7/16 batch)
- BACKEND (gm-waitlist): branch tour-waiver-backend-0711 tip f6c87cca. Migration 051_tour_waivers side table; src/server/tour-waiver.ts (intake eligibility, $65 waive-on-attendance, $45 same-day-reserve waiver LA-tz gated, day-10 reminder + day-14 forfeit crons); new POST /api/crm/families/:key/tour-attended (bearer). Waived = fee_paid 0 (no fake Stripe). Position at activation (D3). Excluded from archive/winback/campaign double-ask. TOUR_WAIVER_ENABLED=1 sandbox / 0 prod (dark). Tests 492 pass / 0 fail.
- LP (growingmindfully): branch worktree-agent-a9f5c147ecad4ff85 tip f62182ed. /lp/tour-offer/ noindex+isolated, no dollar figures, D6 copy, design QA passed. LICENSING VIOLATION CAUGHT+FIXED (hero chip + footer "Licensed by California CDSS" removed - net-new licensing on ad infra).
- Two backend judgment calls flagged: (1) marking attended on an already-forfeited row un-forfeits it (human wins); (2) verify-email flow suppresses the "$65 paid" receipt for the waived cohort (no charge occurred).
- REMAINING before 7/16 launch: campaign build via Ads Scripts (login ready), gmwl_tour_booked wiring on /tour/, then gated merge+deploy of both branches together.

## BACKEND REVISION (2026-07-11, Jarred 2 changes) - branch tour-waiver-backend-0711 tip 35c30218, 491 pass/0 fail
- CHANGE 1: waived fee set fee_paid=1 (was 0) "so it doesn't break anything else later"; tour_waivers.status='waived' stays source-of-truth that $0 was collected; isFeeWaived() distinguishes everywhere.
- CHANGE 2: tours ASSUMED ATTENDED - offer=tour-waiver activates immediately at intake (waiting + fee_paid=1 waived, tour_completed_at=intake). The 14-day forfeit + day-10 reminder crons were dropped. No-show is the exception: POST /api/crm/families/:key/tour-no-show (un-waive + forfeit + pay-to-reactivate); tour-attended reverses a no-show. Both idempotent.
- fee_paid=1 AUDIT caught + fixed 2 real leaks: (1) conversions.csv would have uploaded a FAKE $65 offline conversion to Google Ads -> now anti-joined on status='waived'; (2) /verify would have emailed a "$65 paid" receipt to a $0 waived family -> now gated fee_paid=1 AND NOT isFeeWaived. GA4 gmwl_fee_paid_confirmed never fires for waived (test-asserted). Stripe reconcile inherently safe (PI-first). No revenue $-sum inflation (funnel uses counts not $65*fee_paid).
- D6 judgment call: "tour day" for the same-LA-day $45 waiver = intake day (attendance assumed), overridable by a real completed_at; LA-midnight boundary unit-tested.
- REMAINING before 7/16 launch: ad-campaign build (Ads Scripts, its own separate campaign) + gmwl_tour_booked wiring on /tour/ + gated merge/deploy of both branches together.
