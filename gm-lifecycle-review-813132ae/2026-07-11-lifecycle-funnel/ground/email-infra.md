# Ground truth: gm-waitlist email infrastructure (2026-07-11)

Scope: how `~/Projects/gm-waitlist` sends email TODAY, every existing outbound email, the
existing HTML template + "picture style" Jarred references, unsubscribe/suppression state, and
the scheduler/cron that drives automated sends. All file paths absolute. This is what already
EXISTS; the lifecycle T1-T4 build sits on top of it and should reuse it, not rebuild it.

---

## 1. Transport: Postmark PRIMARY, Resend FALLBACK, capture/outbox otherwise

Single chokepoint: `sendEmail(db, env, payload)` in
`/Users/jarredwinn/Projects/gm-waitlist/src/server/email.ts`. Every outbound email in the whole
system goes through it. It is NOT MailChannels/SES/nodemailer/SMTP. Provider ladder (email.ts
lines 174-374):

1. **Postmark** (PRIMARY, prod since launch 2026-07-03). `POST https://api.postmarkapp.com/email`
   with header `X-Postmark-Server-Token: <POSTMARK_TOKEN secret>`. Body: `From, To, ReplyTo,
   Subject, HtmlBody, TextBody, MessageStream` (default `outbound`), optional `Metadata`, optional
   `Headers[]` (List-Unsubscribe + X-GM-Original-To). Best inbox reputation.
2. **Resend** (FALLBACK on ANY Postmark failure incl. plan-cap 429). `POST
   https://api.resend.com/emails`, `Authorization: Bearer <RESEND_API_KEY>`. Same body shape
   (from/to/reply_to/subject/html/text/headers). "A live family's email is never lost."
3. **outbox_only** (`EMAIL_OUTBOX_ONLY=1`, staging): records the row, never POSTs. Sandbox rail.
4. **capture** (no key set): records `provider='capture', status='captured'` for admin preview.

Every path ALWAYS inserts a row into the `emails` table (schema below) regardless of send outcome.
`text` (plain-text alternative) is auto-derived from HTML by `htmlToPlainText()` for multipart
(better Gmail/Apple spam scores).

**Config (prod, wrangler.jsonc env.production.vars):** `POSTMARK_MESSAGE_STREAM="outbound"`,
`PUBLIC_BASE_URL="https://waitlist.growingmindfully.org"`. Secrets (set via
`ops-set-one-prod-secret`, NOT in wrangler): `POSTMARK_TOKEN`, `RESEND_API_KEY`,
`POSTMARK_WEBHOOK_SECRET`, `RESEND_WEBHOOK_SECRET`, `UNSUB_SECRET` (optional; falls back to a
RESEND_API_KEY-derived HMAC key).

**From / Reply-To (email.ts lines 143-144):** `EMAIL_FROM` is NOT set as a plain var (code default
`Growing Mindfully <hello@growingmindfully.org>` unless a secret overrides it). Reply-To default
`enrollment@growingmindfully.org`. Sender domain must be Postmark-verified.

**Delivery-event webhooks (auto-suppression + delivered_at stamping):**
- `/Users/jarredwinn/Projects/gm-waitlist/src/server/routes/postmark-webhook.ts` -> POST
  `/api/postmark/webhook`, header `X-GM-Webhook-Token: <POSTMARK_WEBHOOK_SECRET>`. Suppresses on
  SpamComplaint always + HardBounce; stamps `campaign_sends.delivered_at` via the `gm_send_token`
  Metadata passthrough on the Delivery event.
- `/Users/jarredwinn/Projects/gm-waitlist/src/server/routes/resend-webhook.ts` -> POST
  `/api/resend/webhook`, Svix-signed (`RESEND_WEBHOOK_SECRET`). Same bounce/complaint suppression.

**Incident guards baked in (do not remove):** `EMAIL_OUTBOX_ONLY=1` (staging never delivers);
`EMAIL_TEST_RECIPIENT` reroute is fail-CLOSED on a prod-looking `PUBLIC_BASE_URL` (would be a PII
funnel otherwise); subjects sanitized by `safeSubject()` (CRLF/header-split defense).

---

## 2. Every existing outbound email (all built in gm-waitlist, all via sendEmail)

**Transactional templates - `src/server/email.ts` (builder -> `kind`):**
| Builder | kind | Trigger |
|---|---|---|
| `buildVerificationEmail` | `verification` | email confirm link (72h) |
| `buildVerificationNudgeEmail` | `verification_nudge` | 24h verify nudge (cron) |
| `buildConfirmationEmail` | `confirmation` | on waitlist confirmed + portal link |
| `buildReceiptEmail` (purpose fee\|deposit) | `fee_receipt` / `deposit_receipt` | $65 fee paid / deposit paid |
| `buildConfirmInterestEmail` | `confirm_interest` | re-confirmation prompt |
| `buildPortalResendEmail` | `portal_link_recovery` | family self-serve portal-link resend (`routes/lookup.ts`) |
| `buildEnrollmentConfirmationEmail` | `enrolled` | deposit + agreement complete |
| `buildReserveAbandonEmail` (30m/2h/6h/12h/24h) | `reserve_abandon_<stage>` | signed reserve agreement, deposit unpaid (cron) |
| `buildApplicationReceivedEmail` | `staff_application_received` | INTERNAL staff notice to enrollment@ |
| Enrollment WS7 emails (`src/server/enrollment/emails.ts`) | `enrollment_invite`, `enrollment_item_returned`, `enrollment_phase_reminder`, `enrollment_headstart_nudge`, `enrollment_all_approved` | enrollment flow (director-live, parent-dark) |

**Marketing / winback - `src/server/winback.ts` (daily 06:00 cron sweep, prod DARK `WINBACK_ENABLED=0`):**
- A1 `winback_a1`: applied, never paid $65 (3+ days).
- A2 `winback_a2`: A1 sent 7+ days ago, still unpaid.
- B1 `winback_b1`: email-only lead at overlay, never applied (2+ days).
- C `tour_invite_c`: fee-paid, never reserved, no tour requested (5+ days). TOUR COPY ONLY,
  double-gated `WINBACK_ENABLED` + `TOUR_SEGMENT_C_ENABLED=1`.
Each winback builder appends ONE optional tour-CTA line when a `tourUrl` is passed (`/t/:token`).

**Campaign engine - `src/server/campaigns.ts` (manual, wave-gated, `CAMPAIGNS_ENABLED=1` in prod).**
Registry `CAMPAIGNS` (5 built-in templates today): `reserve-early-access`, `agreement-updated`,
`reserve-invite-apology`, `stall-unpaid-tour` (A1+tour), `stall-lead-tour` (B1+tour). This is the
engine the new lifecycle campaigns should extend (new registry entries), NOT a new mailer.

**Internal/staff kinds (no unsub, no suppression):** `error_alert`, `staff_application_received`,
`staff_enrollment_complete`, `snapshot_alert`, `oncall_backstop`, `chargeback_alert`,
`chargeback_closed`.

---

## 3. THE existing email template + "picture style" (FOUND - Jarred's T4 reference)

Two layers:

**(a) Shared chrome `emailShell(heading, bodyInner, ctaText, ctaUrl, footer?, afterCta?)`**
(email.ts lines 408-440). Every email uses it. Structure, verbatim:
- Outer wrap `background:#eef1ea; padding:26px 12px`, system-ui font stack.
- Card: `max-width:524px; margin:0 auto; background:#fffdf7 (BRAND_PAPER); border-radius:16px;
  box-shadow:0 6px 26px rgba(40,35,25,.09); border:1px solid rgba(42,66,49,.06)`.
- 6px top gradient bar `linear-gradient(90deg,#9BB99E 0%,#6FB8B8 38%,#5FAEB6 64%,#7AA8C4 100%)`
  (BRAND_TEAL_BAR).
- Inner padding `34px 38px`, `color:#2a2a28; line-height:1.62`.
- Centered wordmark `<img src="https://www.growingmindfully.org/assets/wordmark.png" height="40">`.
- `<h2>` heading: `color:#2a4231 (BRAND_GREEN); font-family:'Cormorant Garamond',Georgia,serif;
  font-size:25px; font-weight:600`.
- `${bodyInner}` (arbitrary HTML paragraphs).
- CTA: centered pill `<a>` `background:#3E8E9C (BRAND_CTA); color:#fff; padding:14px 30px;
  border-radius:999px; font-weight:600; font-size:15px; box-shadow:0 6px 16px rgba(42,66,49,.22)`.
  (#3E8E9C clears WCAG AA for white text; brand teal #5FAEB6 does not.)
- Optional `afterCta` slot (below the button).
- Footer: top-border, centered leaf mark `<img src=".../assets/mark.png" width="26" height="26">`
  then muted footer line `Growing Mindfully · enrollment@growingmindfully.org · 750 N Street,
  Sacramento CA 95814` at `color:#9a9590; font-size:12px`.
- `sendEmail` then appends the unsubscribe footer (see 4).

**(b) The "picture style" = the community-photo hero pattern.** Used by the campaign templates
(`reserve-early-access`, `agreement-updated`, `stall-unpaid-tour`, `stall-lead-tour` in
campaigns.ts, and passed as `bodyInner` so it sits above the greeting). Verbatim markup:
```
<img src="https://www.growingmindfully.org/assets/community.jpg"
     alt="Children smiling together on the Capitol lawn"
     width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">
```
Often preceded by a small uppercase trust line:
```
<p style="text-align:center;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;
   color:#6F7F84;margin:0 0 14px">Family founded since 2018</p>
```
**Hero image asset:** `/Users/jarredwinn/Projects/growingmindfully/assets/community.jpg` (224KB,
already live at `https://www.growingmindfully.org/assets/community.jpg`; `community.webp` also
exists). This IS the picture Jarred means. For T4's "DIFFERENT picture," other live hero-quality
assets in the SAME dir: `breathe.jpg`, `joy.jpg`, `play.jpg`, `seated.jpg`, `walk.jpg`, `hero.jpg`
(all ~220-350KB, shipped 2026-07-08). Reference by absolute URL
`https://www.growingmindfully.org/assets/<name>.jpg` at 524px wide, `border-radius:6px`.

**Voice contract (applies to all system/campaign mail):** team voice "we", signed
"With love, The Growing Mindfully team" - NEVER "Best, Jarred" (Jarred 2026-07-07 verbatim: "these
should be from the growing mindfully team, not jarred. ever."). NO em dashes. Greeting on its own
line, a ":)" where natural.

No competing HTML email templates exist in the `growingmindfully` site repo or `kindred-portal`.
kindred-portal only has the Campaigns UI (`src/views/Campaigns/CampaignCreateForm.tsx`,
`src/views/Agenda/TemplatePicker.tsx`) that DRIVES the gm-waitlist engine via the CRM service API;
it holds no email HTML. All email HTML lives in gm-waitlist `src/server/`.

---

## 4. Unsubscribe / suppression state (CAN-SPAM already wired)

`/Users/jarredwinn/Projects/gm-waitlist/src/server/unsubscribe.ts` + `email_suppressions` table.

- **Suppression store `email_suppressions`** (migration 025): PK `email` (lowercased/trimmed),
  `reason` (`unsubscribe|one_click|portal|bounce|complaint|manual`), `source`, `created_at`.
- **Suppression gate** in `sendEmail` (email.ts lines 182-195): any kind NOT in
  `TRANSACTIONAL_KINDS` and NOT in `INTERNAL_KINDS` is checked against the list (ALLOWLIST model -
  a new `campaign`/`newsletter` kind is suppression-checked BY DEFAULT). Suppressed marketing send
  writes an `emails` row `provider='suppression_gate', status='suppressed'` and returns
  `{ok:true, suppressed:true}` - nothing delivered. Transactional mail (receipts, verification,
  offers, reserve-abandon, enrollment) still delivers to suppressed addresses (CAN-SPAM exempt).
- **Three write surfaces:** GET `/unsubscribe?e=<b64url>&t=<hmac>` (footer link, renders a
  CONFIRM page only - GET never mutates, scanner-safe after the 2026-07-05 link-detonation
  incident); POST `/unsubscribe/confirm` + RFC 8058 one-click POST `/unsubscribe`
  (`List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click` headers, Gmail/Yahoo);
  portal toggle POST `/api/portal/:token/email-prefs`. `suppress()` also flips
  `leads.marketing_consent=0`; `unsuppress()` restores it.
- **Token:** `HMAC-SHA256(lowercase email)` with `UNSUB_SECRET` (RESEND_API_KEY-derived fallback).
  Per-address, unforgeable, never expires; timing-safe verify.
- **Footer** auto-appended by `sendEmail` to every non-internal email (email.ts lines 200-207):
  centered muted "Prefer not to get emails from us? Unsubscribe" + the two List-Unsubscribe
  headers. Physical address is in the shell footer (`750 N Street, Sacramento CA 95814`).
- **Leads consent (migrations 009/023):** `leads.marketing_consent` (default 1, implicit consent
  by entering email), `leads.converted`. B1 winback + `stall-lead-tour` require
  `marketing_consent=1`. Lead identity columns for personalization (migration 038):
  `leads.parent1_first`, `leads.child_first` (progressive capture).

**For the new lifecycle emails:** if a new kind is MARKETING, do nothing - the gate covers it
automatically. Only add a kind to `TRANSACTIONAL_KINDS` if it is genuinely service mail about the
family's own in-progress action (as `reserve_abandon_*` was reclassified 2026-07-08). The T1/T3/T4
"reserve your space / waive the fee" promo emails are MARKETING and MUST stay suppression-gated.

---

## 5. Scheduler / cron (Cloudflare Cron Triggers -> `scheduled()` handler)

`wrangler.jsonc`: account is at the **5-cron-trigger limit**. Two triggers only, prod + sandbox:
```
"triggers": { "crons": ["*/10 * * * *", "0 6 * * *"] }
```
(harden worker has `"crons": []` - manual test rig, no sweeps.)

**Dispatcher:** `export const scheduled = async (event, env, ctx)` in
`/Users/jarredwinn/Projects/gm-waitlist/src/server/index.ts` (~line 6749). Runs on the SAME
worker/module as the Hono fetch handler. Every job is isolated in its own try/catch; failures land
in `error_log` via `captureError`. Dispatch logic:

- **Every 10 min (`*/10 * * * *`, and also the 06:00 tick):**
  1. `runReservationReminders(db, env, baseUrl)` (index.ts ~6456): the 30m/2h/6h/12h/24h
     reserve-abandon sequence. Stage table `RESERVE_REMINDER_STAGES` (index.ts ~6430). Idempotent
     per `(application_id, stage)` via `reservation_reminders` table.
  2. `voidExpiredReservations(db)`: 24h null-and-void seat release. Order matters - reminders run
     BEFORE void so the final 24h email still sends.
- **Top of hour only (`minute===0`, gated so `*/10` fires it 1x/hr not 6x):**
  3. `runVerifyNudges(db, env, baseUrl)` (`src/server/verify-nudge.ts`): 24h email-verify nudge,
     cadence-gated per applicant, idempotent.
  4. Tour-bridge liveness watch (only if `TOURS_ENABLED=1`): alerts if the mini availability push
     is >90 min stale.
  5. On-call backstop: emails Jarred if critical `error_log` rows sit un-triaged >30 min.
- **Daily 06:00 UTC (`0 6 * * *`, also minute===0 so it runs the hourly block too):**
  age-6 auto-archive + abandoned-unpaid sweep + daily snapshot/reconcile + **`runWinbackSweep`**
  (the A1/A2/B1/C daily sends; prod DARK). Archive logic in `src/server/archive.ts`.

**Timezone note:** cron is UTC. The T4 "5PM TODAY" waiver rule and all 24h windows must convert to
**America/Los_Angeles** in code (per hard rules) - the cron itself has no TZ awareness.

**Campaigns are NOT on cron.** `runCampaignWave` (campaigns.ts) is driven MANUALLY: admin POST
`/api/admin/campaigns/:id/send` or Kindred service POST `/api/crm/campaigns/:id/send` (Bearer
`CRM_SERVICE_TOKEN`, after a caller-side twofa-relay YubiKey tap). Live send requires
`CAMPAIGNS_ENABLED=1` + explicit `wave` + `confirm:'SEND'` + `approved_via` attestation, capped by
`CAMPAIGN_HOURLY_CAP` (60 prod). **Implication for lifecycle T1-T4:** if the new journey must fire
automatically on a per-family timer (e.g. T1 within 24h of fee-paid, T3 at +24h, T4 at tour-end
+1h), it needs a NEW time-based sweep in `scheduled()` - but the account is at the 5-cron limit, so
piggyback on the existing `*/10` tick (add a gated leg) exactly like reserve-reminders do, rather
than registering a new trigger. A per-family "due at <ts>" queue table + a leg in the `*/10`
dispatcher is the established pattern.

---

## 6. Tracking substrate for the campaign grid (already exists)

The Context Pack's "campaign grid (received / engaged-not-converted / converted)" and drill-level
data map directly onto existing tables:

- **`emails`** (schema.sql line 186): every send. Columns `id, application_id, to_addr, subject,
  body_html, kind, link_path, provider, sent_at, status`. `status` in
  `sent|failed|captured|outbox_only|suppressed`.
- **`campaigns`** + **`campaign_sends`** (migration 032): per-`(campaign, family)` engagement
  ledger. `campaign_sends` columns: `token` (PK, the click/open/webhook key), `campaign_id`,
  `application_id` (or `lead:<email>` / `canary:<uuid>`), `to_addr`, `wave`, `status`, `sent_at`,
  `delivered_at` (Postmark webhook), `opened_at` + `open_count` (pixel), `clicked_at` +
  `click_count`. UNIQUE(campaign_id, application_id) = never double-send.
- **Open/click tracking already built:** open pixel GET `/c/:token/o.gif` (1x1 gif, stamps
  opened_at/open_count); click redirect GET `/c/:token` (stamps clicked_at/click_count, 302s to
  the portal with `utm_source/medium/campaign` + optional `gm_intent=reserve`). Links are wrapped
  through `/c/:token` at send time; pixel appended via `pixelImg()`. Apple MPP inflates opens -
  CLICK is the trustworthy stage; there is a verified-click heuristic (>60s after send + non-
  scanner UA) in `campaignFunnel()`.
- **`campaignFunnel(db, campaignId)`** (campaigns.ts ~785): the 10-stage funnel report
  (sent -> delivered -> opened -> clicked -> fee_started -> fee_paid -> start_date_selected ->
  agreement_accepted -> deposit_started -> reserved) with per-family drill-down, monotonic ladder
  math, reserved-value USD. Served at admin `/admin/campaigns/:id` (+ `?format=json|csv`) and
  Kindred `/api/crm/campaigns/:id/report`. This is the data source for the Kindred grid.
- **`tour_invites`** (migration 036): `subject_type` (application|lead), `subject_key`, `token`
  (UNIQUE), `sent_at`, `clicked_at`. Powers `/t/:token` tour-link tracking (302 to
  `https://www.growingmindfully.org/tour/`, override secret `TOUR_REDIRECT_OVERRIDE` -> raw Google
  `calendar.app.google/uzYtyHyxScntr8W96`). Shared by winback + campaign tourCta templates so one
  family = one tour-link identity.
- **`funnel_events`** (`gmwl_*` events): client-side funnel milestones. The fee-exit winback module
  already fires `gmwl_fee_exit_winback_*` events (offers a tour when a family abandons the fee
  step) - this is the T2 "exit the reserve page -> book-a-tour popup" primitive that already
  EXISTS on the frontend and can be extended.

**Net for the build:** transport, template chrome + picture style, suppression/CAN-SPAM,
open+click tracking, the per-family engagement ledger, the funnel report, and tour-link tracking
are ALL already in place. The lifecycle T1-T4 work is (a) new `CAMPAIGNS` registry entries reusing
the community-photo template with a different picture for T4, (b) a per-family time-based leg added
to the existing `*/10` cron dispatcher (no new trigger - 5-cron limit), TZ-converted to
America/Los_Angeles, (c) the no-show gate reading Kindred/Solace state for T4, and (d) the Kindred
grid reading `campaign_sends` + `campaignFunnel`. Keep marketing kinds suppression-gated; keep the
team voice; no em dashes; nothing licensing-related.
