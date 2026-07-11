# D. Waitlist-flow backend design: tour-conditional fee waiver (Test A) + same-day-enroll waiver (Test B, Phase 2)

Lane: WAITLIST-FLOW. Repo: `~/Projects/gm-waitlist` (Cloudflare Worker + D1). Design doc only, nothing
implemented. Grounded by reading `src/server/index.ts`, `src/server/routes/tours.ts`, `src/server/priorities.ts`,
`src/server/terms/waitlist-v1.ts`, `src/server/archive.ts`, `src/server/winback.ts`, `src/server/crm.ts`,
`src/server/enrollment/solace-tasks.ts`, and `migrations/*.sql` (latest applied: 049).

## Load-bearing discovery that changes the brief's assumed approach

**`applications` is closed to new columns.** Migration 033's note and `priorities.ts`'s `chargeRateTier`
comment both say prod `applications` sits at 99/100 of D1's column cap ("too many columns on
sqlite_altertab_applications"). Migration 036 states the precedent explicitly: *"Future
applications-adjacent state must also go in side tables: the base table is effectively full."*
Tour booking itself (migration 043) already followed this rule (`tour_slots` / `tour_bookings` /
`tour_invites` are all side tables, none touch `applications`).

So the brief's suggested `offer_code TEXT, tour_booking_id TEXT, waiver_state TEXT, application_effective_at TEXT`
on `applications` is **not viable** as a plain ALTER. This design uses one new side table
(`tour_waivers`, 1:1 with `applications.id`) instead. This is still additive-only and changes zero
existing columns or rows.

Second discovery that simplifies things: `applications.status` has **no CHECK constraint** (only
`offer_rounds.status` and `tour_bookings.status` are constrained). `status='waiting'` is the literal
flag every capacity/position/forecast/campaign query already filters on (`archive.ts:96`,
`index.ts:3583`, `index.ts:4736`, `campaigns.ts:109/169/211/260`). A brand-new status value,
`pending_tour`, requires **no migration** and is automatically excluded from every one of those
queries, exactly mirroring how `pending_payment` already works pre-fee-payment today (`index.ts`
comment at the INSERT: *"create as pending_payment - NOT on the waitlist until Stripe confirms"*).
Test A reuses that exact mechanic instead of inventing a parallel one.

## State machine (Test A)

```
 [LP: offer=tour-waiver captured, session flag]
                |
                v
        POST /api/tours/book  (existing, unchanged)
                |
                v
   tour_bookings row: status=pending_calendar/confirmed
                |
                v
  POST /api/applications  { offer_code:'tour-waiver', tour_booking_id }
                |
                v
   applications.status = 'pending_tour'   (NOT counted: position/forecast/campaigns
   applications.fee_paid = 0               all filter status='waiting' only)
   tour_waivers row created: waiver_state = 'pending_tour'
   Stripe fee step SKIPPED entirely (no payment-intent created)
                |
        +-------+-------+----------------------------+
        |                                             |
   tour attended                                  tour no-show / cancelled /
   (Ashley marks in Kindred)                       N days elapse, unmarked
        |                                             |
        v                                             v
  waiver_state = 'waived'                    waiver_state = 'expired'
  applications.status -> 'waiting'           applications.status STAYS 'pending_tour'
  application_effective_at = now()           email: "pay $65 to activate, or rebook a tour"
  $65 NEVER charged                                    |
  GA4 gmwl_tour_completed_waiver                +------+------+
                                                 |             |
                                          family pays $65   family does nothing
                                          (normal fee flow)  further M days
                                                 |             |
                                                 v             v
                                          status='waiting'  waiver_state='forfeited'
                                          (fee_paid=1,      applications.archived_at set
                                           standard path)   archive_reason='tour_waiver_forfeited'
```

Six-line version: LP-flagged application enters `pending_tour` (fee skipped, not counted). Tour
attended (Kindred admin mark) flips it to `waived` + activates as `waiting`, no charge, ever. No tour
within N days flips to `expired` and emails a pay-or-rebook choice. No action within a further M days
flips to `forfeited` and archives the shell, same pattern as the existing abandoned-unpaid sweep.

## Migration DDL draft: `migrations/050_tour_waivers.sql`

```sql
-- 050: tour-conditional $65 waitlist-fee waiver (Test A, 2026-07-10 tour-waiver Google Ads test).
-- Side table by necessity, not preference: prod `applications` is closed to new columns
-- (migration 033/036 precedent, confirmed again here at 99/100 columns). One row per
-- application that entered via the tour-waiver offer path; absence of a row = ordinary
-- fee-paid application (the overwhelming majority, unaffected).
--
-- application_effective_at is the SORT-ORDER TIMESTAMP for these rows once activated:
-- ranking queries (rankFor() and the ORDER BY priority_tier ASC, app_date ASC queries in
-- index.ts / email.ts / campaigns.ts / routes/offer-rounds.ts) must LEFT JOIN this table and
-- COALESCE(tour_waivers.application_effective_at, applications.created_at) as the sort key.
-- Recommended default: activation-time ordering (see "Ordering fairness" below - Jarred decision).
CREATE TABLE IF NOT EXISTS tour_waivers (
  application_id            TEXT PRIMARY KEY REFERENCES applications(id),
  offer_code                TEXT NOT NULL DEFAULT 'tour-waiver',
  tour_booking_id           TEXT REFERENCES tour_bookings(id),
  waiver_state              TEXT NOT NULL DEFAULT 'pending_tour'
                             CHECK (waiver_state IN ('pending_tour','waived','expired','forfeited')),
  application_effective_at  TEXT,          -- set once, at waived (activation instant)
  expires_at                TEXT,          -- computed at insert: tour slot_end + N days
  forfeits_at               TEXT,          -- computed at expiry: expires_at + M days
  expired_notified_at       TEXT,          -- pay-or-rebook email stamp (idempotency)
  created_at                TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at                TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tour_waivers_state ON tour_waivers(waiver_state, expires_at);

-- Abuse control: one waiver per family/email EVER, keyed off the tour booking's visitor_email
-- (tour_bookings.visitor_email is already unique-per-active-booking; this adds a durable,
-- never-cleared history check so a family can't waiver, forfeit, and waiver again on a new app).
CREATE TABLE IF NOT EXISTS tour_waiver_email_history (
  email_norm  TEXT PRIMARY KEY,   -- lower(trim(visitor_email))
  first_used_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

State machine constants (propose, Jarred can tune):
- **N = 3 days** after the tour's `slot_end` with no completion mark -> `expired`. (Mirrors the
  existing `ABANDON_GRACE_HOURS=72` precedent in `archive.ts` - same 3-day grace window language
  already in use elsewhere in this codebase.)
- **M = 11 more days** (14 total from tour date) after `expired` with no fee payment and no rebook
  -> `forfeited`, application archived. Mirrors winback A2's 7-day-plus-buffer cadence in `winback.ts`.

## Endpoint / flow changes (file paths)

1. **`src/server/index.ts`, `POST /api/applications`** (the INSERT block around line 1536-1584).
   New branch: if `body.offer_code === 'tour-waiver'`, require `body.tour_booking_id`; validate the
   referenced `tour_bookings` row exists, `status IN ('pending_calendar','confirmed')`, and
   `visitor_email` matches `parent1_email` (case-insensitive) - this is the "waiver only via a real
   tour booking" control, not just an LP flag. Also check `tour_waiver_email_history` for a prior
   entry (abuse control #1) and reject/redirect to the standard fee flow if found. On pass: insert
   `applications` with `status='pending_tour'` instead of `'pending_payment'`, `fee_paid=0`; insert the
   `tour_waivers` row (`waiver_state='pending_tour'`, `expires_at` = booking `slot_end` + N days);
   upsert `tour_waiver_email_history`. Response includes `waiver: true` so the front end (LP lane's
   contract) skips the Stripe fee-collection step in the UI entirely.
   **Also update the two duplicate-check queries at `index.ts:1444` and `index.ts:1587`**
   (`status IN ('pending_payment','waiting')`) to include `'pending_tour'`, or a resubmit during the
   pending-tour window creates a second shell row instead of recognizing the existing one.

2. **`src/server/routes/tours.ts`, `POST /api/tours/book`** - unchanged. The LP lane's front end calls
   this exactly as today; the only new wiring is that its response `bookingId` gets passed as
   `tour_booking_id` into the subsequent `/api/applications` call. No server-side change needed here.

3. **New: `src/server/crm.ts`, `POST /api/crm/families/:key/tour-waiver/complete`** (same
   `crmAuthed()` Bearer-token gate as the existing `/api/crm/families/:key/*` routes at lines
   121/189/225/294). Called by kindred-portal when Ashley marks the admin task done. Effects,
   atomic (single transaction / `db.batch`):
   - `UPDATE tour_waivers SET waiver_state='waived', application_effective_at=datetime('now'), updated_at=datetime('now') WHERE application_id=? AND waiver_state='pending_tour'` (conditional flip, same idiom as the `fee_paid=0` atomic guards elsewhere in `index.ts`).
   - `UPDATE applications SET status='waiting', updated_at=datetime('now') WHERE id=? AND status='pending_tour'`.
   - Fire `gmwl_tour_completed_waiver` via `sendGa4Event` (existing helper, `index.ts:923`), using the
     application's stored `ga_client_id`/`ga_session_id` (migrations 024/026 - already captured at
     application creation, so no new attribution plumbing needed) plus `ga4.userData(email, phone)`
     enhanced-conversions the same way `tours.ts` already does for `gmwl_tour_booked`.
   - Send the family a "you're on the waitlist, no charge" confirmation email (new template
     alongside the existing `buildTourConfirmationEmail` pattern in `tours.ts` / the fee-paid emails
     in `email.ts`).
   - Call `completeEnrollmentTask(env, 'tour_waiver_check', applicationId)` (existing bridge in
     `src/server/enrollment/solace-tasks.ts`, see admin-task shape below) so the Kindred task closes.

4. **New: `src/server/winback.ts` (or a small sibling module `tour-waiver-sweep.ts` following the same
   shape)** - a cron-driven sweep alongside the existing daily 06:00 UTC tick in `index.ts`
   `scheduled()`:
   - `pending_tour` rows past `expires_at` with no completion -> `waiver_state='expired'`,
     `expired_notified_at` stamped, send the pay-or-rebook email (fire `gmwl_waiver_expired`).
   - `expired` rows past `forfeits_at` with `fee_paid` still 0 and no rebook -> `waiver_state='forfeited'`,
     `applications.archived_at`/`archive_reason='tour_waiver_forfeited'` set (reuses the exact
     `archiveStaleUnpaid`-style UPDATE idiom in `archive.ts`, new reason constant only).
   - Same guardrails as `winback.ts`: `WINBACK_ENABLED`-style kill switch, `SANDBOX_MODE` never sends,
     daily cap, 72h quiet window against any other email to the address.

5. **Ranking touch points** (`src/server/index.ts` `rankFor`-style queries, `src/server/email.ts:789`
   area, `src/server/campaigns.ts`, `src/server/routes/offer-rounds.ts`): add
   `LEFT JOIN tour_waivers tw ON tw.application_id = a.id` and order by
   `COALESCE(tw.application_effective_at, a.created_at)` wherever `app_date`/`created_at` currently
   sorts the queue. This is the only place activation-time-vs-submission-time ordering (below) is
   actually enforced.

## Ordering fairness (surfaced per the brief - Jarred decision, not resolved here)

Does a waived application hold its queue position from **submission** (tour booked, application
filed) or from **activation** (tour completion confirmed)? **Recommend activation-time** ordering:
a family that pays the $65 immediately and a family that defers payment behind a tour they might no-show
should not compete on equal footing for the same slot while the second family's fee is still unpaid and
unconfirmed. Submission-time ordering would let a `pending_tour` shell hold a favorable position for up
to N+M days (14) without a dollar changing hands - a real fairness problem against families who paid on
day one. Activation-time ordering is also mechanically simpler: it reuses `application_effective_at`
exactly as `fee_paid_at` already functions as the de facto rank anchor for standard rows. **This needs
Jarred's explicit call before build** - it is a policy question, not an engineering one.

## Clickwrap: waitlist-v2.ts delta (Tier 2 gated, counsel-ready language placeholder)

`waitlist-v1.ts` is silent on any fee-waiver path; its "Non-refundable fee" paragraph assumes the $65
was already charged. A `pending_tour` applicant is asked to accept SOMETHING before their tour, but the
fee language doesn't apply yet. Two options, both requiring a new versioned terms file
(`src/server/terms/waitlist-v2.ts`, same SHA-256 versioning pattern, same "copy the file, don't edit
v1" discipline):

- **Option A (recommended)**: a short conditional-waiver paragraph inserted after "Non-refundable fee":
  *"Tour-conditional waiver. If you arrived through a tour-waiver offer, the $65 waitlist fee is waived
  upon completing your scheduled tour; your application is provisional and not an active waitlist
  position until the tour is completed and the waiver confirmed. If the tour is not completed within
  [N] days, the fee becomes due to activate your position, or you may reschedule."* This is what the
  applicant accepts AT SUBMISSION (before the tour), replacing the "Non-refundable fee" framing
  entirely for this cohort.
- **Option B**: two-stage acceptance - a short "provisional hold" acknowledgment at submission, then
  the existing v1 fee paragraph presented (accept-only, no charge) at activation, framed as "the fee
  that would have applied is waived because you completed your tour."

Recommend Option A (single acceptance, simpler UX, matches the "application only takes effect if you
finalize the tour" framing from Jarred's own words in the directive). **Placeholder text above is NOT
counsel-reviewed - do not ship until counsel signs off, same gate as every clickwrap edit per repo
CLAUDE.md.**

## Tour-completion signal (how the system knows the tour happened)

Three options considered:
1. **Manual mark via Kindred admin task (recommended v1).** Ships fastest, reuses 100% of existing
   infrastructure (`solace-tasks.ts` bridge, `crmAuthed()` pattern, kindred-portal's existing
   admin-task UI). Ashley already walks every tour; a "mark attended" checkbox costs her nothing new.
2. Calendar-event heuristic (e.g. the mini-side tour bridge marks completion when the Google Calendar
   event's end time passes without a same-day cancellation signal from Ashley). Fragile - no positive
   signal that the family actually showed, would need a real no-show reporting habit that doesn't
   exist today.
3. QR/check-in kiosk at 750 N Street. Real infrastructure build, out of scope for a test.

**Recommend option 1.** The admin task is auto-created at booking time (not at tour time), so it
appears on Ashley's list well before the tour date and she marks it same-day.

## Kindred admin-task shape

Reuses the existing `EnrollmentTaskRequest` bridge in `src/server/enrollment/solace-tasks.ts` /
`src/server/enrollment/types.ts` verbatim - only a new `kind` value is needed, no new plumbing:

```
kind: 'tour_waiver_check'                       // new EnrollTaskKind literal
action: 'create'                                 // fired from POST /api/applications, tour-waiver branch
application_id: <the new application id>
child_name: "<child first> <child last>"
title: "Confirm tour attended: waive $65 fee"
description: "Family booked a tour via the waiver offer and applied with the fee deferred.
              Mark attended once the tour happens to activate their waitlist position (no charge).
              If they no-show, the system emails them automatically after 3 days - no action needed
              from you unless they call to reschedule."
checklist: ["Tour occurred as scheduled", "Family attended (not a no-show)"]
priority: 'high'
assignee_role: 'director'                        // Ashley
admin_url: "https://kindred.growingmindfully.org/enrollment/{appId}"
performed_by: 'gm-waitlist-worker'
```

Dedup key: `tour_waiver_check:{application_id}` (same `{kind}:{application_id}` contract as every
other enrollment task). Completing it (`action:'complete'`) is the `completeEnrollmentTask` call inside
the new CRM endpoint above - Ashley's "mark attended" click drives BOTH the task closure and the
waiver activation in one server-side call from kindred-portal, not two out-of-sync systems.

## Abuse controls

- One waiver per family/email: `tour_waiver_email_history` (durable, never cleared, checked before
  the `pending_tour` branch is taken - matches the "one sequence per family EVER" precedent in
  `winback.ts`).
- Waiver only reachable via the LP's `offer_code` flag AND a real, matching `tour_bookings` row
  (email must match) - can't be triggered by a raw API call without first passing the existing
  `/api/tours/book` rate limit and validation.
- `/api/tours/book` rate limit (4 attempts/hour/IP, already in `routes/tours.ts`) is unchanged and
  covers this path since booking is still the first step.
- No stacking: a `pending_tour` application cannot also carry `fee_grandfathered_at` (legacy-vendor
  grandfather) or a second `tour_waivers` row (PRIMARY KEY on `application_id` prevents it).

## GA4 / ads events (server-side via `sendGa4Event`, `index.ts:923`)

All follow the existing sandbox-gated, default-off, best-effort pattern already used for
`gmwl_fee_paid_confirmed` and `gmwl_tour_booked`:
- `gmwl_tour_booked` - **already exists**, fires from `routes/tours.ts` today; no change needed, the
  waiver flow's tour booking IS this event.
- `gmwl_application_pending_tour` - new, fired from the `POST /api/applications` tour-waiver branch,
  params: `offer_code`, `tour_booking_id`, `age_band`.
- `gmwl_tour_completed_waiver` - new, **the success/conversion event**, fired from the new CRM
  complete-waiver endpoint. This should become a new Google Ads conversion action alongside the
  existing `gmwl_fee_paid_confirmed` Purchase conversion (ads-lane's call, not this doc's).
- `gmwl_waiver_expired` - new, fired from the sweep's expiry transition.

## Test B: same-day-enroll $45 enrollment-fee waiver (PHASE 2, thinking-stage only)

**Grounding**: the $45 enrollment fee is NOT a standalone charge today. It's bundled into the
`deposit` Stripe PaymentIntent: `depositAmountCents = (weekly * depositWeeks + ENROLLMENT_FEE_USD) * 100`
(`ENROLLMENT_FEE_USD = 45` constant, `index.ts:580`). This computation is duplicated across at least
six call sites (`index.ts` lines ~1928, ~2192, ~2992, ~4924, ~4995, ~6510 - quote preview, PI creation,
reserve-agreement text, verified-amount checks). There is no separate "$45 enrollment fee" line item or
column anywhere in gm-waitlist; it lives purely inside the deposit total, and its actual collection of
record is Brightwheel (external, manual) per repo CLAUDE.md.

**Design sketch (not to be built this cycle)**:
1. At tour-waiver completion (or any tour completion, not just the waiver cohort), stamp a same-day
   flag if `reserve_date == tour_date` at the moment of reserve: add `enrollment_fee_waived` to the
   `tour_waivers` side table (or a new small side table if Test B ships independent of Test A,
   `tour_completions` keyed by application_id with `tour_date`, `same_day_enroll_eligible`).
2. Wrap all six `ENROLLMENT_FEE_USD` call sites behind one helper, e.g.
   `enrollmentFeeDue(row, waiverFlag): number` returning `0` when the flag is set, `45` otherwise - a
   single choke point instead of touching six formulas independently, first pass toward the actual
   change.
3. If NOT same-day: the $45 is owed and must land on the family's Brightwheel bill. This is a
   **billing-system write and MUST go through the `Bw*` skills / bwlib path** (dry-run -> confirm ->
   execute -> `BwVerify`), never direct API automation from gm-waitlist. Design the handoff only: a
   queued admin/billing task (same `solace-tasks.ts` bridge, new kind e.g. `bw_enrollment_fee_charge`)
   carrying `{application_id, amount_usd: 45, reason: 'not_same_day_tour'}`, picked up by a human/agent
   running the `BwSendInvoice`/`BwBillingPlan` skill chain. **No UI automation, no direct Brightwheel
   API calls designed here** - Jarred-gated per standing rule.
4. Open questions intentionally left unresolved (Phase 2 scope): does "same day" mean tour and
   reservation on the same calendar date in PT, or within N hours? Does the waiver apply only to
   Test-A tour-waiver applicants or to every tour-then-reserve family? Both are Jarred decisions,
   not engineering ones, and don't need answers to finish Test A.

## Effort estimates (S / M / L)

| Piece | Effort | Notes |
|---|---|---|
| Migration 050 (`tour_waivers` + `tour_waiver_email_history`) | S | Pure additive DDL, no touch to `applications`. |
| `POST /api/applications` tour-waiver branch + dedup-query updates | M | New validation branch, two existing-query edits (`index.ts:1444`, `:1587`), response contract change for the LP front end. |
| New CRM `tour-waiver/complete` endpoint | S | Follows `crm.ts`'s existing route pattern almost exactly. |
| Ranking-query updates (COALESCE join, 4 files) | M | Mechanical but touches `index.ts`, `email.ts`, `campaigns.ts`, `routes/offer-rounds.ts` - needs careful regression check against existing position math. |
| Expiry/forfeiture cron sweep | M | New module mirroring `winback.ts` structure; needs its own kill switch + dry-run preview endpoint, same discipline as `winback.ts`. |
| GA4 events (4 new + reuse of 1 existing) | S | All through the existing `sendGa4Event` helper; no new infra. |
| Kindred admin-task kind (`tour_waiver_check`) | S | One new literal in `EnrollTaskKind`, no new bridge code. |
| Clickwrap `waitlist-v2.ts` | S (build) / gated (ship) | Text is a placeholder; counsel review + Jarred Tier-2 sign-off block shipping, not the file itself. |
| Test B design-to-build (Phase 2, not this cycle) | L | Six call-site refactor + a real Brightwheel billing-task handoff design + open policy questions above. |

## Every Jarred gate in this design

1. **Ordering fairness** (submission-time vs activation-time queue position) - policy decision,
   recommend activation-time, not resolved here.
2. **Clickwrap `waitlist-v2.ts` text** - Tier 2 gated (any terms edit), and separately needs counsel
   review before the placeholder language ships.
3. **N (expiry grace, proposed 3 days) and M (forfeiture window, proposed 11 more days / 14 total)** -
   tunable constants, proposed not decided.
4. **New GA4 conversion action for `gmwl_tour_completed_waiver`** in the Ads account - ads-lane's gate,
   noted here because this doc is the event's origin.
5. **Test B same-day definition** (calendar day vs N-hour window) and **whether the waiver applies
   waiver-cohort-only or to all tour-then-reserve families** - both open, Phase 2.
6. **Any Brightwheel billing task execution** arising from Test B - hard Jarred gate per standing rule,
   dry-run -> confirm -> execute -> `BwVerify`, no exceptions, not touched by this design beyond the
   handoff shape.
7. **Production deploy** of any of the above - via `/safe-site-push` only, per repo CLAUDE.md.
```

