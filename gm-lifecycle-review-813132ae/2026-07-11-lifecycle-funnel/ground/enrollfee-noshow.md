# Ground: $45 enrollment fee + tour no-show marking + tour END time (2026-07-11)

Grounds three T4-lifecycle-email realities against the live code so the design agents build on
what exists, not on assumptions. Repo: `~/Projects/gm-waitlist` (worker + D1), `~/Projects/kindred-portal`
(admin React). No em dashes. Every claim below is line-cited.

---

## PART A - The $45 enrollment fee: verified call sites

### A0. Test B's claim is CORRECT, and slightly understated
Test B (`2026-07-10-tour-waiver-test/D-waitlist-flow.md:283-289`) said the $45 fee "is NOT a
standalone charge today... bundled into the `deposit` PaymentIntent... duplicated across at least
six call sites (index.ts lines ~1928, ~2192, ~2992, ~4924, ~4995, ~6510)." Verified: all six exist
and match. The true count is **6 references to the `ENROLLMENT_FEE_USD` constant in index.ts, PLUS
a 7th HARDCODED `45` in docusign.ts** that does NOT use the constant (a divergence, flagged below).
So "6-7 call sites" = 7 places the $45 enters money/display math.

### A1. The constant (single definition)
- `src/server/index.ts:580` -> `const ENROLLMENT_FEE_USD = 45;`
- Comment at `index.ts:2943`: "Plus a flat $45 enrollment fee in all reservable tiers."
- The fee has NO column and NO separate line item anywhere in D1. It lives purely inside the
  deposit total. Its collection of record is Brightwheel (external, manual) per repo CLAUDE.md.

### A2. The 7 call sites, categorized

| # | File:line | Role | Category | Money-moving? |
|---|-----------|------|----------|---------------|
| 1 | `index.ts:1928` | Sandbox reserve path: `sandboxDepositCents = effDepositCents(env, (sandboxWeekly * sandboxDepositWeeks + ENROLLMENT_FEE_USD) * 100)`. Persisted to `applications.deposit_amount_cents`. | **CHARGE** (sandbox/test path) | yes (test $) |
| 2 | `index.ts:2192` | Real Stripe reserve path: `depositAmountCents = effDepositCents(env, (weekly * stripeDepositWeeks + ENROLLMENT_FEE_USD) * 100)`. This is the amount of the LIVE deposit PaymentIntent. | **CHARGE** (production) | **yes (real $)** |
| 3 | `index.ts:2992` + `:3005` | `GET /api/quote/:applicationId`: `totalDeposit = weekly * depositWeeks + ENROLLMENT_FEE_USD` (2992) and the response field `enrollment_fee_usd: ENROLLMENT_FEE_USD` (3005). Feeds the "YOUR DEPOSIT" banner + overlay quote card. | QUOTE / display | no |
| 4 | `index.ts:4924` | `GET /api/admin/tier-reviews` list: recomputes `verifiedCents = (weeklyTuition(...) * weeks + ENROLLMENT_FEE_USD) * 100` to show Ashley the refund delta before she verifies a discount tier. | REFUND MATH (display) | no |
| 5 | `index.ts:4995` | `POST /api/admin/application/:id/verify-tier`: same `verifiedCents` recompute; `creditCents = max(0, charged - verifiedCents)` is the amount auto-refunded on the deposit PI when a tier is verified. | **REFUND MATH (moves $)** | yes (refund) |
| 6 | `index.ts:6510` | Reserve-abandon reminder email: `depositDollars = weekly * depositWeeks + ENROLLMENT_FEE_USD` for the "deposit owed" line in the nudge email. | EMAIL display | no |
| 7 | `routes/docusign.ts:117` | `enrollment_fee: 45` HARDCODED in the DocuSign enrollment-agreement quote object; rendered at `docusign.ts:156` (`enrollmentFeeSummary`) + `:169`. Does NOT reference `ENROLLMENT_FEE_USD`. | AGREEMENT display | no |

Wrapper detail: sites 1 and 2 pass through `effDepositCents(c.env, ...)`, the reversible `TEST_PRICING`
override (index.ts:580-590 region) that substitutes the CHARGED cents on non-prod origins only. Site
3's total goes through `effDepositUsd(c.env, totalDeposit)`. A waiver must sit INSIDE these formulas
(before the eff* wrapper), not after.

### A3. The clickwrap + agreement copy that also states the $45 (not arithmetic, but must stay truthful)
- `src/web/overlay/overlay.js:2716, 2722, 3593, 3594` - the reserve overlay's deposit sub-copy and
  the binding `ack-prepayment` clickwrap checkbox both say "separate one-time $45 enrollment fee...
  is not refunded if I cancel." Changing what's actually charged WITHOUT updating this text is a
  clickwrap/terms mismatch (Tier 2, counsel-reviewed version bump per CONTEXT-PACK2 hard rules).
- `src/server/agreement-template.ts:53` (`enrollment_fee: number; // 45`), `:63`
  (`total = weekly_tuition * deposit_weeks + enrollment_fee + waitlist_fee`), `:194`, `:204-205`,
  `:335` - the rendered reserve agreement's fee line + total + non-refundable attestation.
- `src/server/terms/reserve-agreement-v1.ts:13,24`, `v2.ts:33`, `v3.ts:39,41` - hashed clickwrap
  terms text naming the $45. These are SHA-256 versioned; editing = a new `reserve-agreement-v4.ts`
  copy-on-change file + counsel + Jarred gate. A T4 "waive the $45" offer that changes the charged
  amount but NOT the signed terms would have the family sign a doc stating a fee they weren't charged.
- `src/web/portal/portal.js:792-793, 800` - portal quote card "Enrollment fee $45" display.

### A4. What "waive the $45" (T4 promo) concretely requires
The waiver is NOT a copy change alone; it changes the deposit PI amount at site 2 (and the sandbox
mirror at site 1), the quote at site 3, the two verify-tier refund computations at 4/5 (or they will
compute the wrong refund delta for a waived family), the abandon-email line at 6, and the DocuSign
agreement at 7. Test B's recommended shape holds (`D-waitlist-flow.md:296-298`): introduce ONE choke
point, e.g. `enrollmentFeeDue(row, waiverFlag): number` returning `0` when waived else `45`, and route
all 7 sites through it, instead of editing 7 formulas independently. The waiver flag itself is a
side-table state (Test A's `tour_waivers` / a `tour_completions` row keyed by application_id), never a
new `applications` column (that table is at the 100-col D1 cap, closed - `043_tour_booking.sql:13`).
Any of this is a Tier-2 waitlist-mutation + clickwrap change: build unattended, ship gated.

---

## PART B - Tour scheduled END time (how T4's "1h after tour END" is known)

**The END time is already stored per booking. No duration math is needed at send time.**

- `tour_bookings.slot_end TEXT NOT NULL` (`migrations/043_tour_booking.sql:34`) - ISO-8601 with PT
  offset, same format as `slot_start`. Copied straight from the availability snapshot at book time
  (`routes/tours.ts:290-317`: the handler SELECTs `slot_start, slot_end` from `tour_slots` and INSERTs
  both into `tour_bookings`).
- Slot duration = **30 minutes**, defined mini-side in the calendar bridge:
  `scripts/tour-calendar-bridge.py:70` -> `SLOT_MINUTES = 30`; `:175` -> `end = start + timedelta(minutes=SLOT_MINUTES)`.
  The bridge computes each window's end and pushes `{start, end}` pairs to `POST /api/tours/availability`
  (`tours.ts:379-421`), which stores them in `tour_slots(slot_start PK, slot_end)`.
- Windows: Mon-Fri 10:00 + 15:00 PT, 30 min (`043_tour_booking.sql:6`, bridge `:68`). The
  confirmation email hardcodes the human phrase "a 30 minute tour" (`tours.ts:134`).

**T4 trigger math (no-show gate aside):** for a `tour_bookings` row with `status='confirmed'`,
fire the promo email when `datetime(slot_end) + 1 hour <= now`. Because `slot_end` is a stored
column, the sweep is a pure `WHERE` clause - no join to the bridge, no duration constant in the worker.

**Where the sweep hooks in:** the Cloudflare account is at its 5-cron-trigger limit
(`wrangler.jsonc:33,42` -> crons `["*/10 * * * *", "0 6 * * *"]`), so a T4 sweep must PIGGYBACK on
the existing every-10-min tick, not add a trigger. It mirrors `runReservationReminders`
(called at `index.ts:6781` inside the `scheduled()` handler; the reminder pattern is at
`index.ts:6426-6540`, idempotent via a `(application_id, stage)` row in `reservation_reminders`).
A `runTourFollowups(db, env, baseUrl)` would select due `confirmed` bookings, skip no-shows +
already-sent, send, and stamp a sent-marker (new `tour_followups` side table, same idempotency idiom).
The 10-min cadence lands the email within 10 min of the +1h threshold - acceptable. All time logic in
`America/Los_Angeles` (the "reserve by 5PM TODAY" copy is PT; `tours.ts:66` `PT = 'America/Los_Angeles'`).

---

## PART C - How Ashley marks a tour no-show (REALITY: nothing exists yet)

### C0. Hard truth
There is **NO no-show marking anywhere today.** Grep for `no_show` / `no-show` / `noShow` across
BOTH `gm-waitlist/src` and `kindred-portal/src` returns zero hits. Specifically:
- `tour_bookings.status` CHECK allows ONLY `('pending_calendar','confirmed','conflict','cancelled')`
  (`043_tour_booking.sql:42-43`). There is no `attended` / `no_show` / `completed` state and no
  attendance column.
- `kindred-portal` has NO tour-bookings view. Its only tour surface is the Ads Funnel
  (`src/api/adsFunnel.ts:36-40`, `src/views/AdsFunnel/AdsFunnelView.tsx:225-227,577-585`), which shows
  `tour_requested / tour_invited / tour_clicked` derived from `tour_invites` (the OLD Google-scheduler
  nudge funnel), NOT actual `tour_bookings` and NOT attendance.
- `gm-waitlist` has NO admin endpoint that lists or mutates `tour_bookings`. The only admin tour
  endpoints are `GET/POST /api/admin/tour-nudge/preview|canary` (`index.ts:5720,5725`) - the legacy
  nudge campaign, unrelated to booked-tour attendance.
- `solace-tasks.ts` (the "task bridge" named in the brief) is **ENROLLMENT-ONLY**. Its task kinds
  are `enroll-review | enroll-file | enroll-final | enroll-critical` (`enrollment/types.ts:555-558`),
  it POSTs to solace-api `POST /tasks/enrollment` on the mini (`solace-tasks.ts:31`), and tour
  bookings do NOT flow through it. There is no tour task kind and no tour->Solace bridge at all.

So T4's "unless Ashley marked no-show in GM admin (Kindred)" describes a surface that must be BUILT.
Below are the two mapped paths, grounded in the existing patterns each would reuse.

### C1. Path 1 (RECOMMENDED, matches Jarred's "in GM admin (Kindred)") - Kindred admin surface
A new Tours view in kindred-portal + a gm-waitlist CRM endpoint, reusing the exact enrollment-review
pattern that already exists for "Ashley marks X":

1. **Additive migration `050_tour_attendance.sql`** (next number; 049 is latest). tour_bookings is a
   SIDE table, so this is allowed (not the closed applications table). SQLite CHECK on the existing
   `status` column cannot be altered without a table rebuild, so ADD a separate column instead:
   ```sql
   ALTER TABLE tour_bookings ADD COLUMN attendance TEXT
     CHECK (attendance IN ('attended','no_show'));  -- NULL = outcome not yet marked
   ALTER TABLE tour_bookings ADD COLUMN attendance_marked_at TEXT;
   ALTER TABLE tour_bookings ADD COLUMN attendance_marked_by TEXT;  -- x-staff-email actor
   ```
2. **gm-waitlist CRM read + write endpoints** (Bearer `CRM_SERVICE_TOKEN`, actor from `x-staff-email`
   - the identical auth the enrollment CRM uses, `routes/enrollment-crm.ts:2,27`):
   - `GET  /api/crm/tours` -> confirmed/past bookings for the admin list (name, email, slot_start,
     slot_end, attendance, subject linkage).
   - `POST /api/crm/tours/:bookingId/attendance` body `{ attendance: 'attended' | 'no_show' }` ->
     sets the three columns; actor = `x-staff-email` (default `'kindred'`). Mirrors the
     `POST /api/crm/enrollment/:appId/items/:docKey/review` action verb pattern
     (`enrollment/types.ts:380-389`).
3. **Kindred UI**: a Tours list (new `src/views/Tours/` + `src/api/tours.ts`) with an Attended /
   No-show toggle per row, calling through the same-origin `/crm-api/*` proxy that injects the bearer
   (`kindred-portal/vite.config.ts:29-36`, rewrites `/crm-api` -> `/api/crm`). This is parent-adjacent
   ops data, not parent-facing copy; the marking action itself is low-risk, but it GATES a
   parent-facing promo send, so treat the whole T4 chain as Tier-2 surfaced to Jarred.
4. **T4 sweep reads the flag**: `runTourFollowups` (Part B) sends only when `attendance IS NULL OR
   attendance = 'attended'` and skips `attendance = 'no_show'`. Null-safe default: an UNMARKED tour is
   treated as attended (email sends) unless Ashley affirmatively marks no-show. If Jarred wants the
   opposite (no email until Ashley confirms attended), flip the predicate - a one-line policy choice
   the design doc should call out explicitly.

### C2. Path 2 (the solace-tasks bridge angle named in the brief) - task-driven confirmation
Instead of (or alongside) a toggle, create a Solace /agenda task 1h after `slot_end` asking Ashley to
confirm the tour outcome; her completing it as attended/no-show writes back the attendance flag. This
reuses `solace-tasks.ts` but requires EXTENDING the frozen task contract:
- Add a task kind e.g. `tour-outcome` to `EnrollTaskKind` (`enrollment/types.ts:555-558`) and a dedup
  key `tour-outcome:{bookingId}` (`types.ts:596-609` pattern). NOTE: this contract is FROZEN
  (WS0, Jarred 2026-07-08, `types.ts:3`); a change fans out through the WS0 owner + the solace-api
  `POST /tasks/enrollment` handler on the mini. Heavier than Path 1.
- The task's completion must round-trip back to gm-waitlist to set `attendance` (Solace would call a
  gm-waitlist endpoint, or the mini poller carries it). solace-tasks.ts today is fire-and-forget
  create/complete (`solace-tasks.ts:45-62`) with NO inbound attendance channel - that channel is net-new.
- Verdict: Path 2 is the right shape ONLY if Ashley already lives in the Solace /agenda and won't open
  Kindred for tours. Given Kindred is the named "GM admin" and already has the CRM auth + React shell,
  **Path 1 is materially less work and less contract risk.** Path 2 can be a later add (a task that
  deep-links to the Kindred toggle) without blocking T4.

### C3. Calendar-native alternative (worth surfacing, lowest-friction for Ashley)
Ashley's tours are real Google Calendar events (the bridge creates them, `docs/tour-booking.md:35-36`,
`tours.ts:450-474` reconcile). The bridge already does a two-way sync (push slots, pull pending, report
reconcile). It could ALSO read an attendance signal Ashley sets natively on the event (e.g. she declines
/ colors / prefixes the title "NOSHOW") and POST it to a new `POST /api/tours/attendance` bridge endpoint
(Bearer `TOURS_BRIDGE_TOKEN`, same auth class as `/reconcile`). Pro: zero new UI, Ashley marks in the
tool she already uses. Con: relies on a manual calendar convention + a bridge parse; less auditable than
an explicit Kindred button. Recommend Path 1 as system-of-record with C3 as an optional convenience input.

---

## Gaps / risks the design agents must resolve
1. **Matching a tour back to a waitlist family for the $45-waiver CTA.** A `tour_bookings` row links to
   an application only when booked via an invite token (`tours.ts:298-305,313-317`: `subject_type` /
   `subject_key`, else NULL). Direct page-picker bookings have only `visitor_email`. T4's "reserve your
   space and we waive the $45" only makes sense for a family who then RESERVES (pays a deposit), which
   requires an `applications` row. Design must specify: token-linked -> use the application; email-only
   -> match `lower(visitor_email)` against `applications.parent1_email`, and handle the no-match case
   (a tour visitor with no waitlist app cannot have a $45 deposit waiver because there's no deposit).
2. **The waiver actually changing the charge (Part A4)** touches the live deposit PI, the signed
   clickwrap terms, and the DocuSign agreement - all Tier-2, counsel + Jarred. The email can PROMISE
   the waiver before the plumbing lands, but the charge won't reflect it until the `enrollmentFeeDue`
   choke point ships. Do not send a "$45 waived" promo while site 2 still bills the full $45+deposit.
3. **docusign.ts:117 hardcodes `45`** instead of `ENROLLMENT_FEE_USD` - fold it into the choke-point
   helper in the same change, or a waived family's agreement will still print a $45 fee line.
4. **5-cron limit** - the T4 sweep cannot add a trigger; it piggybacks the 10-min tick (Part B).
5. **No-show default direction** (C1.4) is a policy decision Jarred should make: unmarked = send, or
   unmarked = hold. Affects false-positive promo sends to families who actually no-showed but weren't
   marked in time.

## Key file references
- `~/Projects/gm-waitlist/src/server/index.ts` (constant :580; charge :1928,:2192; quote :2992,:3005;
  refund :4924,:4995; abandon email :6510; cron scheduled + reminder sweep :6769-6803, :6426-6540)
- `~/Projects/gm-waitlist/src/server/routes/tours.ts` (booking, slot_end persist, reconcile)
- `~/Projects/gm-waitlist/src/server/routes/docusign.ts:117,156,169` (hardcoded 45)
- `~/Projects/gm-waitlist/src/server/enrollment/solace-tasks.ts` + `enrollment/types.ts:555-609` (task bridge, frozen contract)
- `~/Projects/gm-waitlist/migrations/043_tour_booking.sql` (tour_bookings DDL; status CHECK :42-43)
- `~/Projects/gm-waitlist/scripts/tour-calendar-bridge.py:70,175` (SLOT_MINUTES=30, end = start+30)
- `~/Projects/gm-waitlist/wrangler.jsonc:42` (crons); `~/Projects/gm-waitlist/docs/tour-booking.md`
- `~/Projects/kindred-portal/vite.config.ts:29-36` (/crm-api proxy + bearer); `src/api/adsFunnel.ts`,
  `src/views/AdsFunnel/AdsFunnelView.tsx` (only existing tour surface)
- `~/Projects/kindred-portal/src/api/enrollment.ts` + `gm-waitlist/src/server/routes/enrollment-crm.ts:27` (the "Ashley marks X" pattern to clone)
