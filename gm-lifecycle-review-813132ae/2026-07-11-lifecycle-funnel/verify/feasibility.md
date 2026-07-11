# VERIFY: Feasibility attack on the lifecycle-funnel designs (2026-07-11, live-source re-verified)

Lane: VERIFY. Adversarial question: **does every design fit the actual gm-waitlist / kindred-portal
code + D1 schema ground truth as it stands on disk RIGHT NOW?** Method: read all design + ground
docs, then re-ran every load-bearing claim against live source in `~/Projects/gm-waitlist/src` and
`~/Projects/gm-waitlist/migrations` (not against the ground docs' summaries). Every finding is
file+line cited. No em dashes.

**Bottom line: the reuse substrate (Postmark/Resend transport, `emailShell`, `campaign_sends`
open/click tracking, `campaignFunnel`, `/c/:token`, `tour_bookings.slot_end`, the Kindred view/helpers
stack) is REAL and mostly reusable.** But there are now **SIX blocking seams**, TWO of which are new
and were invisible to the prior consistency/feasibility passes because those passes trusted the ground
docs' "049 is latest migration" snapshot. That snapshot is STALE. The two new blockers (F0a migration
collision, F0b a second live $65-waiver path) must be resolved by the synthesizer before any build,
alongside the four already-known ones (F4 slug/offer registry, F1/F2/F3 T4 send-path straddle, F5/F6
CTA/tracking paths).

---

## 0. NEW BLOCKERS found by re-verifying against on-disk source (not in the prior passes)

### F0a. (BLOCKER) Migrations 050 AND 051 are ALREADY TAKEN on disk. Next free number is 052.
- **Claim (pervasive):** every ground + design doc assumes 050 is the next free migration.
  `d1-schema.md` line 11 ("Highest applied: 049. Next free number ... is 050"),
  `waiver-package.md` §1a (`050_tour_waivers.sql`), `enrollfee-noshow.md` C1.1 (`050_tour_attendance.sql`,
  "next number; 049 is latest"), `data-tracking.md` (migrations 050=tour_waivers, 051=lifecycle_tracking),
  `campaign-grid.md` §2b ("`tour_waivers` migration 050" + "`tour_outcomes` migration 050 sibling").
  `consistency.md` C-8 even audits the three-way 050 collision AMONG the designs, but still assumes 050
  itself is free.
- **Ground truth (verified 2026-07-11, `ls migrations/` + `git log`):** `050_feedback.sql` (BETA
  feedback + auto error-snapshot pipeline, commit `d568c3c`) and `051_table_day_waivers.sql` (VIP RTO
  table-day $65 waiver codes, commit `000569e`) BOTH exist and are committed, both dated 2026-07-11.
  The highest migration on disk is **051**, not 049. The next free number is **052**.
- **Why it breaks:** D1 applies migrations by number. A new `050_tour_waivers.sql` /
  `050_tour_attendance.sql` / `051_lifecycle_tracking.sql` written per the current design set will
  COLLIDE with the two already-committed files (duplicate number -> either a rename fight in git or a
  skipped/out-of-order apply). Every migration reference in the entire design set is off by at least two.
- **Fix:** renumber the whole lifecycle migration plan starting at **052** and going up, and re-run the
  "verify no collision at write time" check `d1-schema.md` line 16 already advises (that advice was
  correct; the specific numbers were not). Concretely, a workable sequence: 052=tour_waivers,
  053=tour_attendance/outcomes, 054=lifecycle_sends, 055=campaign_events, 056=offer_variants. This
  supersedes `consistency.md` C-8 (whose "sequence them 050/051" fix is itself now stale).

### F0b. (BLOCKER) A SECOND live $65-waiver path shipped 2026-07-11 (`fee_grandfathered_at`); the lifecycle T1/T3 cohort logic is blind to it and mis-triggers.
- **Claim:** the design set models exactly two ways a family reaches the waitlist: Cohort A "standard
  fee-paid" (`fee_paid=1`) and Cohort B "OPEN ENROLLMENT tour-waiver" (`fee_paid=0` +
  `tour_waivers.waiver_state='waived'`). `d1-schema.md` §"Load-bearing columns" calls `fee_paid` "the
  de facto rank anchor and the T1 trigger signal (fee paid, no tour = T1)". `email-reserve.md` §0 keys
  T1-A on `fee_paid=1`. `consistency.md` §1 builds its whole trigger x cohort matrix on A/B/C/D only.
- **Ground truth (verified in source):** migration `051_table_day_waivers.sql` plus new module
  `src/server/waiver.ts` introduce the FIRST runtime writer of `applications.fee_grandfathered_at`.
  Per-building lobby "table day" event codes waive the $65 fee on-site by flipping
  `UPDATE applications SET fee_grandfathered_at=..., fee_grandfathered_note=... WHERE id=? AND fee_paid=0`
  (`index.ts:2689`). So a table-day-waived family has **`fee_paid=0` AND `fee_grandfathered_at` set**.
  Every settle-gate in the worker treats them as fee-settled via `(fee_paid OR fee_grandfathered_at)`
  (`index.ts:1806, 1844, 2098, 2291, 2656`). This is a THIRD live cohort the design set never saw
  (the 033 legacy `fee_grandfathered` backfill was static; 051 makes it a runtime acquisition channel).
- **Why it breaks:**
  1. **T1-A silently skips them.** T1-A's predicate is `fee_paid=1`. A table-day family is `fee_paid=0`,
     so they are a fully fee-settled waiting family who receives NO T1 "Reserve Your Space" email. T3
     (also `fee_paid=1`-gated) skips them too. The entire table-day cohort is invisible to the lifecycle
     journey. Given table days are a funded VIP/state-employee acquisition push, this is exactly the
     high-value cohort the nurture sequence should catch.
  2. **`d1-schema.md`'s "`fee_paid` = the T1 trigger signal" is now incomplete.** The correct
     "this family has settled the waitlist fee" predicate across the app is
     `(fee_paid=1 OR fee_grandfathered_at IS NOT NULL)`, and even that conflates three different families
     (paid, tour-waived, table-day-waived) that a comparative-cohort read wants to keep distinct.
- **Fix:** the synthesizer must add the table-day cohort to the trigger matrix and decide T1/T3 audience
  predicates deliberately. Recommended: T1's "fee settled, no tour" audience becomes
  `(fee_paid=1 OR fee_grandfathered_at IS NOT NULL) AND status='waiting' AND no tour`, with
  `fee_grandfathered_note` (or a cohort tag) segmenting table-day vs standard in the grid/scorecard so
  the comparative read stays honest. Also reconcile with `campaign-grid.md`'s cohort resolver (its
  `OFFER_VARIANTS` map has no table-day bucket, so those families fall to `standard`, double-jeopardy
  with C-4). This interacts with the C-3 `?offer=` registry work: the table-day path uses event CODES on
  `fee_grandfathered`, NOT a `?offer=` LP param, so it is a fourth distinct waiver-attribution surface.

---

## A. BLOCKING / INFEASIBLE AS WRITTEN (known, re-verified against source)

### F1. The T4 email builder signature is incompatible with the CAMPAIGNS registry it says to join
- **Claim:** `email-post-tour.md` §8 defines `buildPostTourPromoEmail(row, urls, deadline)` (THREE
  args), and §1/§8 say drop it in "as a `CAMPAIGNS` registry entry OR as the render half of
  `runTourFollowups`."
- **Ground truth (VERIFIED `campaigns.ts:97`):** the registry contract is exactly two args:
  `build(row: { child_first: string|null; parent1_first: string|null }, urls: { clickUrl: string; tourUrl?: string }): { subject; html }`.
  `runCampaignWave` invokes it as `template.build(r, { clickUrl, tourUrl })` (`campaigns.ts:678`) with
  no third argument. The audience `r` is SELECTed with only child_first / parent1_first / parent1_email
  fields, no `slot_end`, no `booking_id`, no deadline label.
- **Why it breaks:** a registry campaign cannot receive a per-booking `deadline` arg, and `row` cannot
  carry the booking's `slot_end` / dated afterCta label. T4-as-registry with the §6 today/tomorrow
  variant intact is impossible.
- **Fix:** either (a) compute the deadline INSIDE `build()` from send-time `Date.now()` in
  America/Los_Angeles (drops the 3rd param, fits the 2-arg contract, but §6's "decide by send hour" and
  the dated `{weekday}, {Month} {D}` become render-time logic), OR (b) accept T4 is a bespoke
  `runTourFollowups` send, not a registry entry (triggers F2).

### F2. "Reuse the campaign tracking substrate for free" holds ONLY inside `runCampaignWave`; a bespoke `runTourFollowups` (T4) does not inherit it
- **Claim:** `email-post-tour.md` §1/§7 say T4 fires via `runTourFollowups(db, env, baseUrl)`
  "mirroring `runReservationReminders`" AND writes a `campaign_sends` row + routes the CTA through
  `/c/:token` + appends the open pixel. `campaign-grid.md` §10 dep #1 makes this a HARD dependency: no
  `campaign_sends` write -> the grid column is permanently empty.
- **Ground truth (VERIFIED `campaigns.ts:658-692`):** the tracking apparatus is internal to the
  `runCampaignWave` per-family loop: `mintToken()` (`:658`), INSERT-first `campaign_sends` dedup
  (`:663`), `clickUrl = ${base}/c/${token}` (`:668`), `pixelImg(.../o.gif)` appended to the html
  (`:679`), and crucially `metadata: { gm_send_token: token }` (`:682`) which the Postmark delivery
  webhook keys on to stamp `campaign_sends.delivered_at`. `runReservationReminders` (the thing T4 says
  it mirrors) calls `sendEmail` directly with NONE of that.
- **Why it breaks:** a `runTourFollowups` "mirroring `runReservationReminders`" sends the email but does
  NOT populate `campaign_sends`/opens/clicks/`delivered_at`, so the T4 grid column stays empty,
  contradicting `campaign-grid.md` dep #1. The plumbing is engine-internal, not free.
- **Fix:** route T4 (and every cron-fired lifecycle email that must appear in the grid) THROUGH
  `runCampaignWave` (create a `campaigns` row, drive it from the cron leg with an explicit `wave` +
  `approvedVia:'lifecycle-cron'` - the human gates are HTTP-layer, not in the function, so this is
  allowed and CONFIRMED feasible below), OR factor the per-family send+track block out of
  `runCampaignWave` into a shared helper both call. Do not hand-reimplement token/pixel/`gm_send_token`.

### F3. Per-booking T4 idempotency collides with `campaign_sends`' per-application uniqueness
- **Claim:** `email-post-tour.md` §1 adds `tour_followups(booking_id, stage)` for "one T4 send per
  booking ever," AND writes a `campaign_sends` row for grid visibility.
- **Ground truth (VERIFIED):** `campaign_sends` is UNIQUE `(campaign_id, application_id)` (index
  `idx_campaign_sends_app`), enforced INSERT-first at `campaigns.ts:663` (dup throws ->
  `skipped++; continue`). A family who tours twice has ONE `application_id`.
- **Why it breaks:** the SECOND completed tour's T4 is blocked by the anti-join even though
  `tour_followups(booking_id)` says it is due. Per-booking vs per-application idempotency disagree.
- **Fix:** decide whether a repeat tour re-fires T4. If yes, the grid cannot key T4 on `application_id`
  under one `campaign_id`. If no (one T4 per family ever is acceptable), drop `tour_followups` and rely
  on the `campaign_sends` anti-join. Low volume today, but the docs assert both without reconciling.

### F4. The two LP-owning designs disagree on V3/V4/V5 slugs AND `?offer=` codes, and the offer code is the server waiver-allowlist key
- **Claim A (`lp-factory.md` §1):** V3 `?offer=fees-waived`, V4 `/lp/free-tour/ ?offer=free-tour`, V5
  `/lp/fee-waived-65/ ?offer=fee-waived-65`; allowlist `WAIVER_OFFER_CODES = {open-enrollment,
  fees-waived, fee-waived-65}`.
- **Claim B (`ad-variants.md` §1/§4):** V5 `/lp/waitlist-fee-waived/ ?offer=waitlist-fee-waived`, V3
  `?offer=fees-waived-100`, V4 `/lp/book-a-tour/ ?offer=tour`.
- **Why it breaks:** the `?offer=` code is the waiver-branch allowlist key AND the grid cohort-resolution
  key. If LPs ship per ad-variants but the allowlist ships per lp-factory, V5/V3 codes are NOT in
  `WAIVER_OFFER_CODES`, so the $65 waiver **silently does not fire** (server treats them tracking-only,
  family is charged the full fee against an ad promising it waived: the "unavailable offer" exposure
  `policy-compliance.md` §1.3 warns of), and the grid mis-buckets those families to `standard`. V4/V5
  also point at LP dirs one lane never builds -> 404 on ad click. Per-slug isolation greps target
  different strings.
- **Fix:** synthesizer locks ONE canonical `{slug, offer_code, utm_campaign, utm_content}` registry
  that the LP files, `WAIVER_OFFER_CODES`, the grid `OFFER_VARIANTS`, and Ads Final URLs all reference.
  This must precede any LP build. (lp-factory's §1b already declares a canonical set and flags
  `book-a-tour` vs `free-tour` as the one open naming call; adopt that and reconcile ad-variants to it.
  Note F0b: the table-day path is a fourth attribution surface that does NOT use `?offer=`, so the
  registry must also record "code-based / fee_grandfathered" as a non-LP cohort.)

---

## B. HAND-WAVED / UNDERSPECIFIED SEAMS (feasible, but materially more work than stated)

### F5. The T3 CTA cannot reach `/tour/?offer=` through the existing `/c/:token` click tracker
- **Claim (`email-tour-nudge.md` §1e):** fallback = wrap `/tour/?offer=enroll-waiver` through the
  campaign `/c/:token` click tracker and make `/c/` preserve the query string for tour destinations.
- **Ground truth (VERIFIED `campaigns.ts:1104-1130`):** `/c/:token` ALWAYS 302s to
  `/portal/<portal_token>?utm_*&gm_intent=<intent>`; on no matching row it redirects to `SITE_URL`
  (homepage, `:1114`), and on no `portal_token` it ALSO dead-ends at `SITE_URL` (`:1121`). There is NO
  tour-destination branch and no arbitrary-query passthrough. The primary path (`/t/:token` appending a
  server-controlled `?offer=`) is also net-new: `tourRedirectDest()` returns a FIXED destination
  (`index.ts:6064`, "never interpolate user input").
- **Fix:** state BOTH T3 CTA options require backend changes. The `/c/` "fallback" is not a query tweak,
  it needs a new tour-destination branch. Prefer extending `/t/:token` with a stored, server-controlled
  `offer` enum (and register `enroll-waiver` per `consistency.md` C-11).

### F6. The grid's T2 column reads `funnel_events` rows nothing writes, and the winback design's proposed server write targets the wrong table
- **Claim:** `campaign-grid.md` §2b/§3c read `gmwl_fee_exit_winback_*` + new `gmwl_reserve_exit_winback_*`
  from `funnel_events`. `winback-popup.md` proposes `bridgeEnqueue('t2_reserve_winback_shown', ...)` as
  the durable server signal.
- **Ground truth (VERIFIED):** the fee-exit winback events fire client-gtag ONLY
  (`overlay.js:1356/1380/1381/1385` via `gmwlTrackFunnel` -> `gtag`); nothing writes them to D1
  `funnel_events`. And `bridgeEnqueue` writes `solace_bridge_outbox` (`db.ts:290`), NOT `funnel_events`,
  which the grid does not read. So neither the existing events nor the proposed enqueue populates the
  queried table. (Also per `consistency.md` C-2: the grid queries the WRONG event family - the old
  `gmwl_fee_exit_*` not the new `gmwl_reserve_exit_*`.)
- **Fix:** choose ONE server sink for T2 (recommend a `funnel_events` write from the overlay on
  shown/tour, or the `exit_intents` side table) and make the grid query it by the correct
  `gmwl_reserve_exit_winback_*` names. Do not rely on `bridgeEnqueue` for the grid.

### F7. The `lifecycle_sends` idempotency table is largely redundant for stages that run as campaigns
- **Tension:** `d1-schema.md` item 2 calls `lifecycle_sends(application_id, stage)` "the single most
  load-bearing new table," while `email-reserve.md` §0/§7 correctly leans on the existing
  `campaign_sends` UNIQUE `(campaign_id, application_id)` as the idempotency key. For any stage that
  writes `campaign_sends` (T1, T3, T4-as-campaign) the anti-join already dedupes; a separate
  `lifecycle_sends` row is redundant. It is only needed where a stage does NOT write `campaign_sends`
  (the T2 popup) or needs per-booking keying (T4, see F3).
- **Fix:** scope `lifecycle_sends` to the non-`campaign_sends` stages only, or drop it. Not a blocker.

---

## C. MINOR / ACCURACY (not blockers)

### F8. The "5-cron-trigger limit" claim is now BETTER supported than the prior pass allowed, but the real constraint is per-family timers, not slot count
- The prior feasibility pass flagged the 5-cron claim as "unverifiable from this repo." Re-verified:
  `wrangler.jsonc` defines TWO crons in prod (`:42` `["*/10 * * * *", "0 6 * * *"]`), TWO in staging
  (`:175`), and `[]` in sandbox (`:142`) and harden. The repo's OWN comment (`wrangler.jsonc:139-140`)
  states: "the Cloudflare account is at its 5-cron-trigger limit (sandbox + staging + prod already
  consume them)." So the "cannot add a trigger" claim is supported by the codebase's own operating note,
  not just the ground docs. Either way the actual design decision (piggyback the existing `*/10` tick
  with a gated leg, mirroring `runReservationReminders`) is correct and lower-risk regardless of the
  exact free-slot count. The real constraint the plan must honor is "no new trigger; add a due-at leg to
  `*/10`," which every email design already does. Accuracy note, not a blocker.

### F9. `improvements.md` #1 "auto pauses / negative-keywords a band's ad group at ~95%" assumes Ads programmatic control that does not exist
- The Solace forecast READ is feasible (`bandReservableInWindow` / `bandAvailabilityAt` exist and are
  used by `runCampaignWave`). But the Ads WRITE-back (auto pause/enable/negative) needs the Google Ads
  API or Ads Scripts, and there is no such integration in gm-ads or the worker (the account is operated
  by manual backup-code login). So "auto" is a human op or a not-yet-built integration.
  `improvements.md` is a hedged, ranked backlog, so this is a scoping note.

### F10. `crmAuthed` is file-local, not shared/exported
- **VERIFIED:** `crmAuthed` is defined per-module in FOUR files (`campaigns.ts:1081`, `crm.ts:333`,
  `enrollment-crm.ts:21`, `enrollment-legacy-intake.ts:16`) and is not exported. The new
  `campaign-grid.ts` must COPY the 4-line helper, not import it. (Note: `campaign-grid.md` cited
  `crm.ts:402` and "constant-time"; the real def is `crm.ts:333`, a plain `auth === token` compare that
  is NOT timing-safe. `campaign-grid.md`'s own author already corrected this per its lane summary.)
  Trivial, but "reuses" is inaccurate; it is copy-the-pattern.

---

## D. CONFIRMED FEASIBLE (reuse claims attacked against live source that survived)

- **Email transport: no new vendor.** Postmark PRIMARY + Resend FALLBACK via the single `sendEmail`
  chokepoint exist (`email.ts`, `email-infra.md` §1). No new mailer / vendor decision needed. CONFIRMED.
- **`emailShell` signature.** VERIFIED at `email.ts:456`:
  `emailShell(heading, bodyInner, ctaText, ctaUrl, footer='Growing Mindfully ... 750 N Street ...',
  afterCta='')` - a 6-arg function with the last two optional. Every email design's `emailShell(...)`
  call (incl. the `emailShell(h, body, cta, url, undefined, afterCta)` form) matches. CONFIRMED.
- **CAMPAIGNS template fields** the T1 design relies on all exist: `portalIntent` (`campaigns.ts:88`,
  used at 127/183/232), `leadAudience` (`:92`), `tourCta` (`:95`), `gm_intent=<portalIntent>` on the
  `/c/:token` redirect (`:1126`). T1 (variant A + B) is a genuine drop-in registry entry (modulo F0b
  fixing the cohort predicate). CONFIRMED.
- **`runCampaignWave` is callable from cron.** The human gates (`CAMPAIGNS_ENABLED`, `wave` required,
  `approved_via`, hourly cap at `:636`) live INSIDE the function but are satisfiable programmatically;
  they are enforced at the HTTP layer for humans, so a cron leg can pass `approvedVia:'lifecycle-cron'`
  + a wave. The "piggyback `*/10`, call the same tracked send path" approach (F2 fix) is feasible.
  CONFIRMED.
- **`campaign_sends.application_id` accepts synthetic ids** - `lead:<email>` (`campaigns.ts:318/461`)
  and `canary:<uuid>` (`:737`) - so the grid's `scope=all` lead rows and canary handling are feasible.
  CONFIRMED.
- **applications table closed - honored everywhere.** No design ALTERs `applications`. All new
  per-family state is side-tabled. CONFIRMED consistent with the 99/100 cap. (Caveat: 051 now uses the
  ONE remaining slot's neighbor differently - it is a RUNTIME writer of the existing
  `fee_grandfathered_at` column, not a new column, so the cap is intact; but see F0b for the cohort
  consequence.)
- **Tour END time is derivable.** `tour_bookings.slot_end TEXT NOT NULL` is stored per booking
  (`043_tour_booking.sql:34`), so T4's "1h after END" is a pure `WHERE datetime(slot_end)+1h <= now`,
  no duration math. The status CHECK is `('pending_calendar','confirmed','conflict','cancelled')`
  (`043:42-43`) with NO `attended`/`no_show`, confirming the no-show signal must be a side table /
  additive column. CONFIRMED.
- **Kindred grid page fits the stack.** React 19 SPA, view/helpers split, `/crm-api` direct-tokened
  lane (zero solace-api change), `registerAdsFunnel`/`crmAuthed` pattern to mirror all exist
  (`kindred-portal.md`). CONFIRMED buildable (modulo F10's copy-not-import nit + F0b's missing table-day
  cohort bucket).
- **The genuinely-missing surfaces are correctly identified as net-new, not hand-waved as existing:**
  no-show marking / attendance, `gmwl_tour_completed`, the `enrollmentFeeDue` $45 choke point (7 call
  sites incl `docusign.ts:117` hardcoded `45`), and the `waitlist-v2`/`reserve-agreement-v4` clickwrap
  bumps. Every email/LP design GATES its send/launch on these. These are honest build dependencies, not
  feasibility errors. (F0b adds one the designs missed: the $45 choke point must also thread the
  table-day `fee_grandfathered` families, who already reach the deposit step fee-settled.)

---

## E. One-line verdict for the synthesizer
The stack is real and reusable, but the design set was written against a schema snapshot that is now
two migrations stale. Ship blockers, in order: **(F0a)** renumber all lifecycle migrations to 052+
(050/051 are taken on disk); **(F0b)** add the table-day `fee_grandfathered_at` cohort to T1/T3 audience
predicates and the grid cohort map, or it silently gets no lifecycle email and mis-buckets to standard;
**(F4)** lock ONE canonical slug/offer-code registry or the $65 waiver silently no-ops on V3/V5;
**(F1/F2/F3)** decide T4's send path (registry-with-render-time-deadline vs bespoke-sweep-routed-through-
the-tracked-send-helper) since it decides whether T4 carries the today/tomorrow deadline AND lands in the
grid; **(F5/F6)** the T3->/tour/ and T2->grid paths need net-new backend, not the "reuse" the docs imply.
Resolve F0a, F0b, F4, and the T4 send-path decision before writing code; F5-F10 are corrections. All
copy/waiver items remain Tier-2 Jarred-gated; nothing here changes that.
