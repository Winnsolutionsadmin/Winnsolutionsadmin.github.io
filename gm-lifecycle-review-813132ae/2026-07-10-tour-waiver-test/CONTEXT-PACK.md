# CONTEXT PACK - Tour-Waiver Test (written 2026-07-10 PM, source: gm-ads brief + counsel deliberation + live data pulls)

## The directive (Jarred, 2026-07-10, verbatim intent)
TEST A (primary): a Google Ads campaign offering the $65 waitlist fee WAIVED with a FREE TOUR.
Mechanics per Jarred: dedicated landing page; visitors from that LP get the $65 waitlist fee waived
ONLY IF they book a tour; "perhaps... they book a tour and get the waitlist completed and then the
waitlist fee or the waitlist application only takes effect if they finalize the tour." I.e. the
application is captured in-flow, fee is deferred/waived conditional on tour completion.
TEST B (side lane, design/thinking stage): waive the $45 one-time enrollment fee for families that
enroll SAME DAY as their tour. Today this fee is managed externally (Brightwheel billing, manual).
Desired: system-managed - "automatically waived in the system... if they booked today, it saves
them $45. If not, then it just adds it to their next bill."

## Decisions Jarred is superseding with this directive
- $65 mandatory-for-everyone (2026-07-06) -> now has a tour-conditional waiver TEST path.
- "Tours only fallback, tour campaign = later test" (7/2) -> activated now.
STILL BINDING unless he says otherwise: the dollar amount $65 appears NOWHERE in ad copy
(say "application fee waived with your tour"); NEVER anything licensing-related in ads or site
(permanent hard rule); never-drop (pause/edit only) in the Ads account; no call assets/conversions;
YouTube/Discover/Demand Gen permanently parked; budget raises are evidence-gated proposals only;
public waitlist flow writes ONLY waitlist_pipeline + waitlist_holds, NEVER children table, NEVER
Solace enroll gate; solace-mirror.db schema ADDITIVE only; Stripe via httpx not SDK; no em dashes
anywhere in copy or code.

## Live assets to build on (do not reinvent)
- TOUR BOOKING IS LIVE ON PROD: www.growingmindfully.org/tour/ (calendar-first page, noindex,
  0 internal links), backed by waitlist.growingmindfully.org /api/tours/slots (58 slots, 3-min
  fresh, dual-push bridge to ashley@growingmindfully.org real calendar, launchd healthy).
  Booking gate /book: rate-limited 4/hr. Repo: growingmindfully (site) + gm-waitlist (worker).
- Waitlist overlay v35 live on all LPs; GA4 events gmwl_overlay_open/email_submitted/
  application_submitted/fee_paid(+confirmed)/fee_exit_winback_shown/waitlist_terms_signed.
  A fee-exit winback module ALREADY EXISTS (shown at fee abandonment, offers tour - GA4 shows
  gmwl_fee_exit_winback_tour clicks). The waiver test is conceptually an upstream version of this.
- Attribution capture: migration 012 stores utm_*/gclid/attribution_source/referrer/landing_path
  on every application row. End-to-end verified.
- Ads account 945-427-9476: 6 campaigns $103/day split ($115 enabled), Stage 0 capped Max Clicks,
  freeze until 7/16. Conversions: gmwl_email_submitted PRIMARY $5, gmwl_fee_paid_confirmed
  Purchase PRIMARY $65 (headline), gmwl_reserve_confirmed $1,839 staged for 7/14. Directions
  demote pending. Clickwrap terms waitlist-v1.ts is counsel-ready + SHA-256 versioned (terms
  edits = Tier 2 gated).

## Evidence base (why this test is well-aimed)
- First paid-attributed fee-paid EVER: 7/10 (Flynn, state employee, multi-visit email->return->pay).
  Before that: 2 of last 2 applications stalled at the $65 payment step (1 paid-attr, 1 organic).
- GA4 90d funnel: overlay_open 117 -> application_submitted 16 -> fee_paid 6 (~38% app->fee).
- Counsel deliberation 7/10 (5 models): unanimous that fee-step friction is the binding
  constraint; top move = fix fee trust; P6 budget raise REJECTED; P9 PMax REJECTED.
- /state-employees/ LP currently says "No application fee" twice (contradiction, fix pending
  Jarred gate) - the waiver LP must NOT recreate this class of bug: copy must be precise that
  the WAIVER is conditional on tour completion.
- Capacity: Infant emptiest (10-11 open, ~44% used), Toddler full until Aug (2-4 open after),
  Preschool 6-9 open Aug-Sep + big Feb 2027 wave. Empty-seat cost $6.4k-$9.4k/WEEK.
- Rate card FT monthly: Infant/Toddler $1,839-$2,074; Young Preschool $1,577-$1,860;
  Preschool $1,436-$1,595. Tiers: Private/State/VIP.
- Competitor fees (Sacramento): $40-$100 waitlist fees common (+$150 registration); $65 is
  mid-market. A waived-fee-with-tour offer is a real differentiator locally.
- Economics: one enrollment covers ~a month of spend; a free tour that converts even 1 in 10
  bookings to enrollment massively out-earns the $65 waived.

## Org/repo map
- gm-ads (~/Projects/gm-ads): ads account operations, brief.md, tools/gads/* (Scripts-slot
  injection tooling; login currently BLOCKED on lpass unlock - campaign build will be STAGED).
- growingmindfully (~/Projects/growingmindfully): the static site + /tour/ page + waitlist widget.
- gm-waitlist (separate repo ~/Projects/gm-waitlist): the Cloudflare Worker + D1 (applications,
  fees, Stripe, tours API, clickwrap).
- kindred-portal: admin portal reading the same D1 (admin tasks, /ads dashboard).
- Brightwheel billing: via bwlib on mini (Bw* skills, dry-run->confirm->execute->BwVerify gate).
  The $45 enrollment fee lives THERE today, manual.

## Output contract for every lane agent
Write your deliverable to ~/Projects/gm-master/marketing/paid-ads/drafts/2026-07-10-tour-waiver-test/<lane>.md
Be concrete: file paths, campaign/asset names, copy text, schema DDL, event names, numbers.
Flag every Jarred gate (Tier 2: parent-facing copy, waitlist mutation, clickwrap edit, budget,
production deploy). Nothing you write executes anything - these are build-ready plans + drafts.
NO EM DASHES anywhere. Never put "$65" or licensing anything in proposed AD copy.
