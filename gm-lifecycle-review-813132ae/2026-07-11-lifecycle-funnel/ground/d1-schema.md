# D1 Schema Ground Truth (gm-waitlist) for the Lifecycle Funnel

Lane: GROUND. Repo: `~/Projects/gm-waitlist` (Cloudflare Worker + D1). Read of `schema.sql` (root,
canonical base through migration 004+025) plus every file in `migrations/` (latest applied: **049**,
`049_enrollment_items_expiry.sql`, 2026-07-10). Purpose: give the design/build lanes the exact
column and table facts the T1-T4 lifecycle, campaign grid, and OPEN ENROLLMENT tour-waiver work must
build against. Hard rule reminder honored throughout: no em dashes; applications is additive-closed;
public flow writes only gm-waitlist-owned tables.

## Latest migration number

- Highest applied: **049**. Next free number for the lifecycle system is **050** (already claimed on
  paper by the tour-waiver design in `2026-07-10-tour-waiver-test/D-waitlist-flow.md`; nothing is
  implemented yet, so 050 is still available to whoever ships first). Note the repo has parallel-numbered
  files from concurrent branches (two 009s, two 025s, two 026s, two 027s, two 032s, two 033s). New
  lifecycle migrations should start at 050 and go up; verify no collision at write time.

## applications table: 99/100 columns, CLOSED (99/100 closure CONFIRMED)

**Confirmed closed.** The prod `applications` table sits at **99 of D1's hard 100-column-per-table
cap**. This is not a style preference, it is a wall prod already hit:

- `migrations/033_tier_review_queue.sql` (header, lines 9-10): the original 5-ALTER version of that
  migration was **REJECTED by prod** on 2026-07-06 (run 28761259550) with the literal D1 error
  `"too many columns on sqlite_altertab_applications"`. It was rewritten as a side table (`tier_reviews`).
- `migrations/036_tour_nudge.sql` (v2 header): states prod applications is "at 99 columns and D1 caps a
  table at 100", and sets the standing precedent: *"Future applications-adjacent state must also go in
  side tables: the base table is effectively full."*
- `migrations/043_tour_booking.sql` (line 13): "Side tables only: prod applications is AT the 100-col
  D1 cap." Migrations 035, 037, 040, 049 repeat the same note.
- `src/server/priorities.ts:47` and `src/server/index.ts:693` both say applications "sits at 99/100 of
  D1's column limit and is closed to new columns."

**Implication for the lifecycle system: you may NOT add a single column to `applications`.** Every new
piece of per-family lifecycle state (T1-T4 send stamps, exit-intent flags, waiver state, no-show
outcome) MUST live in a side table keyed by `application_id` (or by `email` for lead-only families).
There is technically one free column slot left, but the team treats the table as full and DB-level
adds have been rejected before; do not spend it.

### applications columns (full list, 99, as built by schema.sql + ALTERs)

Base (schema.sql, 75 cols through migration 022 + 025-sms interleave): `id, child_first, child_last,
child_dob, age_band, priority_tier, priority_label, parent1_first, parent1_last, parent1_email,
parent1_phone, parent2_first, parent2_last, parent2_email, parent2_phone, employer, building,
days_needed, desired_start, hear_about, sibling_enrolled, sibling_name, note, status, removed_reason,
fee_paid, fee_paid_at, stripe_session_id, stripe_payment_intent, portal_token, email_verified,
email_verify_token, email_verified_at, source, legacy_waitlistplus_id, app_date, last_confirmed_at,
created_at, updated_at, offer_made_at, offer_expires_at, offer_responded_at, offer_response,
contract_status, contract_sent_at, contract_signed_at, contract_signer_name, contract_doc_id,
child_dob_trying, emails_json, verified_state_employee, envelope_id, agreement_signed_at, deposit_paid,
deposit_paid_at, deposit_payment_intent, waitlist_terms_version, waitlist_terms_accepted_at,
waitlist_terms_ip, waitlist_terms_ua, sms_consent, sms_consent_at, deposit_weeks, prepaid_through,
last_verify_nudge_at, verify_nudge_count, deposit_amount_cents, reserve_agreement_version,
reserve_agreement_accepted_at, reserve_agreement_ip, reserve_agreement_ua, reserve_agreement_signer_name,
courtesy_hold_offered_at, reserve_start_date, reserve_voided_at`.

Post-schema.sql ALTERs on applications (chronological, the remainder): `archived_at, archive_reason`
(009), `referral_family` (010), `matched_schedule` (011), `utm_source, utm_medium, utm_campaign,
utm_content, utm_term, gclid, fbclid, attribution_source, attribution_referrer,
attribution_landing_path` (012, 10 cols), `ga_client_id` (024), `ga_session_id` (026),
`tour_requested_at` (026_tour_requested), `winback_a1_sent_at, winback_a2_sent_at` (027_winback),
`tier_verified` (032_tier_verified), `fee_grandfathered_at, fee_grandfathered_note` (033_fee_grandfathered).

Load-bearing columns for the lifecycle work already present on applications (read these, do not
re-add):
- **`status`** TEXT, default `'waiting'`, **NO CHECK constraint** (verified against schema.sql). This
  is the flag every capacity / position / forecast / campaign query filters on (`status='waiting'`).
  New status literals (e.g. `pending_tour`) require NO migration and are auto-excluded from those
  filters, exactly like the existing `pending_payment` pre-fee state.
- **`fee_paid` / `fee_paid_at`** INTEGER/TEXT: the de facto rank anchor and the T1 trigger signal
  (fee paid, no tour = T1).
- **`tour_requested_at`** TEXT (026): in-app "has this family engaged the tour path" proxy. Powers the
  existing fee-exit winback and the post-deposit nudge suppression. Relevant to T2/T3 gating.
- **`winback_a1_sent_at` / `winback_a2_sent_at`** TEXT (027): existing winback send stamps. Precedent
  for how lifecycle stamps work, but these are the LAST two columns the table can afford. T1-T4 stamps
  CANNOT follow this pattern; they must go to a side table.
- **`ga_client_id` (024) / `ga_session_id` (026)**: captured at application creation. Server-side GA4
  events (`sendGa4Event`, `index.ts:923`) reuse these, so lifecycle emails/conversions need no new
  attribution plumbing to stitch back to GA4.
- **`utm_* / gclid / fbclid / attribution_*`** (012): full paid-ad attribution already on the row. The
  ad-variant matrix (V1-V5) attributes through these plus `?offer=` param; no new attribution columns
  needed.

## Tours / booking tables (migration 043, all side tables)

- **`tour_slots`** (`slot_start` PK ISO-8601-with-PT-offset, `slot_end`): availability snapshot,
  full-replace on every mini-bridge push.
- **`tour_slot_meta`** (single-row, `id=1` CHECK; `generated_at, pushed_at, source_calendar,
  windows_version`): staleness guard; stale -> page falls back to phone.
- **`tour_bookings`** (`id` TEXT PK `'tb_'+uuid`; `slot_start, slot_end, visitor_name, visitor_email`
  normalized lower(trim()), `visitor_phone, child_dob, subject_type, subject_key, invite_token,
  status, calendar_event_id, calendar_id, created_at, reconciled_at`).
  - **`status` CHECK IN ('pending_calendar','confirmed','conflict','cancelled')**. IMPORTANT: there is
    **no `attended` or `no_show` state**. Because this is a CHECK constraint, you cannot add those
    literals with a plain ALTER (SQLite would need a table rebuild). The T4 trigger ("tour FINISHED
    unless Ashley marked no-show") therefore needs its **outcome signal in a NEW side table** keyed by
    `tour_bookings.id`, not a status change on this table. See NEW side tables below.
  - Dedupe authority: partial unique index `idx_tour_bookings_slot_active` (one active booking per
    slot) and `idx_tour_bookings_email_active` (one active booking per email). These are
    per-active-booking only, not durable history, which is why the waiver design adds a separate
    durable email-history table.
- **`tour_invites`** (036_tour_nudge; PK `(subject_type, subject_key)`, `subject_type` CHECK IN
  ('application','lead'), `token` UNIQUE, `sent_at, clicked_at, created_at`; plus `tour_booked_at`
  added by 043): one invite EVER per subject, backs the `/t/:token` redirect and the ads-funnel
  invited -> clicked -> booked view.
- **`generic_all_dates_tokens`** (045): tokens for the generic all-dates tour link.

## Holds / capacity / seat tables

- **`reserve_holds`** (016; `hold_id` PK, `application_id` UNIQUE, `age_band, status` default 'held',
  `expires_at, created_at, updated_at`): atomic anti-overbook holds for the self-serve reserve path.
  This plus `waitlist_holds` (the CLAUDE.md-named public-write target) are the ONLY hold surfaces the
  public flow touches.
- **`band_seats`** (019; `age_band` PK, `taken` INTEGER CHECK >=0, `updated_at`): single-row atomic
  seat ledger, seeded with `infant, toddler, young_preschool, preschool`. The claim gates on
  `UPDATE ... WHERE taken < ?` (D1-atomic).
- **`band_capacity`** (005): configured per-band caps.

## Email / notification / campaign tables (this is what the lifecycle system extends)

- **`emails`** (schema.sql; `id` AUTOINCREMENT, `application_id, to_addr, subject, body_html, kind,
  link_path, provider, sent_at, status, created_at`): unified send log, serves both sandbox
  simulation (`status='sandbox_sim'`) and real transactional sends. `kind` drives suppression gating.
  Every lifecycle email lands a row here.
- **`email_suppressions`** (025_email_suppressions; `email` PK lowercased, `reason` default
  'unsubscribe', `source, created_at`): the single source of truth for do-not-market. `sendEmail()`
  drops any non-transactional `kind` for a suppressed recipient (records `status='suppressed'`).
  CAN-SPAM: transactional mail still sends. **The T1-T4 promo emails MUST honor this table** and must
  carry unsubscribe + physical address (hard rule).
- **`campaigns`** (032_campaigns; `id` slug PK, `template, name, email_kind, subject, audience_desc,
  audience_filter` validated JSON age_bands/tiers only, `status` draft|sending|sent, `notes,
  created_by, approved_at, approved_via, created_at`): the campaign registry. The OPEN ENROLLMENT
  tour-waiver campaign and each ad-variant sequence can be a row here.
- **`campaign_sends`** (032_campaigns; `token` PK per-send, `campaign_id, application_id, to_addr,
  wave, status` pending|sent|suppressed, `sent_at, delivered_at, opened_at, open_count, clicked_at,
  click_count`): **the per-recipient engagement ledger. Open+click tracking already exists** (open
  pixel `/c/:token/o.gif`, wrapped-link click redirect `/c/:token`, Postmark Delivery webhook). Cell
  states for the campaign grid map directly: `received` = delivered_at set, `engaged-not-converted` =
  opened_at/clicked_at set but no conversion, `converted` = downstream fee/reserve. Unique index
  `idx_campaign_sends_app (campaign_id, application_id)` guarantees a family gets a campaign at most
  once. NOTE: this table stores FIRST timestamps + counts only, not each individual open/click event.
- **`reservation_reminders`** (022; PK `(application_id, stage)`, stages '30m'|'2h'|'6h'|'12h'|'24h',
  `sent_at`): the row-per-stage idempotency pattern. **This is the exact shape the T1-T4 lifecycle
  send-state table should copy** (one row per fired stage = the idempotency key), since the winback
  column pattern is no longer affordable on applications.
- **`funnel_events`** (013; `id` AUTOINCREMENT, `application_id, event_name, occurred_at, value,
  currency, source, archived_at`; unique `(application_id, event_name)`): per-family funnel mirror of
  the GA4 key events, queryable in-DB independent of GA4. Lifecycle stage events can log here for the
  Kindred grid.
- **`crm_notes`** (035; `id, family_key` = applications.id OR lower(email) for lead-only, `note,
  author, created_at`): free-form staff notes, the CRM person view.
- **`leads`** (023 + 038 progress; `email` PK, `marketing_consent, first_seen_at, last_seen_at,
  seen_count, ip, converted, converted_at, gclid, source` + `parent1_first, parent1_last, child_first,
  furthest_step, progress_at` + `winback_b1_sent_at`): partial-lead capture from the overlay email
  step, addressable for re-engagement. Lead-only families have no `applications` row, so any lifecycle
  logic that can touch pre-application leads must key by `email`, not `application_id`.

## Signature / enrollment / attribution / ops tables (context, not extended by lifecycle)

`signature_events` (027_signature_events, evidence chain), `offer_rounds` + `offer_round_responses`
(007), `waitlist_snapshots` + `snapshot_alerts` (008), `tier_reviews` (033_tier_review_queue),
`start_date_overrides` (039), `enrollment_doc_types` + `enrollment_items` + `enrollment_events` +
`enrollment_status` (040), `enrollment_uploads` (041), `enrollment_doc_masters` (046), `forecast_lkg`
(047), `ads_daily` (037; PK `(date, campaign_id)`, `impressions, clicks, cost_micros, conversions` -
Google Ads daily push, powers cost-per-signup in the Kindred /ads view), plus infra tables
`rate_limits` (021), `admin_users`, `audit_log`, `solace_bridge_outbox`, `error_log`.

## NEW side tables the lifecycle system may add (names free, all additive-only, applications untouched)

The directive (T1-T4 journey, campaign grid, OPEN ENROLLMENT tour-waiver, ad-variant matrix) needs the
following new side tables. Numbers reflect that applications is closed, so all per-family state is
side-tabled and keyed by `application_id` (or `email` for lead-only).

1. **`tour_waivers`** + **`tour_waiver_email_history`** (migration 050, already fully designed in
   `2026-07-10-tour-waiver-test/D-waitlist-flow.md`). Backs OPEN ENROLLMENT (the no-fee tour-waiver
   campaign, directive #1/#4). Fit confirmed below. If the lifecycle system ships first, it should
   claim 050 and carry this DDL.

2. **Lifecycle send-state table** (e.g. `lifecycle_sends` or `journey_sends`). REQUIRED for T1-T4
   idempotency now that winback-style columns can no longer go on applications. Copy the
   `reservation_reminders` shape exactly: PK `(application_id, stage)` where stage IN
   ('T1_reserve','T2_exit_winback','T3_waive_fee_email','T4_tour_promo'), `sent_at`, optional
   `variant`/`campaign_id`. One row per fired stage = the idempotency key. Cron sweep reads this to
   decide next send. This is the single most load-bearing new table for the automated journey.

3. **Exit-intent / T2 event table** (or reuse existing `gmwl_fee_exit_winback_*` events already live in
   GA4 + the existing fee-exit winback module). T2 (exit the reserve page -> "book a tour" popup) can
   likely ride the EXISTING fee-exit winback plumbing; confirm with the ads/site lane before adding a
   table. If a durable server record is wanted, a small `exit_intents (application_id, page, shown_at,
   action)` side table suffices.

4. **Tour-outcome table** (e.g. `tour_outcomes` or `tour_completions`, keyed by `tour_bookings.id`).
   REQUIRED for T4. `tour_bookings.status` has a CHECK constraint with no `attended`/`no_show`
   literal, so the "tour FINISHED unless Ashley marked no-show" signal cannot live on that table. Shape:
   `booking_id TEXT PK REFERENCES tour_bookings(id), outcome TEXT CHECK IN
   ('attended','no_show','cancelled'), marked_by TEXT, marked_at TEXT`. Kindred/Ashley writes it; the
   T4 cron fires the 5pm-today $45-waiver promo 1h after `slot_end` when outcome is not `no_show`. The
   tour-waiver design's `tour_waivers.waiver_state` covers ONLY the waiver cohort; T4 applies to ALL
   tours, so this general table is the cleaner home. Coordinate with the waiver design so the two do
   not double-write completion.

5. **Campaign event log** (optional, e.g. `campaign_events`). `campaign_sends` stores first-open /
   first-click timestamps + counts only. If the Kindred campaign-grid drill-down (directive #3: "sends,
   opens, clicks, timestamps") must show EACH event with its own timestamp/UA/IP rather than
   first-plus-count, add an append-only `campaign_events (token, event_type, occurred_at, ua, ip)`.
   Otherwise the existing rollup columns are enough for received / engaged / converted cell states.

6. **Offer/variant registry** (optional, e.g. `offer_variants` or `ad_variants`). Maps each `?offer=`
   value (V1 open-enrollment, V2 back-to-school, V3 $100+ waived, V4 free tour, V5 $65 waived) to its
   metadata (brand name, waived amount, expiry for "this week only" rotation, which fee-waiver
   mechanic). Enables directive #4's independent comparative conversion tracking of the tour-waiver
   campaign vs standard flow without hardcoding variant logic in the worker. Attribution still rides
   applications.utm_* + funnel_events; this table just names the variants.

## Does the `tour_waivers` DDL design fit? YES, confirmed.

Cross-checked the `migrations/050_tour_waivers.sql` draft in `D-waitlist-flow.md` against actual schema:

- `application_id TEXT PRIMARY KEY REFERENCES applications(id)` fits: `applications.id` is `TEXT
  PRIMARY KEY`. 1:1 side table, additive, touches zero existing columns/rows. Compliant with the
  applications-closed rule.
- `tour_booking_id TEXT REFERENCES tour_bookings(id)` fits: `tour_bookings.id` is `TEXT PRIMARY KEY`.
- `waiver_state` CHECK IN ('pending_tour','waived','expired','forfeited') is a fresh table, so the
  CHECK is fine (no rebuild concern that would exist on tour_bookings).
- The `status='pending_tour'` mechanic requires NO migration: **verified there is no CHECK constraint
  on `applications.status`** (schema.sql line 41). `pending_tour` is auto-excluded from every
  `status='waiting'` capacity/position/forecast/campaign filter, exactly like `pending_payment` today.
- `tour_waiver_email_history (email_norm PK)` is standalone and durable, correctly compensating for
  `tour_bookings`' email-uniqueness being per-active-booking only (partial index), not history.
- The COALESCE ranking join (`COALESCE(tw.application_effective_at, a.created_at)`) is feasible:
  applications has both `app_date` and `created_at`.

**One caveat to flag to the build lane (not a blocker):** the DB-level dedup unique index
`idx_apps_dedup` is partial, `WHERE status IN ('pending_payment','waiting')`. A `pending_tour` row is
therefore NOT covered by DB-level dedup, so a family in `pending_tour` who later also submits/pays
could create a duplicate row unless the app-level duplicate checks are extended (the D design already
calls out updating the `index.ts:1444` and `:1587` queries to include `pending_tour`). If strict
DB-level protection is wanted, `pending_tour` should also be added to the `idx_apps_dedup` partial
predicate (a new index build, additive). App-level handling is the design's chosen path and is
sufficient for the test.

## Hard-rule compliance check for the lifecycle build

- Additive-only, applications closed: satisfied. Every new artifact above is a side table.
- Public flow writes only gm-waitlist-owned tables (waitlist_pipeline/waitlist_holds/reserve_holds/
  etc.), never `children`, never the Solace enroll gate: unaffected. Lifecycle emails and waiver
  activation are worker-owned; the `Enrolled` child row stays manual/Ashley/Jarred-gated.
- Promo emails (T1, T3, T4, OPEN ENROLLMENT) are marketing `kind`: MUST check `email_suppressions` and
  carry unsubscribe + physical address (CAN-SPAM). `campaign_sends`/`emails` already model this.
- Clickwrap terms changes (any `waitlist-v*.ts` bump for the waiver path) = counsel-reviewed Tier 2.
- No em dashes anywhere; no licensing content in any email/LP.
- Timezone America/Los_Angeles for the 5pm T4 rule and all 24h windows (tour `slot_end` carries a PT
  offset already).
