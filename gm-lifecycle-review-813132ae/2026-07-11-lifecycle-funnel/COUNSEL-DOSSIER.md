# COUNSEL DOSSIER: GM Lifecycle Funnel + Ad Variant Matrix (2026-07-11)

For an external multi-model panel. Score each numbered PROPOSAL from -100 (this will actively hurt
the business) to +100 (clearly right, do it). No em dashes below. Full detail: MASTER-PLAN.md.

## Business context (15 lines)

1. Growing Mindfully is a mindfulness-based infant-through-preschool in downtown Sacramento (750 N St).
2. Acquisition = Google Ads into a static site + an onsite waitlist worker (Cloudflare D1).
3. Empty seats cost $6,400-9,400 PER WEEK. Infant is emptiest; Toddler full til Aug; Preschool 6-9 open.
4. Paid volume is THIN: 43-58 clicks per WEEK account-wide, ~$10-11 CPC, rank/impression-limited.
5. First real paid fee-paid conversion landed 7/7 (a state employee). 12 fee-paid families already wait.
6. A tour-waiver test is BUILT and gated for a 7/16 launch: waive the $65 waitlist fee on tour completion.
7. This directive wraps that into a full lifecycle funnel: automated emails T1-T4, an ad matrix V1-V7,
   a per-family x per-campaign engagement grid in the admin, and full tour-booking instrumentation.
8. Almost all transport/template/tracking substrate ALREADY EXISTS and is reused, not rebuilt.
9. Owner governance is HOOTL (Human Out Of The Loop): autonomous by default, evidence at act time, ONE
   weekly update + ONE batched inquiry; hard gates only for money, parent-facing copy, clickwrap, deploys.
10. The $45 enrollment fee is bundled in the deposit; waiving it for the GENERAL audience needs a code
    choke point that is not built yet (the tour-waiver-cohort $45 path IS built).
11. Owner already rendered D1-D9: launch on existing clickwrap (no counsel bump), NO dollar figures on
    landing pages (ad copy may carry them), 14-day tour window, same-day $45 waiver, 7/16 GO.
12. Tours have NEVER been booked through the funnel, so the tour conversion events have never fired.
13. Rate card FT $1,436-$2,074/mo; the LTV asymmetry makes the test's decision bar deliberately low.
14. Brand voice is calm/mindful; high-pressure tactics sit in tension with it and must stay honest.
15. Hard rules: no em dashes, nothing licensing-related in ads/site/emails, additive-only schema.

## The plan (40 lines)

16. Data layer: reuse `campaign_sends` (open/click), `emails`, `funnel_events`, `tour_bookings`; add 6
    additive side tables (migrations 052+, since 050/051 are taken on disk).
17. New tables: tour_waivers, lifecycle_sends (idempotency), tour_outcomes (attendance), campaign_events
    (per-event log), offer_variants (the ?offer= registry), enroll_fee_waivers (one $45 state/family).
18. `applications` is at 99/100 D1 columns and CLOSED; all new state is side-tabled.
19. Three fee-settled cohorts the logic must separate: standard (paid $65), table_day (on-site $65 waiver
    via fee_grandfathered_at), open_enrollment (tour-waiver $65). "Fee settled" = fee_paid OR grandfathered.
20. Lifecycle engine derives state each 10-min cron tick from timestamps + lifecycle_sends rows; no new
    cron trigger (account at the 5-cron limit), a gated leg on the existing */10 tick.
21. T1 "Reserve Your Space" fires 24h after fee-settled with no tour (two cohort variants A + B).
22. T2 is a PLAIN book-a-tour exit-intent popup on the reserve page (no $45, no offer code).
23. T3 "book a tour, waive the $45" fires +24h after T1 if still no tour; routes to /tour/ with the waiver.
24. T4 fires 1h after a tour ends (unless no-show), promises the $45 waived if they reserve same-day.
25. Suppression: reserved/toured/unsubscribed gates + max 3 timed emails/family + quiet hours 8pm-8am PT.
26. $45 precedence: one waiver state per family, first-writer-wins, one same-day deadline (D6 dissolves
    the old contradictory deadlines).
27. Ad matrix is a PIPELINE, not a parallel launch: max 2 concepts live at once, 2-3 week waves.
28. Wave 0: V4 pure no-obligation tour, SOLO (zero backend gate; cold-starts the tour events for everything).
29. Wave 1: V1 "OPEN ENROLLMENT" vs V5 "$65 waived" concurrent (same $65 mechanic, brand vs dollar framing).
30. Wave 2: scale the winner via V2 seasonal / V6 Infant / V7 State audience cuts; V3 last, only if $45 ready.
31. V3 "$100+ / up to $110" stays HOLD from the first batch (needs the general $45 choke point + rotation).
32. LP factory: one uniform template, per-variant slot stamps; noindex + zero internal links + ad-click-only.
33. ONE canonical slug/offer registry (a prior inconsistency between two design lanes); WAIVER_OFFER_CODES
    allowlist gates which codes actually waive; unknown codes charge the standard fee.
34. Per D5, LP condition language is dollar-free; ad RSAs keep their figures for sanctioned variants.
35. GA4: add gmwl_lp_view (per-variant denominator), star gmwl_tour_booked / gmwl_tour_completed after V4
    fires them; segment by offer param, do NOT create per-variant conversion actions.
36. Measurement reads per-wave, decision at 2 weeks OR 100 sessions; SCALE/ITERATE/KILL thresholds; a
    weekly cannibalization guardrail; the Kindred grid is the closed-loop audit surface.
37. Compliance: every "$ waived" ad asset conditions in the same string; "free tour" banned house-wide;
    editorial scrub (no all-caps/"!"); CAN-SPAM already wired for the marketing emails.
38. Clickwrap: owner chose to launch on the existing v1/v3 (no counsel bump); residual risk noted.
39. Everything ships DARK behind kill-switch env flags; parent-facing sends ride a mandatory design-QA gate.
40. Real build gate remaining for the general $45: the enrollmentFeeDue choke point across 7 deposit sites.

## PROPOSALS (score each -100..+100)

P1. WAVE SEQUENCING. Run the ad matrix as a pipeline (max 2 concepts live, 2-3 week waves) instead of
launching V1-V5 in parallel, because 43-58 clicks/week split five ways learns nothing about any variant.

P2. V4-FIRST COLD-START. Launch V4 (pure no-obligation tour, zero backend gate) SOLO as wave 0 to prove
tour-ad demand and fire the tour conversion events for the first time, before any waiver plumbing runs.

P3. V3 HOLD vs FIX-NOW. Keep the "$100+ / stacked $65+$45" variant OUT of the first batch until the
general $45 choke point and an honest urgency rotation exist; interim descope to $65-only or cut.

P4. EMAIL CADENCE/COUNT. Cap the lifecycle journey at 3 timed emails/family ever (T1 nurture, T3 tour
nudge, T4 post-tour) plus the T2 popup, with a ~2 marketing-emails/family/week ceiling across all legs.

P5. SAME-DAY $45 DEADLINE MECHANICS. Interpret D6's "reserve same day as the tour" as end of the tour's
calendar day (11:59 PM PT) rather than a 5:00 PM PT cutoff, to keep afternoon-tour offers honest (T4
fires ~4:30 PM for a 3 PM tour, so a 5 PM cutoff is a ~30-minute dark pattern).

P6. $45 PRECEDENCE RULE. Enforce one $45-waiver state per family, first-writer-wins, with all triggers
(T3/T4/V3) sharing ONE same-day deadline that later triggers restate but never overwrite or shorten.

P7. GRID SCOPE. Render acquisition cohort as a row-attribute + a comparative card rather than as literal
grid columns, since a family "receives" campaigns but does not "receive" its own acquisition source.

P8. T1 24-HOUR WINDOW. Read the directive's "within 24h" as a 24h nurture DELAY (fire at fee-settled +24h,
giving a self-serve window) rather than "send promptly / immediately."

P9. OPEN ENROLLMENT COHORT TRIGGER MAPPING. Catch the fee-waived OPEN ENROLLMENT cohort with a dedicated
T1 Variant B (predicate waiver_state='waived') instead of the literal fee_paid=1 trigger that would skip
them, and add the table_day fee_grandfathered cohort to the T1/T3 audience OR-predicate.

P10. HOOTL COMPLIANCE. Ship the whole system autonomous-by-default with kill-switch env flags, act-time
evidence rows, self-heal to an ops channel, and exactly one weekly scorecard + one batched inquiry to the
owner, with hard human gates only on money / parent-facing copy / deploys.

P11. CLICKWRAP-AS-IS (owner-rendered, scored for outside sanity-check). Launch the fee-deferring waiver
variants on the existing clickwrap (which describes the fee as non-refundable) with NO counsel-reviewed
version bump, accepting that a waived family signs terms describing a fee they were not charged.

P12. NO-SHOW DEFAULT. Treat an UNMARKED tour as attended so T4 sends (Ashley's mark only SUPPRESSES a
known no-show), rather than holding T4 until a positive attended-mark is entered.
