# DESIGN: Lifecycle Engine (T1-T4) - the gm-waitlist worker (2026-07-11)

Lane: LIFECYCLE-ENGINE. Owns the per-family state machine, cron scheduler, T1/T3/T4 trigger sweeps,
suppression, 5pm-deadline edges, and $45-waiver precedence. It does NOT own copy (email-* lanes), the
grid (campaign-grid), or the LP/offer registry (data-tracking + ad-variants). Where this doc names a
table or event, data-tracking.md owns its shape and this doc owns its firing logic.

Adopted upstream decisions (do not re-litigate):
- Tables (data-tracking.md canonical): `campaign_sends` + `emails` EXIST; `campaign_events`,
  `lifecycle_sends`, `tour_outcomes`, `offer_variants` are new additive side tables.
- C-1: T2 is a plain book-a-tour winback popup, no $45, no `?offer=` waiver code (the winback-popup
  lane's surface, not a cron send). This engine only records it (section 4).
- C-5: the reserve conversion event is `gmwl_reserve_deposit_paid` (never `gmwl_reserve_confirmed`).
- F0a: migrations 050 + 051 are TAKEN on disk. Lifecycle tables renumber to 052+ (052 tour_waivers, 053
  tour_outcomes, 054 lifecycle_sends, 055 campaign_events, 056 offer_variants, 057 enroll_fee_waivers).
- F0b: a THIRD fee-settled cohort exists (`fee_grandfathered_at`, table-day). "Fee settled" =
  `(fee_paid=1 OR fee_grandfathered_at IS NOT NULL)`, NOT `fee_paid=1`.
- F1: the `CAMPAIGNS` `build(row, urls)` is 2-arg; T4's dated deadline is computed at RENDER time
  inside `build()` from PT wall-clock, never a third arg.

No em dashes. Nothing licensing. Time math America/Los_Angeles. Marketing kinds suppression-gated.
Parent-facing sends Tier-2 Jarred-gated at launch; engine ships dark (`LIFECYCLE_ENABLED=0`).

## 1. Per-family state machine

State is NOT a column. It is DERIVED each `*/10` sweep from existing timestamps plus
`lifecycle_sends(application_id, stage)` idempotency rows (the `reservation_reminders` pattern). "A
stage fired" = a row exists; the family cannot re-enter it. HOOTL agent-owned-deadline model: no human
advances a family, the sweep does, the row is the evidence.

### 1a. States (derived, per application_id)

| State | Predicate (PT) | Next timed action |
|---|---|---|
| `FEE_SETTLED` | `(fee_paid=1 OR fee_grandfathered_at)`, `status='waiting'`, no tour, `deposit_paid=0` | T1 at fee-settle +24h |
| `T1_SENT` | `lifecycle_sends` T1, still no tour, `deposit_paid=0` | T3 at T1 +24h |
| `T3_SENT` | `lifecycle_sends` T3, still no tour | nurture ends |
| `TOUR_BOOKED` | active `tour_bookings` (pending_calendar|confirmed) | T4 at slot_end +1h (outcome-gated) |
| `TOUR_DONE` | `tour_outcomes='attended'` OR unmarked past slot_end+1h | T4 -> waiver window |
| `TOUR_NOSHOW` | `tour_outcomes='no_show'` | T4 suppressed (terminal) |
| `RESERVED` | `deposit_paid=1` / `gmwl_reserve_deposit_paid` | all lifecycle suppressed (terminal) |
| `UNSUBSCRIBED` | `email_suppressions` row | marketing terminal |

(`NEW` = app, no fee settled = owned by winback A1/B1, not this engine.) Transitions are one-way except
entry to `TOUR_BOOKED` from any of FEE_SETTLED/T1_SENT/T3_SENT. Booking a tour STOPS the T1->T3 nurture
(both predicates require "no tour"), so the nurture and tour arms never both run for one family.

### 1b. Which rows encode state (additive-only)

`applications` (READ only, zero new columns; table at 99/100): `fee_paid(_at)`, `fee_grandfathered_at`,
`status`, `deposit_paid`, `tour_requested_at`, `parent1_email/first`, `child_first`. `tour_bookings`
(read): `status`, `slot_end`, `visitor_email`, `subject_type/key`. `tour_outcomes` (read; Kindred
writes no-show). `lifecycle_sends` (WRITE, idempotency ledger). `campaign_sends`/`campaign_events`
(WRITE via shared helper = grid + open/click). `enroll_fee_waivers` (WRITE, section 6). `tour_waivers`
(read, gates T1-B).

### 1c. `lifecycle_sends` DDL (migration 054, copies `reservation_reminders`)

```sql
CREATE TABLE IF NOT EXISTS lifecycle_sends (
  application_id TEXT NOT NULL,
  stage          TEXT NOT NULL
     CHECK (stage IN ('T1_reserve','T3_waive_fee','T4_tour_promo')),  -- T2 is a popup, not here
  sent_at        TEXT NOT NULL DEFAULT (datetime('now')),
  campaign_id    TEXT,          -- CAMPAIGNS registry id used (grid join)
  send_token     TEXT,          -- campaign_sends.token for this send (open/click)
  variant        TEXT,          -- offer_code / cohort the family entered under
  PRIMARY KEY (application_id, stage)
);
```

Idempotency doubles up: the `lifecycle_sends` PK stops the sweep re-selecting a family; the
`campaign_sends` UNIQUE(campaign_id, application_id) anti-join stops a double-send under a concurrent
tick. (F7: redundant for `campaign_sends` stages but kept as the cheap "what stage" read for the grid.)

## 2. Scheduler: piggyback the existing `*/10` cron (no new trigger)

The account is at the 5-cron limit (prod crons `["*/10 * * * *", "0 6 * * *"]`; sandbox + staging +
prod consume all five). A lifecycle timer CANNOT register its own trigger; it adds ONE gated leg to
the existing 10-minute tick, like `runReservationReminders`. No trigger change; only env vars change.

### 2a. Dispatch leg (in `scheduled()`, `src/server/index.ts` ~L6781)

```js
// on the existing "*/10 * * * *" tick; new module src/server/lifecycle.ts
if (env.LIFECYCLE_ENABLED === '1') {
  try { await runLifecycleSweeps(db, env, baseUrl); }
  catch (e) { await captureError(db, 'lifecycle_sweep', e); }  // isolated: never fails the tick
}
```

`runLifecycleSweeps` calls `sweepT1`, `sweepT3`, `sweepT4` in order, each in its own try/catch so a T1
failure never blocks T4. Order gives cadence fairness (T1 before T3). The 10-min cadence lands each
email within 10 min of its due threshold, well inside the 24h / +1h windows.

### 2b. `wrangler.jsonc` delta (env only, NOT crons)

```jsonc
// env.production.vars  (add; crons UNCHANGED)
"LIFECYCLE_ENABLED": "0",          // dark until Tier-2 launch gate
"LIFECYCLE_T1_DELAY_HOURS": "24",
"LIFECYCLE_T3_DELAY_HOURS": "24",
"LIFECYCLE_T4_AFTER_END_HOURS": "1",
"LIFECYCLE_HOURLY_CAP": "40",      // per-tick send ceiling, mirrors CAMPAIGN_HOURLY_CAP
"LIFECYCLE_BACKLOG_GUARD_DAYS": "2" // do not send to families whose trigger ts is older than this
```

### 2c. Timezone handling (America/Los_Angeles)

Cron is UTC; SQLite has no session TZ. Two rules keep it correct without an app-side TZ lib in the
due math:
1. **Due-ness compares are UTC-safe already.** `fee_paid_at`/`sent_at` are stored UTC `datetime('now')`;
   `slot_end` carries an explicit PT offset (`2026-07-11T15:30:00-07:00`) that `datetime()` normalizes
   to UTC. So `datetime(slot_end,'+1 hour') <= datetime('now')` is an exact UTC compare, no JS math.
2. **Wall-clock COPY is PT at render time.** T4's "5PM TODAY" needs a PT date + 5pm boundary; compute
   in `build()` via `Intl.DateTimeFormat('en-US',{timeZone:'America/Los_Angeles',...})` on the send
   instant (section 5). Never pass a precomputed deadline into the 2-arg registry (F1).

### 2d. Idempotent sweep skeleton (all three share this shape)

```sql
-- generic: families DUE for <stage>, not yet sent it, not suppressed, capped
SELECT ...audience cols... FROM <source>
WHERE <due predicate in section 3>
  AND NOT EXISTS (SELECT 1 FROM lifecycle_sends ls WHERE ls.application_id=<app_id> AND ls.stage='<stage>')
  AND NOT EXISTS (SELECT 1 FROM email_suppressions s WHERE s.email=lower(<email>))  -- also gated in sendEmail
ORDER BY <trigger_ts> ASC LIMIT :LIFECYCLE_HOURLY_CAP;
```

The sweep is a pure per-tick re-derivation (no cursor): a restart mid-sweep re-selects the same due set
next tick and the anti-joins prevent double-send. Crash-safe, self-healing on the next pass.

## 3. Trigger implementations

All three send through ONE shared helper `sendTrackedCampaignEmail(db, env, campaignId, row, urls,
wave)` factored out of `runCampaignWave`'s per-family block (F2: token mint + INSERT-first
`campaign_sends` dedup + `/c/:token` wrap + `pixelImg` + Postmark `gm_send_token` metadata live here, so
a cron send lands in the grid like a manual wave). Do NOT copy winback.ts's bare-`sendEmail` (no tracking).

### 3a. T1 - "Reserve Your Space" (fee settled, no tour, +24h)

**Sweep window logic.** "within 24h" is resolved (data-tracking canonical) as a 24h nurture DELAY: T1
fires on the first tick where `now >= fee_settled_at + LIFECYCLE_T1_DELAY_HOURS`, giving the family a
24h self-serve window before the nudge. `fee_settled_at = COALESCE(fee_paid_at, fee_grandfathered_at)`.
(Jarred toggle: delay=1 reads "within 24h" as "promptly." Default 24.)

```sql
-- sweepT1 due predicate
SELECT a.id, a.parent1_email AS email, a.parent1_first, a.child_first,
       CASE WHEN a.fee_grandfathered_at IS NOT NULL AND a.fee_paid=0 THEN 'table_day'
            WHEN tw.waiver_state='waived' THEN 'open_enrollment' ELSE 'standard' END AS cohort
FROM applications a
LEFT JOIN tour_waivers tw ON tw.application_id = a.id
WHERE a.status='waiting' AND a.deposit_paid=0
  AND (a.fee_paid=1 OR a.fee_grandfathered_at IS NOT NULL)          -- F0b: 3 fee-settled cohorts
  AND a.tour_requested_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM tour_bookings tb
                  WHERE lower(tb.visitor_email)=lower(a.parent1_email)
                    AND tb.status IN ('pending_calendar','confirmed'))
  AND datetime(COALESCE(a.fee_paid_at,a.fee_grandfathered_at)) <=
      datetime('now', '-'||CAST(:t1_delay AS TEXT)||' hours')
  AND datetime(COALESCE(a.fee_paid_at,a.fee_grandfathered_at)) >=
      datetime('now', '-'||CAST(:backlog_days AS TEXT)||' days')    -- backlog guard on first enable
  AND NOT EXISTS (SELECT 1 FROM lifecycle_sends ls WHERE ls.application_id=a.id AND ls.stage='T1_reserve')
LIMIT :cap;
```

**OPEN ENROLLMENT cohort mapping (consistency §5).** T1 ships as TWO `CAMPAIGNS` entries so no
fee-settled family is skipped:
- **T1-A** (`fee_paid=1 OR fee_grandfathered_at`): standard + table-day (SQL above); `cohort` tags
  `standard` vs `table_day` for the scorecard (F0b: table-day is a funded VIP/state push, must be
  nurtured not dropped).
- **T1-B** (`fee_paid=0 AND tour_waivers.waiver_state='waived'`): OPEN ENROLLMENT tour-waiver cohort
  (fee waived, already toured, so T1-A excludes them). Its 24h clock runs from `tour_waivers.waived_at`
  (completion-anchored), so it collides with T4 (section 6c).
- **Cohort C (`waiver_state='pending_tour'`)**: intentionally UNCOVERED by T1 (has a booked tour; T4
  reaches them on completion). Accepted gap.

On send: `sendTrackedCampaignEmail(..., 't1-reserve'|'t1-reserve-openenroll', row, {clickUrl,tourUrl},
wave)` then `INSERT lifecycle_sends(...,'T1_reserve',...,variant=cohort)`. CTA is the reserve deep-link
(`portalIntent:'reserve'` -> `/c/:token` -> `/portal/<token>?gm_intent=reserve`).

### 3b. T3 - "Book a tour and waive your enrollment fee" (+24h after T1, still no tour)

```sql
-- sweepT3 due predicate
SELECT a.id, a.parent1_email AS email, a.parent1_first, a.child_first
FROM applications a
JOIN lifecycle_sends t1 ON t1.application_id=a.id AND t1.stage='T1_reserve'
WHERE a.status='waiting' AND a.deposit_paid=0
  AND a.tour_requested_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM tour_bookings tb
                  WHERE lower(tb.visitor_email)=lower(a.parent1_email)
                    AND tb.status IN ('pending_calendar','confirmed'))
  AND datetime(t1.sent_at) <= datetime('now', '-'||CAST(:t3_delay AS TEXT)||' hours')
  AND NOT EXISTS (SELECT 1 FROM lifecycle_sends ls WHERE ls.application_id=a.id AND ls.stage='T3_waive_fee')
LIMIT :cap;
```

T3 is anchored to `t1.sent_at` (clean +24h regardless of when T1 fired). Its CTA carries the $45
waiver: routes to `/tour/`, and the click ATTACHES the waiver by creating the single
`enroll_fee_waivers` row (first-writer-wins, dated; section 6). Offer code `enroll-waiver` is in its
OWN allowlist distinct from the $65 `WAIVER_OFFER_CODES` (consistency C-11) so the $65 branch never
rejects it. T3 fires only for A/table-day (fee settled, $45 the only fee left); B/C have a tour so the
no-tour clause excludes them.

### 3c. T4 - post-tour "reserve by 5PM, we waive the $45" (slot_end +1h, not no-show)

```sql
-- sweepT4 due predicate: booking-anchored, resolves back to an application for the waiver
SELECT tb.id AS booking_id, tb.slot_end, tb.visitor_email,
       COALESCE(app_tok.id, app_email.id) AS application_id,
       COALESCE(app_tok.parent1_first, app_email.parent1_first) AS parent1_first,
       COALESCE(app_tok.child_first, app_email.child_first) AS child_first
FROM tour_bookings tb
LEFT JOIN tour_outcomes o ON o.booking_id = tb.id
LEFT JOIN applications app_tok   ON tb.subject_type='application' AND app_tok.id = tb.subject_key
LEFT JOIN applications app_email ON app_tok.id IS NULL
                                AND app_email.parent1_email = lower(tb.visitor_email)
WHERE tb.status='confirmed'
  AND datetime(tb.slot_end, '+'||CAST(:t4_after AS TEXT)||' hours') <= datetime('now')   -- PT offset normalized
  AND datetime(tb.slot_end) >= datetime('now', '-'||CAST(:backlog_days AS TEXT)||' days')
  AND (o.outcome IS NULL OR o.outcome = 'attended')          -- unmarked = attended (default, section 3d)
  AND COALESCE(app_tok.deposit_paid, app_email.deposit_paid, 0) = 0
  AND COALESCE(app_tok.id, app_email.id) IS NOT NULL         -- must resolve to an app to have a $45 to waive
  AND NOT EXISTS (SELECT 1 FROM lifecycle_sends ls
                  WHERE ls.application_id = COALESCE(app_tok.id, app_email.id)
                    AND ls.stage='T4_tour_promo');
```

Tour END derivation (enrollfee-noshow Part B): `slot_end` is stored at book time (slots Mon-Fri 10:00 +
15:00 PT, 30 min, END 10:30 or 15:30 PT). No duration math, no bridge join; +1h is a pure WHERE clause.

**Family resolution (ground gap 1):** token link first (`subject_type/key`), else
`lower(visitor_email)=applications.parent1_email`. A visitor with NO application resolves NULL and is
EXCLUDED (no app -> no deposit -> no $45; lead-nurture, not T4).

**F3 idempotency:** one T4 per FAMILY (application_id), not per booking, keeping it compatible with the
`campaign_sends` per-application anti-join (low tour volume). `lifecycle_sends(application_id,
'T4_tour_promo')` is the sole key; no `tour_followups` table. Per-booking re-fire flagged, not built.

### 3d. No-show gate (T4 default direction)

The no-show mark is an OPERATING INPUT (Ashley writes `tour_outcomes.outcome='no_show'` via `POST
/api/crm/tours/:bookingId/attendance`), NOT a gate. **Default: UNMARKED = attended -> T4 SENDS**; the
mark only SUPPRESSES a known no-show (HOOTL: the system acts on its +1h deadline, a human can veto but
never authorize). The opposite (hold until `o.outcome='attended'`) is a one-predicate Jarred decision.

## 4. Suppression rules (layered; a send passes only if ALL clear)

First failing gate drops the family with a recorded reason:

1. **Already reserved** - `deposit_paid=1` / `gmwl_reserve_deposit_paid`. Terminal (`AND deposit_paid=0`
   in every sweep).
2. **Already toured** - active/completed `tour_bookings` row suppresses T1 + T3 (no-tour clause). Does
   NOT suppress T4 (T4 IS the post-tour email).
3. **Unsubscribed / bounced / complained** - `email_suppressions` row. Pre-filtered in the sweep SQL
   AND re-enforced in `sendEmail` (T1/T3/T4 are MARKETING kinds, not in `TRANSACTIONAL_KINDS`, so
   unsubscribe footer + physical address + RFC 8058 headers auto-append). Double coverage intentional.
4. **Max-N-per-family** - capped at 3 timed emails ever (T1, T3, T4) by the `lifecycle_sends` PK (one
   per stage). A family gets at most T1+T3 (nurture) OR T1+T4 (tour arm).
5. **One-campaign-per-24h (anti-fatigue)** - `NOT EXISTS (SELECT 1 FROM lifecycle_sends ls WHERE
   ls.application_id=a.id AND datetime(ls.sent_at) > datetime('now','-24 hours'))`. Honors the tighter
   of this and email-infra's global 72h window.
6. **Quiet hours** - no send 20:00-08:00 PT, computed at send time:
   ```js
   const hourPT = Number(new Intl.DateTimeFormat('en-US',
     { timeZone:'America/Los_Angeles', hour:'numeric', hour12:false }).format(new Date()));
   if (hourPT >= 20 || hourPT < 8) return;  // defer, do NOT write lifecycle_sends -> stays due
   ```

Quiet-hours + one-per-24h are checked LAST (per-family, send time) so a deferred family stays due;
reserved/toured/suppressed are in the SQL so they never enter the loop.

## 5. The 5PM-deadline edge cases (T4 copy math, computed at render time)

T4 promises "reserve by 5PM TODAY, we waive the $45." Tours are only the 10:00 or 15:00 PT slot, so
the deadline has two branches from `slot_end` in PT:

- **Morning tour** (slot_end 10:30, T4 fires ~11:30 PT): same-day 5:00 PM gives ~5.5h. Copy "by 5:00
  PM today."
- **Afternoon tour** (slot_end 15:30, T4 fires ~16:30 PT): same-day 5PM is 30 min away, not fair.
  **Rule: `slot_end` after 14:00 PT -> deadline rolls to 5:00 PM PT the NEXT BUSINESS DAY**, copy "by
  5:00 PM {weekday}, {Month} {D}". (Jarred decision: the 14:00 pivot + roll. Default as stated.)

Weekend/holiday: the +1 roll skips Sat/Sun (Friday afternoon tour -> Monday 5PM). Tours are Mon-Fri
only so the source day is never a weekend; only the roll can, and it advances to the next weekday. No
holiday calendar in v1 (a roll erring one day long only makes the offer more generous; later refinement).

Implementation (render-time, inside the 2-arg `build()`, F1-compliant):
```js
function t4Deadline(nowUtc) {                              // nowUtc = send instant
  const pt = zonedParts(nowUtc, 'America/Los_Angeles');    // {y,m,d,hour,weekday}
  const deadline = pt.hour >= 14 ? nextBusinessDay5pmPT(pt) : atPT(pt.y, pt.m, pt.d, 17, 0);
  return { iso: deadline, label: isSamePTDate(deadline, nowUtc) ? 'today' : ptWeekdayDate(deadline) };
}
```
`enroll_fee_waivers.expires_at` (section 6) is set to this same `deadline`, so the email promise and the
charged window are ONE value (urgency stays truthful).

## 6. $45 waiver precedence (one waiver max; which wins)

The $45 is a SINGLE fee inside the deposit PI, read via `enrollmentFeeDue(row, waiver)` (enrollfee-
noshow A4; returns 0 or 45). "Two waivers" never means a double discount (the fee is $0 once); the risk
is two waivers asserting CONTRADICTORY deadlines for one fee (T3 open-ended vs T4 5PM), a false promise
(consistency §4). Resolution: **one waiver STATE per family, first-writer-wins; later triggers READ it.**

### 6a. Single state table (migration 057)

```sql
CREATE TABLE IF NOT EXISTS enroll_fee_waivers (
  application_id TEXT PRIMARY KEY,           -- one row per family = one waiver, ever
  source         TEXT NOT NULL CHECK (source IN ('T3_book','T4_post_tour','V3_stacked')),
  granted_at     TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at     TEXT NOT NULL,              -- the ONE authoritative deadline
  offer_code     TEXT                        -- 'enroll-waiver' (T3) etc, for the grid
);
```

`enrollmentFeeDue` reads this: waiver active iff a row exists AND `datetime(expires_at) >=
datetime('now')`. Read by all 7 fee sites (charge, quote, refund x2, abandon, DocuSign). Written
`INSERT ... ON CONFLICT(application_id) DO NOTHING` = first-writer-wins.

### 6b. Precedence (who writes, who reads)

Writers by journey order: `T3_book` at tour-BOOK (window = tour completion + 48h, dated); `V3_stacked`
at V3 "$100+" reserve entry (window = `offer_variants.expires_at`); `T4_post_tour` at T4 send IF no row
yet (window = 5PM today / next-business-day). **Rule: whoever attaches FIRST owns the deadline; a later
trigger RESTATES it, never overwrites or shortens.** Nurture-then-tour: T3 writes at tour-book, post-tour
T4 finds the row (`ON CONFLICT DO NOTHING`) and RESTATES its `expires_at` ("by 5:00 PM {that date}"),
never a contradictory 5PM-today (fixes consistency §4). Direct-tour (V4, no T3): T4 writes the 5PM
window. V3 stacked: row exists from reserve, T3/T4 restate it. Net: one row per family, one `expires_at`;
T4 READS when a waiver exists, WRITES only when none does.

### 6c. Cohort-B convergence (consistency C-6)

On a cohort-B family's tour completion, T1-B and T4 both go eligible; the 24h anti-fatigue gate lets one
fire. **T4 wins** (time-boxed, higher-intent); T1-B is SUPPRESSED for any family with a tour (`AND NOT
EXISTS (tour_bookings...)` on T1-B). The waiver-confirm transactional email may co-send (CAN-SPAM
exempt); copy lane verifies it is not a third "reserve now" push.

## 7. HOOTL governance (per-component: autonomy / evidence / escalation / kill switch)

| Component | Autonomy class | Evidence at act time | Escalation target | Kill switch |
|---|---|---|---|---|
| `runLifecycleSweeps` dispatch leg | AUTONOMOUS, agent-owned deadlines | each sub-sweep's rows | `#biz-gm-ads` on repeated sweep exception | `LIFECYCLE_ENABLED=0` (env) |
| T1 sweep (A + B + table-day) | AUTONOMOUS, fires at fee_settled+24h itself | `lifecycle_sends` T1 row + `campaign_sends` + `campaign_events` | `#biz-gm-ads` on send-fail streak | `LIFECYCLE_ENABLED=0` |
| T3 sweep | AUTONOMOUS, fires at T1+24h | `lifecycle_sends` T3 + `campaign_sends` + `enroll_fee_waivers` row | `#biz-gm-ads` | `LIFECYCLE_ENABLED=0` |
| T4 sweep | AUTONOMOUS, fires at slot_end+1h | `lifecycle_sends` T4 + GA4 `gmwl_tour_completed` + waiver row | `#biz-gm-ads` | `LIFECYCLE_ENABLED=0` |
| No-show mark | OPERATING INPUT (Ashley), not a gate | `tour_outcomes` row (marked_by/at) | none (optional input) | unmarked=attended default |
| `enroll_fee_waivers` write | AUTONOMOUS (first-writer-wins) | the row + `expires_at` | none | choke point returns full fee if row absent |
| Quiet-hours / anti-fatigue defer | AUTONOMOUS | absence of a `lifecycle_sends` row (stays due) | none | inherent (no send = no harm) |

Mapped to the mandate: **autonomous by default** (no email needs a human; the system owns every
deadline, Ashley's no-show mark is an input not an approval); **closed-loop evidence** (every send writes
`lifecycle_sends` + `campaign_sends` + `campaign_events` at act time, auditable in the grid drill-down =
the spot-check; the weekly scorecard reads these); **single update / single inquiry** (no per-send ping
to Jarred, only the numbered decisions below plus the launch report); **hard gates where they belong**
(Tier-2 stays human: T1/T3/T4 copy, `enrollmentFeeDue` clickwrap/DocuSign bumps, GA4 star + Ads import,
prod deploy); **kill switch, not permission slip** (`LIFECYCLE_ENABLED=0` disables the leg in one flip;
per-stage `lifecycle_config(stage, enabled)` disables T4 alone).

Numbered Jarred decisions (single batched inquiry, one line each):
1. T1 timing: 24h nurture delay (default) vs "promptly within 24h" (delay=1)?
2. T4 no-show default: unmarked = send (default, recommended) vs hold-until-attended?
3. T4 afternoon-tour roll: 14:00 PT pivot -> next-business-day 5PM (default), confirm?
4. $45 T3-branch waiver window: completion + 48h (default) vs another value?
5. Approve T1/T3/T4 parent-facing copy (email lanes) before first live send.

## 8. Retry / failure handling + effort estimates

**Retry / failure.**
- **Transport failure** is handled below the engine: `sendEmail` ladders Postmark -> Resend -> capture.
  If BOTH fail, the helper does NOT write the `lifecycle_sends` marker, so the family stays due and the
  next tick retries; the `campaign_sends` anti-join keeps retry double-send-safe.
- **Sweep exception** -> `error_log` via `captureError`, routed to `#biz-gm-ads`, never Jarred; a single
  family's failure never aborts the sweep (per-family try/catch).
- **Ordering:** send FIRST, then write `lifecycle_sends`. A crash between = at most one duplicate next
  tick, caught by the `campaign_sends` anti-join -> `skipped`. Never write the marker before send.
- **Backlog guard:** `LIFECYCLE_BACKLOG_GUARD_DAYS=2` stops the first `LIFECYCLE_ENABLED=1` flip from
  blasting months of old fee-paid families; older families are left out (a manual wave catches them).

**Effort (S <= 0.5d, M ~1-2d, L ~3-5d):**

| Piece | Size | Note |
|---|---|---|
| migrations 054 `lifecycle_sends` + 057 `enroll_fee_waivers` | S | copy `reservation_reminders` shape |
| `sendTrackedCampaignEmail` helper (factor out of `runCampaignWave`) | M | F2; keep wave callers green |
| `runLifecycleSweeps` + sweepT1/T3/T4 + cron leg | M | core engine: SQL + loop + caps + quiet hours |
| T1-A / T1-B / T3 `CAMPAIGNS` registry entries (wiring; copy is email lanes) | S | 2-arg build drop-ins |
| T4 render-time deadline math (`t4Deadline`, PT, weekend roll) | M | the fiddly bit (section 5) |
| `enrollmentFeeDue` choke point: 7 sites + docusign.ts:117 | L | Tier-2, clickwrap/DocuSign bumps gate it |
| no-show read (`tour_outcomes`), guards, kill switches | S | read-only + predicate helpers + env |

Critical path to a dark-shippable engine (no parent send yet): migrations + shared helper +
`runLifecycleSweeps` + sweeps + guards. The `enrollmentFeeDue` choke point (L, Tier-2) and copy
approval gate T3/T4's live "$45 waived" promise, so build the engine and fire T1 (no waiver claim)
first, add the $45 branch when the choke point lands. All additive-only, `applications` untouched, PT
time math, no em dashes, nothing licensing.
