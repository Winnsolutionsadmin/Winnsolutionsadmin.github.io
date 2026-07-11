# Ground Truth: gm-waitlist tours + fees + winback + reserve + drain code

Mapped 2026-07-11 from `~/Projects/gm-waitlist/src` (Cloudflare Worker, Hono, D1). Every
path/line/DDL/event below is verbatim from source. This is the substrate the lifecycle-funnel
(CONTEXT-PACK2) builds ON. Where the directive needs something the code does NOT yet do, it is
flagged **GAP**.

Hosts: public site `www.growingmindfully.org` (overlay embedded on homepage + /rates + /tour/).
Worker API `waitlist.growingmindfully.org` (`GMWL_API_BASE`). Tour page `www.growingmindfully.org/tour/`.

---

## 1. TOURS API  (`src/server/routes/tours.ts`, registered `registerTours(app, makeDb, ga4)` in index.ts)

### Endpoints (public)
| Method | Path | Signature / behavior |
|---|---|---|
| GET | `/api/tours/slots` | `?days=45` (1-90), `?limit=20` (1-120). Returns `{slots:[{start,end,timezone,displayTime}], stale, snapshotAgeMinutes}`. Stale guard 60 min (`STALE_AFTER_MIN`); if snapshot stale OR `TOURS_KILL='1'`, returns `{slots:[],stale:true}` and the /tour/ page falls back to the Google scheduler embed (Layer-0 standby). |
| GET | `/api/tours/next-slots` | `?count=3` (1-10). Top-N open slots for email templates. Same stale/kill guards. |
| GET | `/api/tours/prefill?t=<token>` | Contact prefill from a `tour_invites` token (email one-tap). Returns `{found, name, firstName, email, phone, childDob}`. GET never mutates (email scanners prefetch). |
| POST | `/api/tours/book` | The booking claim. **Double-gated**: `TOURS_KILL!='1'` AND `TOURS_ENABLED==='1'` else `503 {code:'disabled'}`. |

### `/api/tours/book` request body (POST JSON)
```
{ slotStart, name, email, phone?, childDob?, t?(invite token), gaCid?, gaSessionId?, company?(honeypot) }
```
Validation: `slotStart` must match `ISO_RE` (`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$`),
`email` must match `EMAIL_RE`, `childDob` optional `YYYY-MM-DD`. Honeypot `company` non-empty ->
fake `{ok:true}`. Rate brake: **4 attempts/hour/IP** via `rate_limits` table (fail-open), key
`tourbook:<ip>`; over -> `429 {code:'rate_limited'}`. Snapshot must be fresh (`503 stale`); slot must
exist in `tour_slots` (`409 {code:'slot_taken', slots:[...]}`). **No per-slot lock** (migration 044,
Jarred: "we can do multiple tours at the same time worst case") - two families CAN book the same slot;
the only DB constraint is one active booking per email (see index below).

Success response: `{ ok:true, bookingId:'tb_<uuid>', slot:{start,end,displayTime} }`.

### What a booking row stores (`migrations/043_tour_booking.sql`, table `tour_bookings`)
```sql
CREATE TABLE tour_bookings (
  id TEXT PRIMARY KEY,             -- 'tb_' + crypto.randomUUID()
  slot_start TEXT NOT NULL, slot_end TEXT NOT NULL,
  visitor_name TEXT NOT NULL, visitor_email TEXT NOT NULL,  -- email lower(trim())
  visitor_phone TEXT, child_dob TEXT,
  subject_type TEXT, subject_key TEXT, invite_token TEXT,   -- tour_invites linkage when booked via /t/ token
  status TEXT NOT NULL DEFAULT 'pending_calendar'
        CHECK (status IN ('pending_calendar','confirmed','conflict','cancelled')),
  calendar_event_id TEXT, calendar_id TEXT,
  created_at TEXT DEFAULT datetime('now'), reconciled_at TEXT );
-- UNIQUE partial idx: one active booking per slot (status in pending_calendar/confirmed)
-- UNIQUE partial idx: one active booking per visitor_email (status in pending_calendar/confirmed)
```
On book, INSERTed at `status='pending_calendar'`. Email-collision -> `409 {code:'already_booked'}`.

### Booking side-effects (the "update ALL databases" wiring already present)
On successful `/api/tours/book` (tours.ts ~326-367):
1. `UPDATE tour_invites SET tour_booked_at=... WHERE subject_type/key` (funnel stamp invited->clicked->BOOKED).
2. **GA4 Measurement Protocol** event `gmwl_tour_booked` via injected `ga4.sendEvent(env, gaCid||id, ...)` with
   params `{source:'tour_page', method:'email_one_tap'|'page_picker', conversion_type:'winback'|'direct',
   subject_type, slot_start, booking_id, session_id}` + `ga4.userData(email,phone)`. Sandbox-gated + default-off
   inside `sendGa4Event`; the page passes GA4 client/session ids so the conversion stitches to the click session.
3. `funnel_events`: `logFunnelEvent(db, subjectKey, 'gmwl_tour_booked', {source:'tours'})` - **application subjects only**
   (table is application-keyed; `INSERT OR IGNORE`).
4. Confirmation email `kind:'tour_confirmation'` (team voice, "Best, The Growing Mindfully Team", Maps CTA).

### The ashley@ calendar bridge (`scripts/tour-calendar-bridge.py`, launchd ~5 min on mini)
Worker cannot reach Google Calendar. Bridge auth = `Bearer TOURS_BRIDGE_TOKEN` (its own secret, NEVER the CRM token).
- POST `/api/tours/availability` - full snapshot REPLACE: `DELETE tour_slots` then INSERT each `{start,end}` (<=500,
  ISO-validated), upsert `tour_slot_meta` row id=1 with `pushed_at=now`. Body `{slots, generatedAt, sourceCalendar, windowsVersion}`.
- GET `/api/tours/pending` - up to 20 bookings at `status='pending_calendar'` (id, slot, visitor fields) for the bridge to create calendar events.
- POST `/api/tours/reconcile` - body `{bookingId, status:'created', calendarEventId, calendarId}`. Flips
  `status='confirmed'`, stamps `calendar_event_id/calendar_id/reconciled_at`. **No conflict path** (044).
- Calendar events are created by the bridge on the **TEST calendar** until Jarred approves the flip to
  `ashley@growingmindfully.org` (Tier 2 gate). `/tour/` calendar is noindex, 0 internal links (isolation).

### Click-tracking redirect  `GET /t/:token` (index.ts:5704)
Every tour link in outreach is `<base>/t/<24-char-token>`. Stamps `tour_invites.clicked_at` (rate-limited
30/min/IP), then `302` -> `tourRedirectDest(env)` = `TOUR_PAGE_URL` (`https://www.growingmindfully.org/tour/`)
unless `TOUR_REDIRECT_OVERRIDE` secret is set to the raw Google link (`https://calendar.app.google/uzYtyHyxScntr8W96`,
the hot standby). Fixed destinations; never interpolate user input.

---

## 2. FEE FLOW  ($65 waitlist fee)  — `src/server/index.ts`

### Application/fee columns (`applications` table, schema.sql)
`fee_paid INTEGER DEFAULT 0`, `fee_paid_at`, `fee_grandfathered_at` (legacy vendor cohort = settled),
`stripe_session_id` (holds the fee PI id, or `avs_declined:pi_xxx` AVS-retry salt), `stripe_payment_intent`,
`waitlist_terms_accepted_at / _version / _ip / _ua`. Applications table is at 99/100 D1 columns - **CLOSED to new columns** (use side tables).

### State transitions / funnel events
| Event (funnel_events + client GA4) | Fires when | Source line |
|---|---|---|
| `gmwl_fee_started` | Fee PaymentIntent minted (family reached pay screen) | index.ts:2381 (`logFunnelEvent`) |
| `gmwl_fee_paid` | Sandbox mock-pay success | index.ts:2012 |
| `gmwl_fee_paid_confirmed` | Server-confirmed settlement (webhook/poll) | index.ts:3136 |

Client-side (`overlay.js`) also fires `gmwl_waitlist_terms_signed`, `gmwl_step_view` per screen, and the
in-page `gmwl_fee_paid` on card confirm.

### Stripe checkout — actually the Stripe SDK over a FETCH http client (NOT httpx)
`getStripe(env)` (index.ts:541): `new Stripe(key, { apiVersion:'2025-09-30.clover',
httpClient: Stripe.createFetchHttpClient() })`. Accepts `sk_test_`/`sk_live_`/`rk_live_` (restricted live) +
`pk_test_`/`pk_live_`. **NOTE:** CLAUDE.md's "Stripe via httpx" is the design intent for a *standalone Python*
service; the shipped implementation is a CF Worker using the Stripe SDK with a fetch transport. Same
least-privilege posture, different transport. Do not assume an httpx client exists in code.

### `POST /api/stripe/payment-intent/:id`  (index.ts:2052) — dual purpose
Body `{ purpose?('fee'|'deposit'), terms_accepted?, terms_version?, reserve_agreement? }`.
- **purpose='fee' (default):** guards - already-paid short-circuits (`fee_paid || fee_grandfathered_at`);
  clickwrap Waitlist Terms required (`terms_accepted` + `terms_version` must equal `getTermsHash()` or `409 terms_version_mismatch`).
  Creates PI: `amount=effFeeUsd(env)*100` (real $65; SANDBOX_MODE + PRICE_TEST_MODE='1' can force $1),
  `capture_method:'manual'` (authorize-only; `/status` verifies AVS/CVC then captures or voids - ZIP mismatch = void, never charged),
  `payment_method_types:['card']`, `statement_descriptor_suffix:'WAITLIST'`, `metadata{application_id, purpose:'fee', environment}`.
  Idempotency key `fee-<id>` (+ `-retry-<pi>` after AVS decline). Records terms ceremony evidence. Returns `{payment_intent_id, client_secret, amount}`.
- Fee already paid returns `{already_paid:true}`.

### `POST /api/stripe/webhook` AND `/stripe/webhook` (both mounted, index.ts:3395-3396; handler ~3013)
The live Stripe dashboard posts to `/stripe/webhook` (no /api) so BOTH are served. On
`payment_intent.succeeded` for purpose='fee': **atomic** `UPDATE applications SET fee_paid=1, fee_paid_at=now,
stripe_payment_intent=?, status='waiting', (un-archive if abandoned_unpaid) WHERE id=? AND fee_paid=0`.
Race loser changes 0 rows and acks (no double email/bridge). Then: `bridgeEnqueue('fee_paid')`,
`logFunnelEvent('gmwl_fee_paid_confirmed')`, `fireWaitlistAddition()` (the single point that fires the GA4
server-side conversion, so it never double-counts). Unique-constraint collision on the 'waiting' flip ->
`fee_paid` reconciled without status flip, ACK (no 500 retry loop). Poll fallback:
`GET /api/stripe/payment-intent/:id/status` captures the auth and flips the same fields (index.ts:2539+).

---

## 3. FEE-EXIT WINBACK POPUP  (client-side, `src/web/overlay/overlay.js`) — the EXISTING module

This is the browser popup the CONTEXT-PACK calls the "fee-exit winback module" (distinct from the
server-side email `winback.ts` sweep in §5). Item "#9" in the code.

### Trigger (`onUserDismiss`, overlay.js:1335)
When a family tries to dismiss the overlay (X button / backdrop tap / `Esc`), before closing:
- If on a live intake mode (`fresh`/`secure-intake`/`email`), flush draft (`saveDraft`) + `gmwlExitCapture()`.
- **Offer the winback IFF** `!feeWinbackSeen && (step.id==='pay' OR (step.id==='child' && !state.fee_ack))`.
  Shown at most once per session (`feeWinbackSeen`). Any other step/mode closes immediately.
- **GAP for T2:** the reserve-flow screens are MODES (`calendar`, `reserve-disclaimer`, `welcome`), not
  steps, so `currentStepDef()` returns null -> **NO winback fires when a family exits the reserve page today.**
  T2 (reserve-page exit -> book-a-tour winback) is net-new work on this dismiss hook.

### Popup mechanics (`showFeeWinback`, overlay.js:1354)
Builds a top-layer fixed scrim appended to `document.body` (z-index `2147483647` = matches `.gmwl-sheet` max int,
later DOM sibling wins paint so buttons are hittable). Card copy: "Before you go, come see us first? ... Book a
free tour ... We'll hold your place while you decide." Three buttons:
- **"Book a free tour"** (`#gmwl-winback-tour`) -> fires `gmwl_fee_exit_winback_tour`, then POSTs
  `/api/portal/<portal_token>/request-tour` (if a portal token exists on `state._created`), else opens a
  `mailto:enrollment@growingmindfully.org` fallback. Shows "We'll be in touch soon" confirmation, then closes.
  **GAP for T2:** today it calls `request-tour` (queues an admin email), it does NOT route to `/tour/` or book a
  slot. The directive wants it to route to `/tour/` and track the booking - a redirect change here.
- **"Keep going with my application"** (`#gmwl-winback-stay`) -> `gmwl_fee_exit_winback_stay`, removes scrim.
- **"No thanks, exit"** (`#gmwl-winback-leave`) -> `gmwl_fee_exit_winback_leave`, removes scrim + closes.

### Events (all via `gmwlTrackFunnel` -> `gmwlTrack('gmwl_'+name)`)
`gmwl_fee_exit_winback_shown` (:1356), `_stay` (:1380), `_leave` (:1381), `_tour` (:1385).

### GA4/gtag wiring (`gmwlTrack`, overlay.js:746)
Fire-and-forget. Auto-merges attribution `{event_category:'waitlist', source, medium, campaign, gclid, fbclid}`
+ extra params, strips undefined. Path 1: `gtag('event', name, params)` — **only on pages that hardcode
gtag.js (homepage + /rates)**. Path 2: `dataLayer.push` — currently a no-op (GTM container GTM-5FDBM4WK purged
2026-06-24, malware-flagged; kept for a future clean container). Server-side conversions use the GA4
Measurement Protocol (`sendGa4Event`), which is the reliable path for /tour/ + fee-paid.

---

## 4. RESERVE FLOW  (secure-a-space: deposit + agreement)

### Where it lives (page/URL + entry points)
The reserve flow is screens INSIDE the embedded overlay SPA (`overlay.js`), NOT a standalone page. Entry:
1. **Family portal** `/<GMWL_API_BASE>/portal/<portal_token>` (portal.js boots the overlay straight into the
   availability/reserve screen; login-bypass via token in path).
2. **CRM per-family reserve-link** (`POST /api/crm/families/:key/reserve-link`, crm.ts:293): returns
   `<base>/portal/<portal_token>?sdo=<token>` — login-bypass + open-dates (all start days) view. 14-day window,
   one active override per family, idempotent. Moves no money; CRM bearer surface. Also `/api/crm/all-dates-link`
   (family-agnostic `?alldates=<token>`, 3-day).
3. **On-site CTA** "Reserve your space" -> overlay `reserve-question` (3-choice) -> `secure-space`/`calendar`.

Reserve screen modes (`overlay.js`): `reserve-question`, `availability-check`, `secure-space`, `calendar`
(month grid, color-coded by deposit weeks), `reserve-disclaimer` (clickwrap agreement), `welcome` (confirmation).
Reserve funnel events: `gmwl_reserve_disclaimer_signed` (:3708), `gmwl_reserve_deposit_paid` (:3739, the reserve
conversion), plus `gmwl_step_view` mode screens (`reserve_calendar`/`reserve_agreement`/`reserve_welcome`).

### Deposit = the reservation charge  (`purpose='deposit'` on `POST /api/stripe/payment-intent/:id`, index.ts:2066)
Gate ladder (self-serve path, `status='waiting'`):
1. `RESERVE_ENABLED==='1'` else `403 reserve_disabled` (**PROD is DARK / '0' today**; $65 fee + admin-offer deposit paths unaffected).
2. `fee_paid=1 || fee_grandfathered_at` else `403 fee_required` ($65 fee must precede deposit).
3. `email_verified` else `403 email_verification_required`.
4. Reserve clickwrap agreement (`ensureReserveAgreement`, `reserve-agreement-v3.ts`) — `403` if missing.
5. If a DocuSign envelope was issued it must be SIGNED else `409 agreement_signature_required`.
6. Live capacity: `bandAvailabilityAt(env, age_band, desired_start)` per-MONTH forecast + `effectiveOpenSlots`
   (nets in-flight admin offers). `409 space_filled` if none.
7. Atomic anti-overbook `claimReserveHold(db, id, age_band, effOpen)` (writes `reserve_holds`); loser `409 space_filled`.
Admin-offer path (`status IN ('accepted','offered')`) skips availability (admin vetted).

Amount: `effDepositCents(env, (weeklyTuition(age_band, days_needed, effectiveChargeTier(row)) * depositWeeks
+ $45 ENROLLMENT_FEE) * 100)`. `computeDepositWeeks(desired_start)` scales weeks by lead time (JOURNEY.md 0008);
`>1yr out -> 409 not_reservable`. Charged at the family's **RATE tier** (`chargeRateTier`) — a sibling pays their own
employment tier, never the sibling discount (decision #3). PI: `capture_method:'manual'`, `['card']`, 3DS automatic,
`statement_descriptor_suffix:'DEPOSIT'`, idempotency `deposit-<id>-<cents>`. Writes `deposit_payment_intent,
deposit_weeks, prepaid_through`; fires `gmwl_deposit_started`. Succeeded-PI reuse reconciles `deposit_paid=1` (never double-charge).

### Deposit confirm -> reservation complete
Webhook/poll on succeeded deposit PI (index.ts:2522 / 3084): atomic `deposit_paid=1, deposit_paid_at`, writes
`deposit_amount_cents/deposit_weeks/prepaid_through`, fires `gmwl_reserve_deposit_paid` (client) + Tier-3 GA4
conversion, `bridgeEnqueue('deposit_paid')`, and if both legs done `bridgeEnqueue('enrolled')` + enrollment
confirmation email. **Enrolled child row stays MANUAL/Jarred-gated** — the bridge event is an admin task, it never
writes `children` or fires Solace's enroll gate (hard rule).

### Reserve columns
`deposit_paid`, `deposit_paid_at`, `deposit_payment_intent`, `deposit_weeks`, `prepaid_through`,
`deposit_amount_cents`, `reserve_start_date`, `reserve_voided_at`, `agreement_signed_at`,
`reserve_agreement_version/_accepted_at`, `tour_requested_at`. Hold table `reserve_holds` (status `held`/`confirmed`, `expires_at`).

### Reserve EXIT points / abandonment mechanics  (index.ts:6409-6620)
Abandonment clock anchors at `agreement_signed_at` (reserve clickwrap signed, deposit not yet taken).
Eligible when ALL: `agreement_signed_at NOT NULL`, `deposit_paid=0`, `status='waiting'`, `reserve_voided_at NULL`,
active `reserve_holds` row. `runReservationReminders` sends abandoned-cart emails at stages **30m / 2h / 6h / 12h /
23h** (`RESERVE_REMINDER_STAGES`; final at min 1380, ~1h before void), idempotent via `reservation_reminders(application_id,stage)` PK,
`kind:'reserve_abandon_<stage>'`, deep-links `/portal/<token>`. `voidExpiredReservations` (24h null-and-void, agreement
Section 6): releases the held seat (`releaseReserveHold`), stamps `reserve_voided_at`, reverts `status='waiting'`,
clears `agreement_signed_at`, `bridgeEnqueue('reserve_voided')`. Family stays fee-paid on the plain waitlist (only the
reservation leg is undone). Also a 24h `reserve_voided:'deposit_not_funded_within_24h'` path at index.ts:6606.

### request-tour endpoint  `POST /api/portal/:token/request-tour` (index.ts:3710)
Body `{preferred?, note?}`. Rate-limited 8/min/IP. Sets `applications.tour_requested_at=now`,
`bridgeEnqueue('tour_requested')`, emails `enrollment@growingmindfully.org` (all fields HTML-escaped). Does NOT
create a `tour_bookings` row (this is the "raise hand" path the fee-exit popup currently uses; §3 GAP).

---

## 5. SERVER-SIDE EMAIL WINBACK SWEEP  (`src/server/winback.ts`) — distinct from the popup

Daily 06:00 UTC cron (`scheduled` in index.ts). Kill switch `WINBACK_ENABLED` (**PROD='0' dark**). Segments:
- **A1** applied never paid $65 (age>=3d) `winback_a1`; **A2** A1 sent 7+d ago still unpaid `winback_a2`;
- **B1** email-only lead never applied (2+d, `leads.converted=0`, `marketing_consent=1`) `winback_b1`;
- **C** fee-paid, `deposit_paid=0`, `tour_requested_at NULL`, never invited, 5+d after fee -> ONE tour invite
  `tour_invite_c`. **Double-gated** `WINBACK_ENABLED` + `TOUR_SEGMENT_C_ENABLED='1'` (default off). Excludes mid-reserve
  (`reserve_start_date` set — owned by reminders), legacy imports (`source='alllists_legacy'`), Toddler band while full.
Guardrails: `DAILY_CAP=25`, one sequence per family EVER (`winback_*_sent_at` never cleared), 72h quiet window after ANY
email. All kinds NON-transactional: `sendEmail` auto-applies suppression list + CAN-SPAM unsubscribe footer + RFC 8058
one-click headers. Voice = "The Growing Mindfully team" (never signed Jarred). Every email tour CTA is `<base>/t/<token>`.
Tour token shared via `tour_invites` (`ensureTourToken`/`markTourInviteSent`, `mintTourToken` = 24-char base62).
Dry-run (works while dark, sends/stamps nothing): `GET /api/admin/tour-nudge/preview` (adminGuard); single canary
`POST /api/admin/tour-nudge/canary`.

---

## 6. DRAIN / SYNC ENDPOINTS  (mini <-> worker bridge)

### Solace bridge outbox  (`solace_bridge_outbox`, enqueued by `bridgeEnqueue` in db.ts:290)
Every lifecycle transition drops `{event, application_id, ...}` here: `fee_paid`, `deposit_paid`, `enrolled`,
`email_verified`, `tour_requested`, `offer_*`, `reserve_voided`, `tier_*`, `child_docs_sync`, `chargeback_revoke`, etc.
It is an audit/change trail the mini drains. NEVER writes `children` / never fires Solace enroll gate.
- Admin view: `GET /api/admin/outbox` (adminGuard) — last 100 rows.

### Waitlist sync (mini pulls the roster)  `GET /api/internal/solace/waitlist` (index.ts:4758)
Auth `Bearer BRIDGE_SYNC_TOKEN`. Returns `{rows, secured, count, generated_at}`. `rows` = all `status='waiting'`,
non-legacy, with computed `position` (`ROW_NUMBER() OVER (PARTITION BY age_band ORDER BY priority_tier, app_date)`).
`secured` = `deposit_paid=1` within last 14 days (the completion window the mini needs since deposit->enrolled removes
the row from `rows`). Additive keys only (Kindred contract; `solace-mirror.db` schema is additive-only).

### Child-docs / Drive-filing bridge  (`src/server/routes/enrollment-internal.ts`, mounted `/api/internal/solace`)
Auth `Bearer BRIDGE_SYNC_TOKEN`. `GET /child-docs-pending` (outbox rows where `event='child_docs_sync'`,
`delivered_at IS NULL`, limit 20), `GET /child-docs/:appId` (extended bundle), `GET /child-docs/:appId/upload/:uploadId`
(bytes), `POST /child-docs-ack` (body `{outbox_ids[], ok, error}`): on ok stamps `delivered_at`; on the
`enrollment_final_approved` event also stamps `enrollment_status.drive_filed_at` + a `drive_filed` event. Fail path
increments `attempts` + `last_error`. This is the drain-ack idiom every bridge consumer follows (`delivered_at IS NULL` -> ack -> `delivered_at=now`).

---

## 7. KEY GAPS the lifecycle-funnel (CONTEXT-PACK2) must build

1. **T2 reserve-exit winback:** `onUserDismiss` (overlay.js:1348) only fires the popup on `pay`/`child` steps, NOT on
   reserve modes (`calendar`/`reserve-disclaimer`/`welcome`). Reserve-page exit -> book-a-tour popup is net-new on this hook.
2. **T2 route-to-/tour/ + track booking:** the popup's "Book a free tour" button today POSTs `request-tour` (admin email,
   no `tour_bookings` row). Directive wants it to route to `/tour/` and record the booking (reuse `/api/tours/book` +
   `gmwl_tour_booked`).
3. **T4 no-show gate:** `tour_bookings.status` has no `no_show`/`attended` value (CHECK is
   pending_calendar/confirmed/conflict/cancelled). The "1h after scheduled tour END unless Ashley marked no-show in
   Kindred" trigger needs a new attendance signal (side table or additive column) fed from the admin/bridge.
4. **Lifecycle emails T1/T3/T4 are net-new templates:** the existing email surfaces are winback A1/A2/B1/C and
   reserve_abandon_<stage>. T1 ("Reserve Your Space" 24h post fee-paid, no tour) / T3 (+24h waive-fee) / T4 (post-tour
   5PM-today waiver) do not exist yet; T4 must match the existing template shell (`emailShell`) with a DIFFERENT picture.
5. **Campaign grid + open/click tracking:** email opens/clicks are not currently pixel+wrapped-link tracked in `emails`;
   the Kindred per-family x campaign grid (received/engaged/converted drill-down) is new instrumentation.
6. **"OPEN ENROLLMENT!" tour-waiver campaign** is tracked independently (build on `2026-07-10-tour-waiver-test/`
   `tour_waivers` side table + `pending_tour` state machine; applications table CLOSED to new columns).

## Config / secrets referenced
`TOURS_ENABLED`, `TOURS_KILL`, `TOURS_BRIDGE_TOKEN`, `TOUR_REDIRECT_OVERRIDE`, `RESERVE_ENABLED`, `WINBACK_ENABLED`,
`TOUR_SEGMENT_C_ENABLED`, `BRIDGE_SYNC_TOKEN`, `STRIPE_SECRET_KEY`/`STRIPE_PUBLISHABLE_KEY`, `SANDBOX_MODE`,
`PRICE_TEST_MODE`, `GA4_*` (Measurement Protocol), `PUBLIC_BASE_URL`, `ADMIN_EMAIL_DOMAIN`.
Client `/api/config` reports `reserve_enabled`, `payment_mode`, `stripe_publishable_key`.
