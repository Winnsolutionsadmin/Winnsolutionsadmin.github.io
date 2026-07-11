# GROUND: Tour-Waiver Package Distilled for the Lifecycle Funnel (2026-07-11)

Single reference so lifecycle-funnel design/verify agents do not re-read all five 2026-07-10 lanes.
Source package: `~/Projects/gm-master/marketing/paid-ads/drafts/2026-07-10-tour-waiver-test/`
(SYNTHESIS.md + A-policy-compliance.md + B-campaign-architecture.md + C-landing-page.md +
lp-tour-offer-mockup.html + D-waitlist-flow.md + E-measurement.md + CONTEXT-PACK.md).
New directive that extends it: this dir's CONTEXT-PACK2.md.

No em dashes, no licensing language, no unconditioned "fee waived" claims: those hard rules carry
straight through from the source package into everything below.

---

## 0. One-paragraph orientation

The tour-waiver package designed ONE acquisition test: a single Google Ads campaign ("Search - Tour
Offer | Fee Waiver Test") driving to ONE dedicated, noindexed landing page (`/lp/tour-offer/`) that
offers the $65 waitlist application fee waived on tour completion, backed by a new gm-waitlist side
table (`tour_waivers`, migration 050) and a `pending_tour` application state, with pre-registered
measurement and a full policy/compliance pass. Verdict: BUILDABLE + COMPLIANT WITH CONDITIONS,
staged, nothing executed, launch targeted at the 7/16 batch. The lifecycle-funnel directive
(CONTEXT-PACK2) keeps almost all of that machinery and wraps it in a much bigger system: a
multi-variant ad matrix (V1-V5), multiple LP variants, automated lifecycle emails (T1-T4), a
per-family x per-campaign tracking grid in Kindred, and full "update all databases" tour-booking
instrumentation. Most of the backend and measurement design is directly reusable; the ad-copy and
LP-count rules change; Test B ($45) gets partially un-parked by the "$100+" variant.

---

## 1. REUSABLE: already designed, inherit as-is (or nearly)

### 1a. Backend / gm-waitlist (D-lane) - the whole waiver mechanic is reusable
- **`tour_waivers` side table** (migration `050_tour_waivers.sql`, full DDL in D-lane). One row per
  waiver-path application, 1:1 with `applications.id`. Columns: `application_id` (PK, FK), `offer_code`
  (default `'tour-waiver'` - lifecycle system will need per-variant codes, see section 3),
  `tour_booking_id` (FK to `tour_bookings`), `waiver_state` CHECK IN
  (`'pending_tour','waived','expired','forfeited'`), `application_effective_at`, `expires_at`,
  `forfeits_at`, `expired_notified_at`, `created_at`, `updated_at`. Plus index
  `idx_tour_waivers_state(waiver_state, expires_at)` and abuse table `tour_waiver_email_history`
  (`email_norm` PK, one waiver per family EVER).
- **Load-bearing constraint that shapes ALL lifecycle DB work:** prod `applications` is at 99/100 of
  D1's column cap and is CLOSED to new columns (migration 033/036 precedent). Every new
  application-adjacent field MUST go in a side table. The lifecycle email/campaign-grid state cannot
  ALTER `applications`; it needs its own side tables too.
- **`status='pending_tour'` needs no migration:** `applications.status` has no CHECK constraint, and
  a new value is auto-excluded from every capacity/position/forecast/campaign query (they all filter
  `status='waiting'`). Reuses the exact mechanic `pending_payment` already uses pre-fee.
- **State machine** (full ASCII diagram in D-lane): LP-flagged app enters `pending_tour` (Stripe fee
  step SKIPPED, not counted) -> tour attended (Ashley marks in Kindred) flips to `waived` +
  `status='waiting'`, $65 never charged -> OR no tour within N days flips to `expired`, emails
  pay-or-rebook -> OR no action within M more days flips to `forfeited`, archives shell.
  Constants: **N = 3 days** after `slot_end` (mirrors `ABANDON_GRACE_HOURS=72`), **M = 11 more days
  (14 total)** to forfeit.
- **Endpoints (signatures reusable):**
  - `POST /api/applications` gets a new branch: if `body.offer_code` is a waiver code, require
    `body.tour_booking_id`, validate the `tour_bookings` row exists + `status IN
    ('pending_calendar','confirmed')` + `visitor_email` matches `parent1_email`, check
    `tour_waiver_email_history`, then insert `status='pending_tour'`, `fee_paid=0`, create the
    `tour_waivers` row, return `waiver:true` so the front end skips Stripe. Also patch the two
    duplicate-check queries at `index.ts:1444` and `index.ts:1587` to include `'pending_tour'`.
  - `POST /api/crm/families/:key/tour-waiver/complete` (NEW, `crmAuthed()` Bearer gate like existing
    `/api/crm/families/:key/*` routes). Called by kindred-portal when Ashley marks attended.
    Atomic batch: flip `tour_waivers.waiver_state='waived'` + set `application_effective_at`, flip
    `applications.status='waiting'`, fire `gmwl_tour_completed_waiver`, send "you're on the waitlist,
    no charge" email, `completeEnrollmentTask('tour_waiver_check', appId)`.
  - Cron sweep (new module like `tour-waiver-sweep.ts`) on the existing 06:00 UTC `scheduled()` tick:
    expire past-due `pending_tour`, forfeit + archive past-due `expired`. Same kill-switch /
    SANDBOX_MODE / daily-cap / 72h-quiet-window discipline as `winback.ts`.
- **Ranking touch points** (`index.ts` rankFor, `email.ts:789`, `campaigns.ts`,
  `routes/offer-rounds.ts`): add `LEFT JOIN tour_waivers tw` and order by
  `COALESCE(tw.application_effective_at, a.created_at)`. This is the only place activation-vs-
  submission ordering is enforced (decision D3 / see D-lane "Ordering fairness").
- **Kindred admin task shape:** reuses `EnrollmentTaskRequest` bridge in
  `enrollment/solace-tasks.ts` verbatim, new `kind:'tour_waiver_check'`, dedup key
  `tour_waiver_check:{application_id}`, `assignee_role:'director'` (Ashley), auto-created at BOOKING
  time so it is on her list before the tour date. Ashley's one "mark attended" click drives both task
  closure and waiver activation.
- **Abuse controls:** one waiver per email (durable history table), waiver only via real matching
  `tour_bookings` row (email match), existing 4/hr `/api/tours/book` rate limit, PRIMARY KEY prevents
  double waiver rows / stacking with legacy grandfather.

### 1b. Tour-completion signal (the single biggest instrumentation gap, now reusable design)
- Today the system tracks BOOKING (`gmwl_tour_booked`) but nothing marks a tour actually happened vs
  no-show. Chosen solution (D-lane + E-lane): **manual mark via Kindred admin task** (option 1 of 3;
  calendar-heuristic and QR-kiosk rejected). This is the prerequisite the lifecycle T4 email ("tour
  FINISHES ... UNLESS Ashley marked no-show") directly depends on: T4's trigger IS this completion
  mark. Reuse it, do not reinvent.

### 1c. Landing page (C-lane) - one built mockup, reusable as the V1 template
- **File exists:** `lp-tour-offer-mockup.html` (377 lines, brand-matched, in the source dir). Section
  structure: hero (kicker "Tour offer", H1 "Book a tour, and your application fee is waived."), "How
  it works" 3-step band, `#tour-calendar` anchor reusing the live `/tour/` calendar widget +
  `GET /api/tours/slots` feed, trust band (4 chips, no numeric rating, no licensing), FAQ
  (`<details>`/`<summary>`, 6 Qs), dark final CTA band, footer. This is the reusable LP skeleton for
  the V1-V5 variants CONTEXT-PACK2 asks for.
- **Indexing/isolation posture (reuse per variant):** `<meta robots noindex, follow>` +
  self-canonical, excluded from `sitemap.xml`, zero internal links, X-Robots-Tag noindex via
  `_headers`, reachable only via ad click. URL convention `/lp/<slug>/` matching the existing
  `/lp/state-employees/` paid-LP pattern.
- **Front-end contract (reusable, this is the ad->page->overlay plumbing):**
  - Ad final URL carries `?offer=tour-waiver` (per-variant codes in the lifecycle system).
  - On load, inline script reads `offer` from `location.search`, writes sessionStorage key
    `gmwl_offer_ctx` = `{offer, source_lp, captured_at}` (sits alongside the overlay's existing
    `GMWL_ATTR_KEY`, same naming family).
  - On successful `/api/tours/book`, fire existing `gmwl_tour_booked` GA4 event unchanged, PLUS a new
    from-offer event, and update `gmwl_offer_ctx` with `tour_booking_id` + `tour_start_iso`.
  - Overlay two-layer offer capture: Layer 1 click-time `data-gm-waitlist-offer="tour-waiver"`
    attribute forwarded through the overlay click delegate (`overlay.js` ~5283-5302) into
    `open(entryMode, opts)`; Layer 2 durable read of `gmwl_offer_ctx` from sessionStorage inside the
    overlay mount path (survives cross-session/cross-page, 30-day window) attaching `offer_code` +
    `tour_booking_id` to the application payload. Payload fields (additive):
    `offer_code`, `tour_booking_id`, `tour_scheduled_at`, landing in
    `waitlist_pipeline.attribution_json` (additive JSON, no schema change) or a dedicated column.
- **Copy discipline rule (reusable, non-negotiable):** the words "fee waived" / "no application fee"
  may NEVER appear without the tour condition in the same or immediately adjacent sentence. Grep the
  draft HTML for "fee" before ship; every hit must be conditioned. This is the standing fix for the
  `/state-employees/` "No application fee" bug class.
- Full drafted parent-facing copy (hero, 3 steps, trust band, 6-item FAQ, final CTA, phone
  (916) 626-2739) is in C-lane section 4 - reusable verbatim as the V1 baseline, Tier 2 Jarred read
  required.

### 1d. Campaign architecture (B-lane) - structure reusable, copy rules change (see section 3)
- **Recommended shape:** ONE new standalone campaign, TWO ad groups (AG1 Tour Intent 14 kws, AG2
  High-Intent Overlap 8 kws = 22 total), presence-only Sacramento geo mirroring Core, plus a
  **bidirectional negative-keyword wall** against Core/Infant/RTO/State (the cannibalization guard).
  Full 22-keyword table with match types in B-lane section 2.
- **Negative wall mechanic (reusable for every new lifecycle campaign):** new campaign negates Core's
  exact money terms; Core/Infant/RTO/State negate tour-flavored terms. Recommend a second shared list
  "GM Tour-Cannibalization Guard" used asymmetrically; existing `GM Master Negatives` (109 entries)
  attaches normally.
- **Budget/bidding:** $12/day (or $8/day), **Max Clicks, $8.50 max CPC ceiling** (mid-tier, zero
  conversion history = Max Clicks is the only sane launch strategy). Funded by reallocation inside
  the $115 ceiling OR a small explicit raise (decision D2).
- **RSA deck drafted:** 15 headlines + 4 descriptions, all condition-in-same-string, no dollar
  amounts (B-lane section 4). NOTE: this no-dollar constraint is exactly what CONTEXT-PACK2
  supersedes for the variant matrix - see section 3.
- **Conversion actions (reusable, both SECONDARY at launch):**
  - `gmwl_tour_booked` (secondary, ~$25 mid-funnel value, DDA, 90d) - reporting + future Max
    Conversions eligibility, not today's bid signal.
  - `gmwl_tour_completed_waiver` (secondary, Purchase category, value per rate_card or flat $65) -
    the real success event, earns primary status later by volume + Jarred-gated promotion, mirroring
    how `gmwl_fee_paid_confirmed` did.
  - Do NOT duplicate the existing `gmwl_fee_paid_confirmed` PRIMARY $65 headline metric; reuse it.
- **Serving:** Search only, presence-only geo, no dayparting, no device mods at launch, match Core's
  network settings. Scripts-slot build must answer the EU political-ads declaration "No" at create
  time (RTO-rebuild lesson).
- **Full 14-step build checklist** in B-lane (create negatives first, then campaign, ad groups, RSA,
  assets, conversion actions, GAQL-verify, change-log, test-registry entry, surface to Jarred).

### 1e. Measurement (E-lane) - the whole measurement frame is reusable
- **Primary metric:** tour-completed rate = tour_completed / LP sessions (lead per-session, also
  report per-click). Closest to the mechanic, first metric with enough volume.
- **True-north lagging metric:** enrollment/reservation rate from waiver-LP sessions (will NOT reach
  significance in 30 days; read qualitatively vs LTV).
- **Secondary metrics:** application starts, pending-tour count, waiver-to-activation rate, no-show
  rate (biggest execution risk), cannibalization check.
- **Decision rules (pre-register):** decision point = **100 LP sessions OR 6 weeks**, whichever
  first. SCALE if >=8 tours COMPLETED and (>=1 reservation OR >=3 non-waiver fee-paids off same LP).
  TIGHTEN if >=8 booked but completion <50% (add T-24h/T-2h reminders - do not exist today). KILL if
  <3 booked or persistent zero completions. Weekly cannibalization guardrail.
- **Power honesty:** at 5-15 clicks/day, ~100 sessions in 1-3 weeks (directional); ~200 sessions
  (2-6 weeks) for a clean 10%-vs-25% read; enrollment-level significance impossible in 30 days.
  Wilson CI table in E-lane section 3.
- **Cost of test:** midpoint ~$915-1,125, worst case ~$1,655-1,865 (spend + waived fees + Ashley's
  tour time). Covered by ~1.3 months of ONE enrollment worst case (LTV $1,436-$2,074/mo FT). The
  asymmetry is why the decision bar is deliberately low.
- **10-row weekly scorecard format** (matching `scorecards/2026-Wxx.md`) in E-lane section 5 -
  reusable, extend with a `waiver_active` flag per row.
- **Instrumentation reuse:** migration 012 attribution columns (distinct `landing_path` per LP, no
  new plumbing), `ads_daily` (migration 037), `/api/crm/ads-funnel` view + Kindred `/ads` dashboard
  (extend STAGE_ORDER/EVENT_STAGE with `tour_booked`/`tour_completed` stages). This dashboard
  extension is the seed of CONTEXT-PACK2's campaign-grid ask.

### 1f. Policy/compliance (A-lane) - the compliance frame is reusable, and it constrains the new copy
- **Verdict Test A:** COMPLIANT WITH CONDITIONS. Conditional-free-offer is a lawful, well-understood
  pattern (Google Ads + FTC 16 CFR 251.1(c) + CA BPC 17500). Risk is SEQUENCING, not offer type.
- **Verdict Test B:** COMPLIANT WITH CONDITIONS, NOT READY TO ADVERTISE (manual Brightwheel process;
  advertising a same-day $45 waiver before automation/verified-SOP exists = "unavailable offer"
  exposure). This directly collides with CONTEXT-PACK2's V3 "$100+ in fees waived" - see section 3.
- **Disclosure rule (reusable, binding):** every ad asset that says "waived"/"fee" MUST carry the
  condition in the SAME asset ("...fee waived when you complete a tour"). Never an isolated "Fee
  Waived" / "No Application Fee" headline. That isolated pattern is both the `/state-employees/` bug
  and the textbook Google "unreliable claims" / FTC free-offer violation.
- **$65-on-the-LP requirement (reusable, and it INVERTS a naive reading of the no-dollar rule):**
  Google's Dishonest Pricing Practices policy (effective Oct 28, 2025) requires the full price be
  disclosed at the destination. So the LP MUST state $65 once in the condition fine print. The
  "no $65" rule was scoped to AD COPY only. Full LP disclosure block drafted in A-lane section 2b;
  Test B block in 2c (kept ready, not for use).
- **"free tour" is banned phrasing:** tours never carried a price, so "free tour" manufactures a
  second unnecessary "free" claim next to the real one (the fee waiver). Say "book a tour" /
  "complete a tour". (CONTEXT-PACK2 V4 "Free no obligation tour" and the mockup's "Book a Free Tour"
  headline both trip this - flag for the copy lane, section 4.)
- **Clickwrap conflict (reusable blocker):** `waitlist-v1.ts` says the $65 is "non-refundable...
  regardless" and is shown "upon payment" - contradicts a deferred conditional fee. A genuine
  `waitlist-v2.ts` (counsel-reviewed, SHA-256 version bump) is REQUIRED before any waiver ad goes
  live. Option A recommended (single conditional-waiver paragraph accepted at submission). Applies to
  EVERY variant that defers the fee.
- **Internal-rules matrix + full Jarred-gate list** in A-lane sections 4-5.

---

## 2. The D1-D9 open decisions (from SYNTHESIS.md) - carry these into the lifecycle plan

| # | Decision | Lane recommendation | Status for lifecycle system |
|---|---|---|---|
| D1 | GO/NO-GO on building the Test A stack | GO (buildable, compliant with conditions) | Still open; lifecycle system is a superset, so D1 = go/no-go on the whole waiver mechanic |
| D2 | Budget: +$6-8/day explicit raise ($115->$121) vs stacked reallocation trims | Recommend the raise (honest, evidence-gated) | Reopens bigger: V1-V5 matrix needs materially more than one campaign's budget |
| D3 | Queue fairness: `pending_tour` takes position at ACTIVATION vs submission | Recommend activation-time (protects paying families; simpler, reuses `application_effective_at`) | Unchanged; still a policy call, applies to every waiver variant |
| D4 | Clickwrap v2 language approval (Tier 2, counsel pass) | Option A single conditional paragraph | Unchanged; blocks launch of any fee-deferring variant |
| D5 | LP fine print states $65 once (policy rec) vs omit | Policy WINS: state $65 once on the LP (Variant B), never in ads | Note: CONTEXT-PACK2 now ALSO allows $65 in ad copy, so D5's "never in ads" half is superseded (section 3) |
| D6 | Expiry constants: 3-day tour window, 14-day forfeit | Approve as proposed | Unchanged; also governs lifecycle email timing (T3/T4 windows must not contradict) |
| D7 | `/state-employees/` "no application fee" fix (4 instances: lines 98, 104, 335, 359) ships same push | Fix in same push | Still required; a live self-contradiction Google Misrepresentation reviewers look for |
| D8 | Launch timing: 7/16 batch vs freeze waiver now | Recommend 7/16 batch; waiver-option flagged if Jarred weighs friction as RTO-grade urgent | Reopened by live state: ads login now WORKING, freeze ends 7/16, first fee-paid landed |
| D9 | Test B ($45): confirm parked as Phase 2 | Parked; not ready for paid media | PARTIALLY OVERRIDDEN by CONTEXT-PACK2 V3 "$100+ in fees waived" = $65+$45 stacked (section 3) |

All nine are Jarred gates; nothing in the source package or this ground doc executes anything.

---

## 3. EXTENDS vs CHANGES: exactly where CONTEXT-PACK2 modifies the tour-waiver design

### CHANGES (the new directive overrides a prior ruling)

1. **Dollar figures ARE now allowed in variant ad copy (biggest change).**
   - Prior: CONTEXT-PACK line 17 + A-lane matrix + B-lane "ABSOLUTE RULES" + SYNTHESIS all said $65
     appears NOWHERE in ad copy; only the LP may state it.
   - New (Jarred 2026-07-11 verbatim "One should be 65 waitlist fee waived!"): dollar figures allowed
     in ad copy FOR THESE TEST VARIANTS. The 7/2 "no $65 in copy" deck ruling is superseded for these
     tests. So V5 "$65 waitlist fee waived!" and V3 "$100+ in fees waived" are now permitted ad copy.
   - Guardrails that survive: "$100+" must be truthful ($65+$45 stacked) with conditions clear;
     "this week only" urgency must ACTUALLY expire/rotate (evergreen = policy risk); every waived
     claim still needs its condition in the same asset (A-lane disclosure rule is NOT waived, only the
     no-dollar rule is). The A-lane Promotion-asset caution still applies at the platform-render
     level, but the reason to avoid it (forcing a dollar figure) is weaker now that dollars are OK -
     re-evaluate Promotion assets for these variants.

2. **Multiple LP variants instead of one.**
   - Prior: exactly one dedicated LP `/lp/tour-offer/`.
   - New: an ad-variant matrix V1-V5 (plus more if warranted), each needing message-matched LP copy
     uniform with the existing site (hero text, booking availability, brand system). The V1-V5 set:
     V1 "OPEN ENROLLMENT!" (= the no-waitlist-fee / tour-waiver campaign, rebranded),
     V2 "Back to School", V3 "$100+ in fees waived this week only! Tour our location for FREE!",
     V4 "Free no obligation tour", V5 "$65 waitlist fee waived!".
   - Reuse: the `lp-tour-offer-mockup.html` skeleton + front-end contract + isolation posture become
     the TEMPLATE each variant LP is cut from. Each variant LP still: noindex, zero internal links,
     ad-click-only entry, per-variant `?offer=` code. The isolation mandate scales per-variant, it is
     not relaxed.

3. **Test B ($45) is partially un-parked.**
   - Prior: D9 parks Test B as Phase 2; A-lane says do NOT put the $45 same-day waiver into paid media
     until automation or a verified SOP exists (manual Brightwheel = "unavailable offer" exposure).
   - New: V3 advertises "$100+ in fees waived" = the $65 waitlist fee + the $45 enrollment fee
     STACKED. Advertising the $45 waiver reopens D9 and the A-lane sequencing gate. This is a genuine
     TENSION the lifecycle plan must resolve: either (a) build the $45 waiver automation / verified SOP
     before V3 runs, or (b) scope V3's "$100+" so the $45 half is honored by an airtight process, or
     (c) drop V3 to $65-only. Flag to policy + waitlist-flow lanes; do not let V3 launch on the
     current manual $45 process.

4. **The $65-never-in-ads half of D5 is superseded** (folded into change #1). D5's LP half (state $65
   once on the LP) still stands per Google Dishonest Pricing Practices.

### EXTENDS (net-new scope the tour-waiver package did not cover)

5. **Lifecycle emails T1-T4 (automated journey) - entirely new.** The tour-waiver package was
   single-shot acquisition; this adds a nurture/retention sequence keyed off waitlist-fee-paid and
   tour state, in America/Los_Angeles timezone:
   - T1: fee-paid + NO tour done -> "Reserve Your Space" email within 24h.
   - T2: clicked T1 but did not reserve, tries to EXIT the reserve page -> "book a tour" winback
     popup -> routes to `/tour/`, tracks the booking. (This is an extension of the EXISTING fee-exit
     winback module - `gmwl_fee_exit_winback_*` events already fire and already offer a tour on fee
     abandon; T2 generalizes that pattern to the reserve page.)
   - T3: still no tour booked -> +24h email "Book a tour and waive your enrollment fee!".
   - T4: tour FINISHES (send 1h after scheduled tour END time) UNLESS Ashley marked no-show in
     Kindred -> promo "reserve by 5PM TODAY and we waive the $45 enrollment fee". Must reuse the
     EXISTING email template formatting + picture style with a DIFFERENT picture.
   - Reuse hooks: T4's trigger IS the tour-completion mark designed in 1b/1c (the Kindred admin-task
     completion). T3/T4 both advertise the $45 enrollment-fee waiver, so they inherit the same Test-B
     "$45 not automated yet" tension as V3 (change #3). CAN-SPAM applies (unsubscribe + physical
     address + suppression) - new constraint for these promotional emails to applicants.

6. **Campaign tracking grid in Kindred - new admin surface.** Per-waitlist-family rows x campaigns
   columns; cell states received / engaged-not-converted / converted; click-through to drill-level
   data (sends, opens, clicks, timestamps). Requires email open+click tracking (pixel + wrapped
   links) that does not exist today. EXTENDS the existing `/ads` dashboard + `ads-funnel.ts` STAGE
   maps (E-lane 1e) rather than starting fresh, but the per-family x per-campaign matrix and the
   open/click instrumentation are net-new.

7. **"Update ALL databases" tour-booking tracking.** Directive item 1: tour bookings must update D1,
   GA4, and dashboards (full tracking). EXTENDS the existing `gmwl_tour_booked` + tour-completion
   design into a requirement that every tour event fan out to all three surfaces consistently.

8. **Independent tracking + public brand name for the no-waitlist-fee campaign.** The tour-waiver
   test is now branded "OPEN ENROLLMENT!" publicly (= V1) and must be tracked INDEPENDENTLY and
   compared head-to-head against the standard flow. EXTENDS E-lane's single-test measurement into a
   comparative multi-variant read (V1-V5 each tracked separately, per-variant `?offer=` codes and
   distinct `landing_path` values make this cheap).

9. **Urgency/rotation machinery is new.** V3 "this week only" and any time-boxed claim must actually
   expire and rotate; the tour-waiver offer was ongoing/non-seasonal. This needs a rotation/expiry
   design (ad scheduling or scripted swaps) that the source package explicitly did NOT build.

### UNCHANGED (carry straight through, do not re-litigate)
- The `tour_waivers` side table + `pending_tour` state + N=3/M=11 constants + activation-time
  ordering recommendation + abuse controls (per-variant `offer_code` is the only addition).
- The noindex + zero-internal-links + ad-click-only isolation mandate, now applied per LP variant.
- The clickwrap `waitlist-v2.ts` counsel requirement before any fee-deferring variant launches.
- The disclosure rule (condition in same asset), the "free tour" ban, the `/state-employees/` fix.
- Conversion-action discipline (new actions SECONDARY; protect `gmwl_fee_paid_confirmed` PRIMARY $65
  as the uncontaminated headline metric).
- All Tier 2 gates: parent-facing copy, waitlist mutations, clickwrap, budget, prod deploys; Stripe
  via httpx; additive-only schema; public flow writes only waitlist_pipeline + waitlist_holds; never
  children / never Solace enroll gate; Brightwheel money ops only via Bw* skills.

---

## 4. Tensions the lifecycle plan MUST resolve (do not let these slip)

1. **V3 "$100+ in fees waived" advertises the un-automated $45 enrollment-fee waiver.** Collides with
   A-lane's "do not advertise Test B until automated/verified-SOP" and D9. Resolve before V3 or T3/T4
   launch (build the $45 automation, or a gated verified SOP, or drop to $65-only).
2. **"Free tour" phrasing in V4 and the mockup headline** ("Book a Free Tour Online",
   "Free no obligation tour") trips the A-lane "no free tour" precision rule. Copy lane must decide:
   keep for testing (Jarred explicitly listed V4) but scrub the double-free ambiguity, or reword.
3. **Dollars now in ad copy re-opens the Promotion-asset question.** A-lane recommended against
   Promotion assets specifically because they force a dollar figure; that objection weakens now.
   Re-evaluate per variant, but the parent-facing Tier 2 gate + platform policy review still apply.
4. **Multiple LP variants multiply the isolation-mandate verification surface.** The pre-deploy grep
   ("`grep -r 'tour-offer'` returns only the LP dir + `_redirects`/`_headers`") must become a
   per-variant check across all V1-V5 slugs before every deploy.
5. **CAN-SPAM on T1-T4 promotional emails** is a new compliance surface the acquisition-only package
   never touched (unsubscribe, physical address, suppression list, quiet-window overlap with the
   existing winback 72h rule).
6. **Budget:** V1-V5 is materially more than the single $12/day test the source package sized.
   D2's "+$6-8/day" no longer covers it; the lifecycle plan needs its own budget math.

---

## 5. File index (where the reusable detail actually lives)
- Backend DDL + state machine + endpoints + admin task + Test B sketch:
  `2026-07-10-tour-waiver-test/D-waitlist-flow.md`
- Campaign structure + 22 keywords + RSA deck + negative wall + conversion actions + build checklist:
  `.../B-campaign-architecture.md`
- LP spec + front-end contract + full parent-facing copy + GA4 events:
  `.../C-landing-page.md` and the built mockup `.../lp-tour-offer-mockup.html`
- Measurement metrics + decision rules + power analysis + scorecard + cost:
  `.../E-measurement.md`
- Policy verdicts + disclosure language + clickwrap conflict + gate list + sources:
  `.../A-policy-compliance.md`
- Go/no-go + D1-D9 + isolation mandate: `.../SYNTHESIS.md`
- Original baseline: `.../CONTEXT-PACK.md`; new directive: this dir's `CONTEXT-PACK2.md`.
