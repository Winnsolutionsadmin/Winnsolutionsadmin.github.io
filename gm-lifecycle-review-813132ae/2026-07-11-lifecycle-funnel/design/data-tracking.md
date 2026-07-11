# DESIGN: Data + Tracking Architecture - GM Lifecycle Funnel (2026-07-11)

Lane: DATA-TRACKING. This is the canonical data-model and instrumentation layer that every other
lane consumes. It owns: (1) the campaign-touch / email-event table set (DDL); (2) tour-booking
propagation so one booking updates ALL surfaces; (3) the open-pixel + click-redirect endpoints
(signatures, token design, bot filtering); (4) the complete GA4 event map + gtag wiring per LP
variant; (5) per-variant attribution (utm conventions + the `?offer=` registry).

Builds on ground: `d1-schema.md`, `email-infra.md`, `ga4-ads-state.md`, `tours-fees-code.md`,
`enrollfee-noshow.md`, `kindred-portal.md`, `site-lp-conventions.md`, `waiver-package.md`.
Consumed by siblings: `campaign-grid.md` (renders the grid off these tables), `ad-variants.md`
(defines the `?offer=` creative codes this registry stores), the T1-T4 email design docs (write
into these ledgers). Where a sibling names a table or event, THIS doc is the source of truth for
its shape; where copy or UI, theirs is.

Nothing here executes. Every DDL is additive-only side tables (the `applications` table is CLOSED
at 99/100 columns). No em dashes. No licensing text. Marketing sends stay suppression-gated. Any
parent-facing send, clickwrap, budget, or prod deploy is a Tier-2 Jarred gate; the data plumbing
below is Tier 0/1 build-unattended.

---

## 0. Naming reconciliation (the directive's tables vs what already exists)

The lane brief asked for "a `campaign_touches` side table and `email_sends`/`email_events` tables."
Two of those three ALREADY EXIST under different names, and rebuilding them would violate the
additive-only rule and orphan the open/click plumbing that is already live. The mapping:

| Directive name | Canonical table | Status | Role |
|---|---|---|---|
| `campaign_touches` | **`campaign_sends`** (migration 032) | EXISTS | one row per (family, campaign) = the touch; first-timestamps + counts |
| `email_sends` | **`emails`** (schema.sql) + `campaign_sends` | EXISTS | `emails` = every raw send row; `campaign_sends` = the trackable marketing send |
| `email_events` | **`campaign_events`** (NEW, this doc) | TO BUILD | append-only per-event log: one row per delivered/open/click/bounce |

Decision: **reuse `campaign_sends` as the touch ledger; add ONE new append-only `campaign_events`
table for per-event granularity.** `campaign_sends` already stores the state the grid needs
(received/engaged/converted via `delivered_at`/`opened_at`/`clicked_at`) and is already exposed to
Kindred's `FamilyDetail` as `campaign_touches[]` (kindred-portal ground 6). It is literally the
`campaign_touches` table under its shipped name. `campaign_events` exists only to answer the grid's
drill-down "show EACH open/click with its own timestamp" (directive #3) that the rollup columns
cannot. Everything else is reuse.

---

## 1. Canonical data model

### 1a. EXISTING - `campaign_sends` (migration 032 + 034), do NOT recreate

The per-touch ledger. Documented here because it is the spine the grid and the lifecycle emails
write into. Verbatim shape (gm-waitlist `migrations/032_campaigns.sql:31-49`, `+034` added the
`last_open_ua`/`last_click_ua` columns):

```
campaign_sends(
  token TEXT PK,              -- 'cs_' + uuidhex (mintToken, campaigns.ts:515)
  campaign_id TEXT, application_id TEXT,   -- app id | 'lead:<email>' | 'canary:<uuid>'
  to_addr TEXT, wave INTEGER,
  status TEXT,                -- pending | sent | suppressed  (failed rows are DELETED for retry)
  sent_at TEXT, delivered_at TEXT,         -- delivered = Postmark webhook (null on Resend fallback)
  opened_at TEXT, open_count INTEGER,      -- pixel; Apple MPP inflates (see 3d)
  clicked_at TEXT, click_count INTEGER,    -- click = trustworthy stage
  last_open_ua TEXT, last_click_ua TEXT )  -- migration 034: bot separation
UNIQUE(campaign_id, application_id)         -- a family gets a campaign at most once
```

**Hard dependency propagated to the T1-T4 email lane:** every lifecycle email MUST get a
`campaign_sends` row (send via the `campaigns.ts` engine, or write the row through the same ledger),
or its grid column is permanently empty and its opens/clicks are untracked. The winback path
(`winback.ts`) sends via bare `sendEmail()` WITHOUT the pixel or wrapped links (ga4-ads-state
section 4 gap); T1-T4 must NOT copy that path. This is the single most important cross-lane rule
this doc enforces.

### 1b. NEW - `campaign_events` (the `email_events` role): append-only per-event log

Answers the drill-down requirement (directive #3: "sends, opens, clicks, timestamps" per event).
`campaign_sends` keeps only FIRST timestamps + counts; this table keeps EVERY event with its own
row, so a cell drill can show "opened 3x: 09:14, 11:02, 18:40" and separate verified from bot.

```sql
-- migration 051_lifecycle_tracking.sql (see section 6 for numbering)
CREATE TABLE IF NOT EXISTS campaign_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  token        TEXT NOT NULL,                       -- FK-by-value to campaign_sends.token
  event_type   TEXT NOT NULL
     CHECK (event_type IN ('delivered','open','click','bounce','complaint','unsubscribe')),
  occurred_at  TEXT NOT NULL DEFAULT (datetime('now')),
  ua           TEXT,                                -- request User-Agent, sliced 300
  ip_hash      TEXT,                                -- SHA-256(ip) only; never store raw IP (PII posture)
  bot_suspected INTEGER NOT NULL DEFAULT 0,         -- 1 if UA matches SCANNER_UA_RE or open<60s post-send
  link_path    TEXT                                 -- for click events: which wrapped link
);
CREATE INDEX IF NOT EXISTS idx_campaign_events_token ON campaign_events(token, occurred_at);
```

Written by the SAME two handlers that already stamp `campaign_sends` (section 3): the pixel and the
click redirect each also `INSERT` a `campaign_events` row. Append-only, never updated. The grid's
rollup cell states still read `campaign_sends` (cheap); only the drill panel reads `campaign_events`
(one indexed lookup by token). This is d1-schema item 5, made concrete.

### 1c. NEW - `lifecycle_sends`: T1-T4 idempotency + agent-owned deadlines

The single load-bearing table for the automated journey (d1-schema item 2). Copies the proven
`reservation_reminders` shape exactly (PK `(application_id, stage)` = "this stage fired, never
again"). The `*/10` cron leg computes due-ness each pass from source timestamps; a row here is the
idempotency key that stops a re-send.

```sql
CREATE TABLE IF NOT EXISTS lifecycle_sends (
  application_id TEXT NOT NULL,
  stage          TEXT NOT NULL
     CHECK (stage IN ('T1_reserve','T2_exit_winback','T3_waive_fee','T4_tour_promo')),
  sent_at        TEXT NOT NULL DEFAULT (datetime('now')),
  campaign_id    TEXT,          -- the campaigns registry id used (grid join)
  send_token     TEXT,          -- campaign_sends.token for open/click tracking of THIS send
  variant        TEXT,          -- offer_code the family entered under (cohort attribution)
  PRIMARY KEY (application_id, stage)
);
```

Due-ness is derived, not stored (matches `runReservationReminders`):
- **T1** due when `fee_paid=1` AND no tour booked AND `now - fee_paid_at >= 24h` AND no `T1` row.
- **T2** is a popup, not a timed send (section 2 / winback-popup lane); it writes a
  `funnel_events`/`exit_intents` row, not a `lifecycle_sends` row. Present in the CHECK for symmetry
  only if a durable server record of the popup is wanted.
- **T3** due when `T1` sent, still no tour booked, `now - T1.sent_at >= 24h`, no `T3` row.
- **T4** due when a `tour_bookings` row for the family is `confirmed`, `slot_end + 1h <= now` (PT),
  `tour_outcomes.outcome` is not `no_show`, and no `T4` row. (enrollfee-noshow Part B: `slot_end` is
  stored, so this is a pure WHERE clause; the sweep lands within 10 min of the +1h threshold.)

All time math in `America/Los_Angeles` (the T4 "5PM TODAY" copy is PT; cron is UTC). Kill switch:
`LIFECYCLE_ENABLED` env (default `'0'` dark), mirroring `WINBACK_ENABLED`.

### 1d. NEW - `tour_outcomes`: the T4 no-show gate + comparative "tour completed" signal

`tour_bookings.status` has a CHECK with no `attended`/`no_show` literal and a CHECK cannot be ALTERed
without a table rebuild (d1-schema, tours-fees-code). Two valid homes; this doc chooses the **side
table** as canonical because BOTH the general T4 (all tours) and the OPEN ENROLLMENT waiver cohort
read one completion signal, and the grid's comparative view already references `tour_outcomes`
(campaign-grid.md section 6).

```sql
CREATE TABLE IF NOT EXISTS tour_outcomes (
  booking_id  TEXT PRIMARY KEY,                     -- REFERENCES tour_bookings(id)
  outcome     TEXT NOT NULL
     CHECK (outcome IN ('attended','no_show','cancelled')),
  marked_by   TEXT,                                 -- x-staff-email actor (Kindred), or 'calendar_bridge' / 'auto'
  marked_at   TEXT NOT NULL DEFAULT (datetime('now')),
  source      TEXT                                  -- 'kindred' | 'calendar_bridge' | 'auto'
);
```

Alternative the build lane MAY pick instead (enrollfee-noshow C1): three additive columns on
`tour_bookings` (`attendance`, `attendance_marked_at`, `attendance_marked_by`). Allowed because
`tour_bookings` is a side table, not `applications`. The side table is preferred for clean
separation and because the waiver design and the grid both key off `booking_id`; pick ONE and hold
it (do not double-write completion). Written by Kindred's no-show mark (kindred-portal ground 5,
new `POST /api/crm/tours/:bookingId/attendance` Bearer `CRM_SERVICE_TOKEN`, actor `x-staff-email`).

**Default-direction policy flag (Jarred decision, one line):** an UNMARKED tour = `attended` for T4
purposes (email sends unless Ashley affirmatively marks no-show). The opposite (hold T4 until a
positive attended-mark) is a one-predicate flip. Recommended default: unmarked = send, because the
no-show mark is an OPERATING input, not a gate (HOOTL: the system acts on its own deadline; Ashley's
mark only suppresses). Surfaced as decision #? in the master inquiry.

### 1e. NEW - `offer_variants`: the `?offer=` registry (per-variant attribution)

Maps each `?offer=` code (owned by ad-variants.md) to its metadata, so the worker and the grid can
resolve a family's acquisition cohort without hardcoding variant logic (d1-schema item 6). This is
the table campaign-grid.md's `OFFER_VARIANTS` constant is promoted from.

```sql
CREATE TABLE IF NOT EXISTS offer_variants (
  offer_code       TEXT PRIMARY KEY,       -- the ?offer= value; also utm_content
  label            TEXT NOT NULL,          -- human name for the grid ('OPEN ENROLLMENT')
  public_hook      TEXT,                   -- ad headline family
  lp_slug          TEXT NOT NULL,          -- /lp/<slug>/
  utm_campaign     TEXT,                   -- the Ads campaign slug (cohort cross-check)
  cta_type         TEXT,                   -- 'calendar' | 'overlay'
  waived_waitlist_cents  INTEGER DEFAULT 0,-- 6500 when this variant waives the $65
  waived_enrollment_cents INTEGER DEFAULT 0,-- 4500 when this variant waives the $45
  expires_at       TEXT,                   -- for 'this week only' rotation; NULL = evergreen
  active           INTEGER NOT NULL DEFAULT 1,
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Seed rows (from ad-variants.md section 1; codes are the contract with the LP `?offer=` param):

| offer_code | label | lp_slug | cta_type | waitlist¢ | enroll¢ | expires_at |
|---|---|---|---|---|---|---|
| `tour` | No-obligation tour | `book-a-tour` | calendar | 0 | 0 | NULL |
| `open-enrollment` | OPEN ENROLLMENT | `open-enrollment` | calendar | 6500 | 0 | NULL |
| `waitlist-fee-waived` | $65 waitlist fee waived | `waitlist-fee-waived` | calendar | 6500 | 0 | NULL |
| `fees-waived-100` | $100+ in fees waived | `fees-waived` | calendar | 6500 | 4500 | (dated flight only) |
| `back-to-school` | Back to School | `back-to-school` | calendar | 0 | 0 | (Aug window) |
| `infant-tour-waiver` | Infant openings | `infant-tour` | calendar | 6500 | 0 | NULL |
| `state-tour-waiver` | State employees | `state-tour` | calendar | 6500 | 0 | NULL |

`waived_*_cents` is DATA the `enrollmentFeeDue(row, waiver)` choke point (enrollfee-noshow A4) reads,
so the waiver amount lives in one place, not scattered in copy. `expires_at` non-NULL is the honest
"this week only" clock (ad-variants section 5): the LP `.condition-line` and the ad rotation both key
off a REAL date here, never an evergreen claim.

---

## 2. Tour-booking propagation (directive #1: "update ALL databases")

A booking is ONE event that must fan out to every surface. Most of the fan-out already exists in
`tours.ts` (~L326-367, verified); the directive's "ALL databases" is satisfied by closing three
gaps. The single choke point is the successful `POST /api/tours/book` handler; nothing else creates
bookings, so no second write path can drift.

| # | Surface | Mechanism | Status |
|---|---|---|---|
| 1 | `tour_bookings` row | INSERT `status='pending_calendar'` | EXISTS |
| 2 | `tour_invites.tour_booked_at` | UPDATE (funnel invited->booked) | EXISTS |
| 3 | GA4 (server MP) | `ga4.sendEvent('gmwl_tour_booked', {...})` stitched to click session via `gaCid`/`gaSessionId` + enhanced-conv `userData(email,phone)` | EXISTS |
| 4 | D1 `funnel_events` | `logFunnelEvent('gmwl_tour_booked')` (application subjects only) | EXISTS |
| 5 | Confirmation email | `buildTourConfirmationEmail` via `sendEmail` | EXISTS |
| 6 | ashley@ calendar | mini bridge polls `/api/tours/pending`, creates event, `/api/tours/reconcile` -> `status='confirmed'` | EXISTS (TEST cal until Tier-2 flip) |
| 7 | **Offer attribution** | when booked from an offer LP, ALSO fire `gmwl_tour_booked_from_offer{offer,lp,slot}` + write `funnel_events` `gmwl_tour_booked_from_offer` | **GAP - add** |
| 8 | **Kindred dashboard** | the /ads AdsFunnel reads `tour_invites` (nudge funnel), NOT `tour_bookings`; add booked-tour rollup to the ads-funnel response OR the new campaign-grid endpoint reads `tour_bookings` | **GAP - add (grid lane consumes)** |
| 9 | **GA4 key event + Ads import** | `gmwl_tour_booked` has never fired, so GA4 has not observed it; star it as a key event and import SECONDARY after V4's first real bookings | **GAP - measurement, section 4** |

Gap-7 wiring: the booking POST already receives `gaCid`/`gaSessionId` from the page; add an optional
`offer` field to the `/api/tours/book` body (the LP reads `gmwl_offer_ctx` from sessionStorage and
posts it). When present, the handler fires the second GA4 event and the second `funnel_events` row,
and stamps `lifecycle_sends`/cohort so the grid attributes the booking to the variant. The `offer`
value MUST be validated against `offer_variants.offer_code` (reject unknown -> treat as `standard`,
never trust raw param into analytics as a label without the allowlist).

Gap-8: `tour_bookings` gains no new consumer plumbing beyond the campaign-grid endpoint reading it
for the comparative view (campaign-grid.md section 6). No schema change; the grid's aggregate SELECT
adds `tour_bookings` + `tour_outcomes`.

Propagation ordering rule (already honored in code): analytics and email are each in their own
try/catch so a GA4 or email failure NEVER fails the booking (tours.ts: "analytics must never break a
booking"). The booking row + calendar bridge are the source of truth; every other surface is
best-effort and self-heals on the next sweep/webhook. This is the HOOTL closed-loop posture: the act
(booking) writes its own evidence at act time; a dropped analytics beat is recoverable, not a page.

---

## 3. Open-pixel + click-redirect endpoints (signatures, tokens, bot filtering)

Both endpoints ALREADY EXIST for the manual `campaigns.ts` engine. This section documents their
exact shape and specifies the ONE extension the lifecycle emails need (route T1/T3/T4 through the
same wrap + pixel) and the `campaign_events` append write.

### 3a. Token design (EXISTS)

`mintToken()` (campaigns.ts:515) = `'cs_' + crypto.randomUUID().replace(/-/g,'')` = a 35-char opaque
per-send token, the PK of `campaign_sends`. It is the click/open/webhook key. It is NOT signed (it is
a random UUID, unguessable, single-purpose), so no HMAC is needed: possession of the token only lets
a caller stamp open/click on ONE send row and 302 to that family's portal. There is no sensitive
capability behind it, so an opaque random token is the correct, minimal design. Do not add signing;
it would break the existing Postmark webhook passthrough (`gm_send_token` Metadata) for zero gain.

### 3b. Open pixel - `GET /c/:token/o.gif` (EXISTS, campaigns.ts:1091)

```
GET /c/:token/o.gif
  -> UPDATE campaign_sends SET opened_at=COALESCE(opened_at,now), open_count=open_count+1,
                               last_open_ua=<ua sliced 300> WHERE token=?
  -> returns 1x1 gif, Cache-Control: no-store   (never fails loudly)
```

Pixel markup injected at send time by `pixelImg(base+'/c/'+token+'/o.gif')` (a 1px img). EXTENSION:
the same handler ALSO `INSERT`s a `campaign_events(token,'open',ua,ip_hash,bot_suspected)` row, with
`bot_suspected=1` when `SCANNER_UA_RE.test(ua)` OR the open lands < 60s after `sent_at`.

### 3c. Click redirect - `GET /c/:token` (EXISTS, campaigns.ts:1104)

```
GET /c/:token
  -> lookup campaign_sends.campaign_id + applications.portal_token by token
  -> UPDATE campaign_sends SET clicked_at=COALESCE(clicked_at,now), click_count=click_count+1,
                               last_click_ua=<ua> WHERE token=?
  -> 302 to /portal/<portal_token>?utm_source=email&utm_medium=email&utm_campaign=<campaign_id>
         (+ gm_intent=<intent> when the campaign registry defines a portalIntent)
  -> fallbacks: no row/campaign -> 302 SITE_URL ; no portal_token -> 302 SITE_URL
```

Every email link is wrapped through `/c/:token` at send time. EXTENSION: same handler INSERTs a
`campaign_events(token,'click',ua,ip_hash,bot_suspected,link_path)` row. The 302 target and the
utm stamping are unchanged; the lifecycle emails (T1/T3/T4) inherit this for free BY sending through
the `campaigns.ts` engine (which does the wrap + pixel), which is exactly why section 1a mandates
that path.

### 3d. Bot filtering - Apple MPP inflates opens; clicks are truth

The honest instrumentation posture (matches the existing `campaignFunnel` verified-click heuristic):

- **Opens are directional only.** Apple Mail Privacy Protection proxy-prefetches the pixel from an
  Apple IP with a normal Safari/macOS UA, so it is NOT caught by `SCANNER_UA_RE` and cannot be
  reliably de-botted by UA alone. `open_count` will over-report. Never gate a decision or a send on
  opens. The grid drill shows opens with the caption "Apple Mail prefetch can inflate opens."
- **Clicks are the trustworthy engagement stage.** A wrapped-link click is a real navigation. The
  bot separation that matters is enterprise link-scanners (the 2026-07-05 detonation incident:
  employer appliances hit links 15-28s post-send with appliance UAs). `bot_suspected=1` when
  `SCANNER_UA_RE.test(last_click_ua)` OR `clicked_at - sent_at < 60s`. The grid and any report show
  BOTH raw and verified counts; "engaged" cell state uses VERIFIED clicks (or any open, since open =
  weaker signal but still a touch), never bot-suspected clicks alone.
- `SCANNER_UA_RE` (campaigns.ts:513, verbatim): `/bot|scan|preview|proxy|fetch|monitor|crawler|
  security|defender|safelink|barracuda|mimecast|proofpoint|urldefense|python|curl|wget/i`.

No GA4 emission for opens (unreliable, would pollute). OPTIONAL: fire a server-MP `gmwl_email_click`
from the /c/ redirect for GA4 visibility of email engagement, kept a NON-key event (never imported to
Ads) so it never contaminates the conversion column. Recommendation: defer; D1 `campaign_events` is
sufficient for the grid, and the Ads signal stays clean. Flag, do not build in v1.

---

## 4. GA4 event map additions + gtag wiring per LP variant

Canonical event names (this doc resolves the prefix inconsistency across siblings: site-lp used
`lp_tour_offer_view`, B-lane used `gmwl_tour_completed_waiver`; ALL new events take the `gmwl_`
prefix and segment by param rather than fragmenting into per-variant event names).

### 4a. New events to register

| Event | Fires | Path | Key event? | Ads import | Value/tier |
|---|---|---|---|---|---|
| `gmwl_lp_view` | LP load, param `offer=<code>`, `lp=<slug>` | C (gtag) [+D optional] | no | no | the per-variant DENOMINATOR (ga4-ads-state gap) |
| `gmwl_tour_booked` | booking (EXISTS) | S (MP) + D | **YES - star it** | SECONDARY ~$25 | cold-start unblocks when V4 fires first real one |
| `gmwl_tour_booked_from_offer` | booking from an offer LP, param `offer` | S (MP) + D | no (segment of booked) | no | per-variant mid-funnel |
| `gmwl_tour_completed` | T4 sweep 1h after `slot_end`, not no_show; param `offer`, `waiver`(bool) | S (MP) + D | **YES - star it** | SECONDARY (Purchase-class once volume) | the waiver success metric; B-lane's `_waiver` = this with offer!=null |
| `gmwl_email_click` (optional) | /c/ redirect | S (MP) | no | no | email engagement visibility, deferred (3d) |

Unchanged / already imported (do not touch): `gmwl_fee_paid_confirmed` (Purchase PRIMARY $65, the
protected headline metric), `gmwl_email_submitted` ($5 lead PRIMARY), `gmwl_reserve_confirmed`
($1,839 staged, imports on first real fire). Rule inherited from ga4-ads-state + ad-variants: do NOT
create per-variant Ads conversion actions (fragments a sparse signal); segment by `offer` param in
GA4 and the Kindred grid. **Precondition (all lanes agree):** demote the 3 Local-actions PRIMARY
conversions (Directions/Other/Website visits) to SECONDARY before importing ANY tour/lifecycle
conversion, or the comparative read is dirty from day one.

### 4b. gtag wiring per LP variant (the small client add)

Every ad LP already hardcodes gtag `G-QK5VPGREL8` (ga4-ads-state verified: the overlay's "homepage +
rates only" comment is stale). So the per-variant view event is a small inline script in the LP head,
after the existing `gtag('config',...)`:

```html
<script>
  (function () {
    var p = new URLSearchParams(location.search);
    var offer = p.get('offer') || 'standard';
    var lp = location.pathname.replace(/^\/lp\/|\/$/g, '');   // slug
    // persist for the booking/overlay handoff (site-lp-conventions 6c)
    try { sessionStorage.setItem('gmwl_offer_ctx',
      JSON.stringify({ offer: offer, lp: lp, ts: Date.now() })); } catch (e) {}
    gtag('event', 'gmwl_lp_view', { offer: offer, lp: lp,
      event_category: 'lifecycle' });
  })();
</script>
```

- The `offer` value is read from the URL, stashed in `sessionStorage.gmwl_offer_ctx` (the key
  overlay.js + the tour IIFE both already read), and fired as `gmwl_lp_view`. This gives every
  variant its own view denominator with zero per-variant code.
- On booking success the tour IIFE posts the stashed `offer` in the `/api/tours/book` body (section
  2 gap-7) and fires `gmwl_tour_booked_from_offer`. `assets/track.js` continues to fire the existing
  `waitlist_start` / `contact_phone` / `contact_email` (unchanged, FIXED include).
- The `offer` param must be validated server-side against `offer_variants` before it is used as an
  attribution label anywhere (never trust a raw query param as a GA4/grid dimension value; unknown ->
  `standard`).
- Any NEW event is starred as a GA4 key event BEFORE Ads import (site-lp-conventions rule 11). The
  cold-start reality: `gmwl_tour_booked` / `gmwl_tour_completed` cannot be starred until they fire
  once; V4's wave-0 probe (ad-variants section 2) exists specifically to fire them the first time.

---

## 5. Per-variant attribution (utm conventions + the offer chain)

Two independent carriers so attribution survives if either is stripped:

1. **`?offer=<code>`** - the OFFER identity. Owned by the LP, read into `gmwl_offer_ctx`, validated
   against `offer_variants`. This is the primary cohort key and the waiver flag (waiver rides ONLY
   `?offer=`, per the isolation mandate). It is independent of Google's auto-tagging.
2. **utm + gclid** - the PAID-CLICK identity, auto-captured into `applications.utm_*`/`gclid` (already
   plumbed, migration 012). Convention for the Ads Final URLs:

| utm param | value | purpose |
|---|---|---|
| `utm_source` | `google` | channel |
| `utm_medium` | `cpc` | paid |
| `utm_campaign` | `gm-tour-offer` (the tour campaign slug) | ties to `offer_variants.utm_campaign` |
| `utm_content` | `<offer_code>` (mirrors `?offer=`) | redundant offer carrier if `?offer=` is lost |
| `?offer=` | `<offer_code>` | the authoritative offer/waiver flag |

So a V5 Final URL is `https://www.growingmindfully.org/lp/waitlist-fee-waived/?offer=waitlist-fee-waived&utm_source=google&utm_medium=cpc&utm_campaign=gm-tour-offer&utm_content=waitlist-fee-waived`
(plus Google's appended `gclid`).

**Cohort resolution order (worker, matches campaign-grid.md section 4):**
1. `tour_waivers.offer_code` if the family is on the waiver path (migration 050) -> that code.
2. else `applications.attribution_landing_path` -> `offer_variants.lp_slug` match (each variant has a
   distinct LP slug, so landing path is the reliable cohort key even when `?offer=` was dropped).
3. else `applications.utm_content` / `utm_campaign` match.
4. else `standard`.

Because each variant has a distinct LP slug AND a distinct `?offer=` code AND (redundantly)
`utm_content`, every variant is independently trackable end to end: Ads click -> `landing_path` +
`utm_*` on the app row -> `gmwl_lp_view{offer}` in GA4 -> `gmwl_tour_booked_from_offer{offer}` ->
`gmwl_tour_completed{offer}` -> cohort chip + comparative row in the Kindred grid. Directive #4's
"OPEN ENROLLMENT tracked independently, converts comparatively" falls out with no per-variant Ads
conversion action and no per-variant code path - the `offer_variants` registry is the only thing that
knows the variant list, and adding a variant is one seed row.

**Isolation cross-check (owned with ad-variants section 8):** each variant LP is `noindex`, absent
from sitemap, zero internal links, ad-click-only. The pre-deploy grep must return only each LP's own
dir + `_redirects`/`_headers`. `offer_variants.expires_at` enforces honest "this week only" rotation.

---

## 6. Migration plan + numbering

- **050** = `tour_waivers` + `tour_waiver_email_history` (waiver lane, already designed).
- **051** = `lifecycle_tracking.sql` (THIS lane): `campaign_events`, `lifecycle_sends`,
  `tour_outcomes`, `offer_variants` (4 tables, all `CREATE TABLE IF NOT EXISTS`, additive, zero
  touch to existing tables). `campaign_sends`/`emails`/`funnel_events` are reused as-is.
- **Collision caveat (d1-schema):** the repo has parallel-numbered migration files from concurrent
  branches. Verify 050/051 are free at write time; bump if taken. All four tables are idempotent
  `IF NOT EXISTS`, so a re-run is safe.

Build order: (1) migration 051; (2) extend the pixel + /c/ handlers to append `campaign_events`;
(3) `offer_variants` seed + the `offer` validation helper; (4) tour-book `offer` param + gap-7 GA4;
(5) `lifecycle_sends` + the `*/10` cron leg (`runLifecycleSends`, piggyback - no new trigger, 5-cron
limit); (6) `tour_outcomes` + the Kindred no-show endpoint; (7) star + import the GA4 key events after
V4's first real fires. Steps 1-4 are unattended Tier-0/1; step 7 and any parent-facing send are gated.

---

## 7. HOOTL governance mapping (required by the context pack)

Every component maps to autonomy class / evidence trail / escalation target / kill switch:

| Component | Autonomy | Evidence at act time | Escalation target | Kill switch |
|---|---|---|---|---|
| `campaign_events` append (pixel/click) | AUTONOMOUS | the event row itself | none (best-effort, never fails send) | n/a (read-only side effect) |
| `lifecycle_sends` T1/T3 sweep | AUTONOMOUS, agent-owned deadline (24h) | `lifecycle_sends` row + `campaign_sends` + `campaign_events` | `#biz-gm-ads` on repeated send failure, never Jarred | `LIFECYCLE_ENABLED=0` |
| T4 sweep (post-tour) | AUTONOMOUS, acts at slot_end+1h itself | `lifecycle_sends` T4 row + GA4 `gmwl_tour_completed` | `#biz-gm-ads` | `LIFECYCLE_ENABLED=0` |
| tour-booking propagation | AUTONOMOUS | booking row + GA4 + funnel_events + email | none (self-heals next webhook/sweep) | `TOURS_KILL=1` / `TOURS_ENABLED=0` |
| no-show mark (`tour_outcomes`) | OPERATING INPUT (Ashley), not an escalation | the outcome row (marked_by/marked_at) | n/a | mark is optional; unmarked = attended default |
| `offer_variants` rotation/expiry | AUTONOMOUS (expiry is data) | the row's `expires_at` | none | `active=0` per variant |
| GA4 key-event star + Ads import | GATED (Tier 2, Jarred) | change-log entry | Jarred (batched inquiry) | remove import |

Closed-loop evidence: the Kindred campaign grid IS the audit surface (drill-down = the spot-check).
Single update: the weekly scorecard reads these tables; no drip. Single inquiry: only the genuinely
human items (default-direction policy 1d, GA4 import, budget, clickwrap, parent-facing copy) go to
Jarred, numbered one line each. No automated performance email reaches his inbox.

---

## 8. Hard-rule compliance

- Additive-only, `applications` untouched: all 4 new tables are side tables; `campaign_sends`/
  `emails`/`funnel_events` reused. Satisfied.
- Public flow writes only gm-waitlist-owned tables; never `children`, never Solace enroll gate:
  every table here is worker-owned; `tour_outcomes` is marked by staff via the CRM token, not the
  public flow. Satisfied.
- CAN-SPAM: T1/T3/T4 are marketing `kind` -> auto suppression-gated + unsubscribe + physical address
  (email-infra). `lifecycle_sends` never bypasses `email_suppressions`. Satisfied.
- No em dashes; no licensing text anywhere in this design. Satisfied.
- Timezone `America/Los_Angeles` for T4 5pm + all 24h windows. Satisfied.
- PII: `campaign_events` stores `ip_hash` (SHA-256), never raw IP; UA sliced 300. Tier-2 gates
  (parent-facing copy, clickwrap, budget, prod deploy) stay human.
```
