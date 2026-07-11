# GA4 + Ads Measurement State (ground truth, 2026-07-11)

Scope: complete current event inventory (client overlay + server sendGa4Event), which events
are Ads-imported and at what tier/value, and the gaps vs the lifecycle-funnel needs
(tour_booked, tour_completed, email opens/clicks, per-variant LP views). Built WITHOUT any
Google login: sources are ~/Projects/gm-ads/brief.md, /tmp/gm-ads-audit/gaql-0711.json (live
GAQL pulled this morning under login), and a full grep of gm-waitlist + growingmindfully.

Account: 945-427-9476. Property: GA4 `G-QK5VPGREL8`. GTM container `GTM-5FDBM4WK` was PURGED
from all pages 2026-06-24 (malware flag): dataLayer pushes are harmless no-ops, no container
consumes them. So GA4 receives events by exactly TWO mechanisms, below.

--------------------------------------------------------------------------------
## 1. HOW EVENTS REACH GA4 (two mechanisms)

### A. Client-side gtag (browser)
`gmwlTrack()` in the overlay (`gm-waitlist/public/overlay/overlay.js` ~L790-813; mirror at
`src/web/overlay/overlay.js`) calls `gtag('event', name, params)` and pushes dataLayer.
- Reaches GA4 ONLY on pages that hardcode gtag.js. VERIFIED 2026-07-11: gtag `G-QK5VPGREL8` is
  present on EVERY ad surface: `/`, `/sacramento-daycare/`, `/infant-care/`, `/state-employees/`,
  `/preschool/`, `/rates/`, `/tour/`, `/lp/state-employees/`. (The overlay's own code comment
  saying "only homepage + /rates" is STALE - every ad LP is tagged, so client events land.)
- Params auto-attach attribution: source, medium, campaign, gclid, fbclid (from
  `gmwlCaptureAttribution()`), so client events carry the ad click.
- Ad-blockers can drop these. The server MP path (B) is the resilient backstop for the money events.

### B. Server-side Measurement Protocol (Cloudflare Worker)
`sendGa4Event()` in `gm-waitlist/src/server/index.ts` L916-964 POSTs to
`google-analytics.com/mp/collect`. Default-OFF (no-op unless BOTH `GA4_MEASUREMENT_ID` and
`GA4_API_SECRET` set) and hard-gated to no-op when `SANDBOX_MODE=1` (the 2026-07-06 sandbox-leak
fix). client_id = application id (or GA cid when the page passes it). Enhanced conversions ride
along: SHA-256 of normalized email/phone via `ga4UserData()` (L977) for Ads match-rate lift.
Tours route (`src/server/routes/tours.ts` L339-352) uses the same MP path via `ga4.sendEvent`,
and stitches to the click session by passing the page's GA client_id + session_id.

Server-MP events (the reliable, ad-blocker-proof conversions):
`gmwl_fee_paid_confirmed`, `gmwl_reserve_confirmed`, `gmwl_tour_booked`.

### C. D1 telemetry (NOT GA4 at all)
Two server-only stores, queryable by Kindred without GA4:
- `funnel_events` (migration 013): the /ads funnel ladder. Event->stage map in
  `src/server/ads-funnel.ts` L47-66.
- `campaign_sends` (email engagement): opened_at/open_count, clicked_at/click_count, scanner
  separation. Powers the campaign grid. See section 4.

--------------------------------------------------------------------------------
## 2. COMPLETE EVENT INVENTORY (every gmwl_* fired today)

Legend: [C]=client gtag, [S]=server MP, [D]=written to D1 funnel_events/campaign_sends.

### Money / conversion events
| Event | Fires | Where in code | Notes |
|---|---|---|---|
| `gmwl_email_submitted` | C | overlay.js L1795/L2068 | Tier-1 lead. Client-only fire. |
| `gmwl_application_submitted` | C, D | overlay.js L1910/L2186; funnel_events | App submitted (funnel diagnostic). |
| `gmwl_fee_started` | D | campaigns.ts, ads-funnel.ts L49 | $65 pay screen reached (D1 ladder). |
| `gmwl_fee_paid` | C, D | overlay.js L2007/L2301; index.ts L146/L2012 | Client mirror of the fee payment. |
| `gmwl_fee_paid_confirmed` | S, D | index.ts L932/L1198/L3136; tours.ts L336 | THE Purchase. Server-confirmed via Stripe webhook + enhanced conv. |
| `gmwl_deposit_started` | C/D | index.ts L2282; ads-funnel.ts L63 | Reserve deposit begun. |
| `gmwl_reserve_slot_selected` | C/D | index.ts L4450; campaigns.ts L816 | Tour/reserve slot chosen. |
| `gmwl_reserve_confirmed` | S, D | index.ts L1328/L2525/L3087; ads-funnel L65 | Reservation (tuition-proxy). Server MP. |
| `gmwl_tour_booked` | S, D | tours.ts L341 (MP) + L356 (funnel_events); tour/index.html L376 | NEW (2026-07-08). Winback conversion. See section 3. |

### Reserve-leg screen beacons (funnel drop-off; client gtag + D1 mirror)
`gmwl_overlay_open`, `gmwl_step_view`, `gmwl_view_availability`, `gmwl_reserve_sheet_opened`,
`gmwl_calendar_viewed`, `gmwl_calendar_empty`, `gmwl_view_reserve_calendar`,
`gmwl_agreement_viewed`, `gmwl_view_reserve_agreement`, `gmwl_view_docusign_open`,
`gmwl_payment_viewed`, `gmwl_view_secure_space`, `gmwl_view_reserve_welcome`.
Client fires via `gmwlTrackScreenView()`; the 6 beacon screens also POST to
`/api/portal/:token/screen-view` -> D1 `gmwl_view_<screen>` (ads-funnel.ts L52-64, L71-81).

### Misc client instrumentation (GA4 only, no conversion role)
`gmwl_avail_click` (availability widget, growingmindfully/enrollment-availability/gm-availability.js
L307), `gmwl_alldates`, `gmwl_resume_dismissed`, `gmwl_preview` (walk-harness test noise, filter
from reads), `gmwl_draft_v*` / `gmwl_session_v*` / `gmwl_attr_v*` (client version pings).

--------------------------------------------------------------------------------
## 3. WHICH EVENTS ARE ADS-IMPORTED, AT WHAT TIER + VALUE

Tier model (brief 2026-07-03): email $5 (tier 1) / fee-paid $65 (headline PRIMARY) /
space-reserved $1,839 (tier 3 tuition proxy). Confirmed against gaql-0711.json `conv[]`
(the live conversionActionName rows) plus brief conversion-action IDs.

| Conversion action (Ads name) | ID | Category | Status | Value | Count | Imported? |
|---|---|---|---|---|---|---|
| Growing Mindfully (web) gmwl_fee_paid_confirmed | 7655216632 | Purchase | PRIMARY | $65 fixed | ONE | YES. First real one landed 7/7 (Flynn, Core). Headline metric. |
| Growing Mindfully (web) gmwl_email_submitted | (wizard) | Submit lead form | PRIMARY | $5 fixed | ONE | YES. DDA, 90d. Confirmed importing (Infant + RTO, 7/8). Tier 1. |
| Growing Mindfully (web) gmwl_fee_paid | 7654884716 | (lead) | SECONDARY | $65 fixed | - | YES (secondary, client mirror). |
| Growing Mindfully (web) gmwl_application_submitted | - | (lead) | SECONDARY | - | - | YES (secondary, funnel diagnostic). |
| Growing Mindfully (web) waitlist_start | - | (lead) | SECONDARY | - | - | YES (GA4 auto-import; fires PRE-email). Do NOT promote to primary. |
| Growing Mindfully (web) gmwl_reserve_confirmed | - | Purchase | STAGED / NOT IMPORTED | $1,839 (planned) | ONE | NO. Blocked: GA4 has NEVER observed the event; no create-key-event-by-name in this UI. Unblock = first real reserve fires it, then star + import (Monday 7/14 item). Tier 3. |
| Local actions - Directions | (auto, GBP) | Local action | PRIMARY | Google-set | - | YES, auto-created by the 7/7 GBP link. POLLUTION. |
| Local actions - Other engagements | (auto, GBP) | Local action | PRIMARY | Google-set | - | YES, auto. POLLUTION. |
| Local actions - Website visits | (auto, GBP) | Local action | PRIMARY | Google-set | - | YES, auto. POLLUTION. |

Notes:
- LOCAL-ACTIONS POLLUTION is the live measurement defect: 7/6-7/10 shows Directions 2, Other
  engagements 4, Website visits 2 (Core + Infant + RTO), all PRIMARY, contaminating the
  Conversions column and any future Max-Conversions switch. Pending Jarred ask upgraded to
  "demote ALL Local actions conversion actions to SECONDARY."
- Three dead legacy click actions (Begin application 7616865119, Claim Your VIP Rates
  7635398611, Email enrollment 7635426678) were REMOVED 7/3. Archive pending (never-drop).
- HARD PRECONDITION on brief (all 3 counsel models): demote `gmwl_email_submitted` to SECONDARY
  before ANY bidding switch (the $5-email-chasing trap). Relevant when tour/lifecycle events add
  more low-value primaries.

--------------------------------------------------------------------------------
## 4. EMAIL OPEN + CLICK TRACKING (what exists today)

EXISTS in D1 for the manual campaign engine `campaigns.ts` (template `reserve-early-access`,
Kindred/admin-triggered, wave-gated). This IS the campaign-grid substrate the directive item 3
asks for, already built:
- Open pixel: `GET /c/:token/o.gif` -> UPDATE campaign_sends opened_at/open_count + last_open_ua
  (campaigns.ts L1083-1094). Apple-MPP inflation acknowledged; clicked is the trustworthy stage.
- Click tracking: every email link is a wrapped `GET /c/:token` -> stamps clicked_at/click_count
  + last_click_ua, then 302 to `/portal/<token>?utm_source=email&utm_medium=email&utm_campaign=<id>`
  (L1096-1125). Scanner/appliance clicks separated from verified-human (time + UA rule).
- Reporting: admin funnel `GET /admin/campaigns/:id` (+ ?format=json|csv) AND the Kindred
  service API `GET /api/crm/campaigns/:id/report` returns funnel stages + PER-FAMILY drill-down
  JSON (campaigns.ts L23-32). This is exactly the "click a cell -> sends/opens/clicks/timestamps"
  drill the grid needs.

GAPS in email tracking:
- D1-ONLY. Opens/clicks are NOT emitted as GA4 events, so email engagement is invisible in GA4
  and un-importable to Ads as-is (would need a server MP fire on open/click, or a GA4 measurement
  from the /c redirect).
- LIFECYCLE (T1-T4) EMAILS ARE NOT ON THIS TRACKED PATH. The automated re-engagement sweep
  `winback.ts` (segments A1/A2/B1 unpaid + C tour-invite) sends via `sendEmail` WITHOUT the open
  pixel and WITHOUT wrapped-link click tracking. Its only per-family click stamp is the tour link
  `/t/:token` (tours), not a general open/click tracker. So the directive's T1 "Reserve Your
  Space", T3 "book a tour + waive", and T4 tour-completion promo would ship UN-tracked for
  opens/clicks unless they either route through campaigns.ts or get the pixel + wrap added.
- Both engines are DARK in prod: `WINBACK_ENABLED='0'`, and campaigns need `CAMPAIGNS_ENABLED='1'`
  + confirm:'SEND'. Arming is a Jarred decision.

--------------------------------------------------------------------------------
## 5. GAPS vs LIFECYCLE-FUNNEL NEEDS

### tour_booked -- PARTIAL (exists, not productionized)
- Event `gmwl_tour_booked` EXISTS: server MP via `ga4.sendEvent` (tours.ts L341) with
  method (email_one_tap|page_picker), conversion_type (winback|direct), subject_type, slot_start,
  booking_id, and session stitch; PLUS D1 funnel_events mirror for application subjects (L356);
  PLUS `tour_invites.tour_booked_at` funnel stamp. Client `/tour/` also grabs GA cid/session
  (tour/index.html L376-382).
- GAPS: (a) has NEVER fired (zero tours booked to date), so GA4 has not observed it - same
  cold-start blocker as reserve_confirmed; (b) NOT a GA4 key event yet; (c) NOT Ads-imported;
  (d) no decision on its value/tier (winback vs direct booking may want different values).
  Directive item 1 ("tour bookings must update ALL databases - D1, GA4, dashboards") is CODE-READY
  on D1 + GA4 but needs the dashboard leg + GA4 star + Ads import.

### tour_completed -- MISSING (full gap)
- NO `tour_completed` / no-show event exists anywhere in the waitlist analytics. The only
  no_show/completed_at logic in the repo lives in the Brightwheel ENROLLMENT engine
  (`src/server/enrollment/engine.ts`), unrelated to tours.
- The T4 trigger (send 1h after scheduled tour END unless Ashley marked no-show in Kindred) has
  NO backing data/event today. Needs: a tour state machine that stores scheduled_end, a no-show
  flag writable from Kindred/Ashley, a completion sweep (cron 1h after end, America/Los_Angeles),
  and a `gmwl_tour_completed` event (D1 + GA4 MP), plus its own Ads-import decision.

### email opens / clicks -- PARTIAL (see section 4)
- EXISTS for the manual campaigns.ts engine (D1 pixel + wrapped links + per-family drill report).
- GAPS: not on the automated lifecycle (winback) path; D1-only (no GA4/Ads surface).

### per-variant LP views -- MISSING (full gap)
- NO per-variant landing-page-view event exists. The only view events are reserve-flow step
  beacons (`gmwl_view_*`), which track the onsite reserve funnel, not ad-LP variants.
- The ad-variant matrix (V1 OPEN ENROLLMENT / V2 Back to School / V3 $100+ waived / V4 free tour /
  V5 $65 waived) and the tour-waiver isolation plan key the waiver only off the `?offer=` param
  with noindex + zero internal links. Nothing fires a view event per variant today. Needs a
  client `gmwl_lp_view` (or per-variant name) keyed on variant/offer param, on gtag-tagged LPs
  (all ad LPs already carry gtag, so this is a small client add), optionally mirrored to D1 for
  the Kindred grid. Without it, per-variant LP-view -> conversion rates cannot be measured and the
  V1-V5 A/B read (directive item 4: "OPEN ENROLLMENT tracked independently, converts comparatively")
  has no numerator.

--------------------------------------------------------------------------------
## 6. ONE-LINE SUMMARY FOR DOWNSTREAM AGENTS
Measurement backbone is solid: fee_paid_confirmed ($65 Purchase PRIMARY, live, 1 real) +
email_submitted ($5 lead PRIMARY, live) imported to Ads; reserve_confirmed ($1,839) and
tour_booked both coded (server MP + D1) but cold-start-blocked (never fired -> not GA4 key
events -> not imported). Email open/click tracking exists in D1 for the MANUAL campaign engine
only. Full new-build gaps for the lifecycle plan: tour_completed (no event at all), per-variant
LP views (no event at all), lifecycle-email open/click (winback path is untracked), and moving
tour_booked/reserve_confirmed/email-engagement onto GA4 key events + the Kindred grid. Live
defect to clear first: 3 Local-actions PRIMARY conversions polluting the Conversions column.
