# DESIGN: Kindred Campaign Grid (per-family x per-campaign engagement matrix)

Lane: DESIGN. Owns directive #3 (the Kindred campaign grid) and directive #4's comparative view
(OPEN ENROLLMENT waiver cohort vs standard). Builds on ground: `kindred-portal.md`,
`email-infra.md`, `d1-schema.md`, `waiver-package.md`. Nothing here executes; this is the buildable
spec the implementation branch follows. Hard rules honored: portal owns no schema, additive-only
side tables, no em dashes, no licensing text, CAN-SPAM/suppression respected upstream, Tier-2 gates
on any parent-facing or mutation surface (this surface is READ-ONLY, so it is Tier 0/1).

---

## 0. What this is, in one paragraph

A new admin page `/campaign-grid` in kindred-portal: rows = waitlist families, columns = campaigns
(the lifecycle emails T1/T2/T3/T4 plus any manual campaigns), each cell colored by engagement state
(not targeted / received / engaged / converted / suppressed / failed). Click a cell to open a drill
panel with the send's event timeline (sent, delivered, opened xN, clicked xN, converted) and a
rendered-email preview link. A filter bar scopes by age band, acquisition cohort (offer variant),
and date. Below the grid, a comparative table pits the OPEN ENROLLMENT (tour-waiver) cohort against
the standard flow head to head. The engagement substrate already exists (`campaign_sends` with
open+click tracking, `funnel_events`, `tour_invites`); the build is ONE new read-only worker
aggregate endpoint plus one portal view following the established view/helpers split.

---

## 1. Data source lane decision (which proxy, which token)

Two proxies exist (kindred-portal ground section 4). The grid is READ-ONLY and needs no twofa gate,
so it takes the **`/crm-api` direct-tokened lane** (the Families lane), NOT the `/api/crm` solace
proxy that Campaigns/AdsFunnel use.

- Browser calls `GET /crm-api/campaign-grid` -> vite proxy rewrites to
  `https://waitlist.growingmindfully.org/api/crm/campaign-grid` and injects
  `Authorization: Bearer ${CRM_SERVICE_TOKEN}` server-side (never in the browser).
- Why this lane, not the solace proxy: the solace-api only forwards the specific paths it knows
  (`/crm/campaigns`, `/crm/ads-funnel`). A new grid path through `/api/crm/*` would need a
  solace-api code change AND deploy. The `/crm-api` lane hits the worker directly and requires
  **zero solace-api change**. It is also the lane `FamilyDetail` already uses to serve
  `campaign_touches[]`, so the grid is the natural cross-family aggregate of a payload the worker
  already produces per family.
- The worker route still lives under `/api/crm/*` (the worker's own namespace, guarded by
  `crmAuthed(c)` = a Bearer token equality compare, `crm.ts:333`: `token && auth && auth === token`).
  The `/crm-api` prefix is only the portal-side proxy alias. Note: `crmAuthed` is NOT exported. Each
  worker CRM module defines its own local copy (`crm.ts:333`, `ads-funnel.ts`, `enrollment-crm.ts:21`
  are byte-identical), so the new `campaign-grid.ts` module copies the same 4-line helper rather than
  importing it. It is a plain `===` compare (not timing-safe), matching every existing CRM route.

---

## 2. Worker endpoint (gm-waitlist) - the one new backend piece

New module `/Users/jarredwinn/Projects/gm-waitlist/src/server/campaign-grid.ts`, registered in
`index.ts` next to `registerCrm` / `registerAdsFunnel`:

```ts
export function registerCampaignGrid(app: Hono<any>, makeDb: (d: any) => DbLike): void {
  app.get('/api/crm/campaign-grid', async (c) => {
    if (!crmAuthed(c)) return c.json({ error: 'unauthenticated' }, 401);
    // ... assemble (see 2b) ...
  });
  app.get('/api/crm/campaign-grid/preview/:token', async (c) => {
    if (!crmAuthed(c)) return c.json({ error: 'unauthenticated' }, 401);
    // ... rendered-email preview for one send token (see 5) ...
  });
}
```

SELECT-only. Never writes. Mirrors `ads-funnel.ts` exactly (multi-query fetch then assemble in JS;
`ads-funnel.ts` header line 21 "SELECT-only: this module never writes"). Registration signature
matches `registerCrm`/`registerAdsFunnel` verbatim: `(app: Hono<any>, makeDb: (d: any) => DbLike)`,
called at `index.ts:6049` beside them. Copies the local `crmAuthed` helper (4 lines, not exported;
see section 1) and the local `rowsOf(r){ return r?.results ?? r ?? []; }` helper from
`ads-funnel.ts`.

### 2a. Query params

`GET /api/crm/campaign-grid?scope=&band=&cohort=&since=&until=&limit=`

| param | values | default | effect |
|---|---|---|---|
| `scope` | `applicants` \| `all` | `applicants` | `applicants` = rows with an `applications` row (Waitlist view convention); `all` adds lead-only rows keyed by email |
| `band` | `infant`\|`toddler`\|`young_preschool`\|`preschool` | (all) | filter rows by `age_band` |
| `cohort` | offer code \| `standard` \| `all` | `all` | filter rows by acquisition cohort (see 4) |
| `since` / `until` | ISO date | (all time) | filter cells to sends whose `sent_at` falls in the window; a family with no send in-window shows `not_targeted` cells but still lists |
| `limit` | int | `500` | row cap; grid is applicant-scale (12 fee-paid families today), so 500 is generous |

### 2b. Assembly (four SELECTs, join in JS - the ads-funnel.ts pattern)

1. **Rows** - families:
   ```sql
   SELECT a.id, a.child_first, a.child_last, a.parent1_email, a.age_band,
          a.priority_tier, a.status, a.fee_paid, a.fee_paid_at, a.deposit_paid_at,
          a.reserve_start_date, a.tour_requested_at,
          a.utm_campaign, a.attribution_landing_path,
          tw.offer_code AS waiver_offer_code
     FROM applications a
     LEFT JOIN tour_waivers tw ON tw.application_id = a.id      -- migration 050 (may be absent)
    WHERE a.status NOT IN ('archived')                          -- keep pending_tour, waiting, etc.
      AND (?band IS NULL OR a.age_band = ?band)
    ORDER BY COALESCE(a.fee_paid_at, a.created_at) DESC
    LIMIT ?limit
   ```
   `LEFT JOIN tour_waivers` is wrapped in try/catch (the table may not exist until migration 050
   ships) exactly as `crm.ts` wraps `campaign_sends`/`tier_reviews`. `scope=all` unions a `leads`
   query (email PK) with null campaign cells except where `campaign_sends.application_id =
   'lead:'||email`.

2. **Cells** - every send for these families across the grid's campaigns:
   ```sql
   SELECT cs.campaign_id, cs.application_id, cs.token, cs.status,
          cs.sent_at, cs.delivered_at, cs.opened_at, cs.open_count,
          cs.clicked_at, cs.click_count
     FROM campaign_sends cs
    WHERE cs.campaign_id IN (<grid campaign ids>)
   ```
   (`campaign_sends` unique index `(campaign_id, application_id)` guarantees one row per cell.)

3. **Conversion signals** - `funnel_events` for the conversion test (see 3b):
   ```sql
   SELECT application_id, event_name, occurred_at
     FROM funnel_events
    WHERE event_name IN ('gmwl_tour_booked','gmwl_tour_completed_waiver',
                         'gmwl_reserve_confirmed','gmwl_fee_paid_confirmed',
                         'gmwl_fee_exit_winback_shown','gmwl_fee_exit_winback_tour',
                         'gmwl_fee_exit_winback_stay')
   ```

4. **Comparative-view extras** - tour outcomes + waiver state for the cohort table (see 6):
   ```sql
   SELECT booking_id, outcome FROM tour_outcomes;            -- migration 050 sibling table (may be absent)
   SELECT application_id, waiver_state FROM tour_waivers;    -- OPEN ENROLLMENT cohort
   ```

### 2c. Which campaigns are columns

The grid's column set = the lifecycle campaigns + a synthetic T2 column, ordered by lifecycle stage,
then manual campaigns by `created_at`. NAMING CONTRACT (reconciled with the sibling email lanes,
which already picked concrete identifiers - do NOT invent new slugs): the join key is the
`campaigns.email_kind` value the email lanes register, matched by the `campaign_lifecycle_*` /
`lifecycle_*` prefix, NOT a guessed `template` slug. The real identifiers as chosen by the email
lanes (`design/email-reserve.md`, `email-tour-nudge.md`, `email-post-tour.md`) and the DB/cron lane's
`lifecycle_sends.stage`:

| grid column | `campaigns.email_kind` (real) | `lifecycle_sends.stage` | conversion event |
|---|---|---|---|
| T1 Reserve | `campaign_lifecycle_t1_reserve` (+ `_openenroll` variant B) | `t1_reserve` | `gmwl_reserve_confirmed` |
| T2 Tour winback | (SYNTHETIC popup, no email - see 3c) | `t2_exit_winback` (if durable) | `gmwl_tour_booked` |
| T3 Waive fee | (email-tour-nudge lane's registry `kind`) | `t3` | `gmwl_tour_booked` |
| T4 Post-tour promo | `lifecycle_t4_post_tour` | `t4` | `gmwl_reserve_confirmed` |
| (manual) | any `status IN ('sending','sent')` campaign | - | its own registry-mapped event |

The worker owns the kind->conversion_event map as a constant `CAMPAIGN_CONVERSION` (see 3b), keyed on
the registry `email_kind`/`id` the email lanes actually register - reconcile these values at build
time (single source of truth is the email lanes' registry entries; this table is the consumer's
mirror). The portal renders whatever columns the response lists, so adding a fifth lifecycle campaign
later needs no portal change (same "stages come from the report" principle as `FunnelReport.tsx`).
The T1 A/B variants (`_openenroll`) collapse into ONE T1 column; the cohort split lives in section 6,
not as two columns.

**Cross-lane dependency (flag to the lifecycle-email lane):** T1/T3/T4 emails MUST be sent through
the `campaigns.ts` engine (or write a `campaign_sends` row via the same ledger) so the grid can see
them. If the lifecycle lane sends T1-T4 through a bespoke `sendEmail()` path that only writes the
`emails` table (not `campaign_sends`), those columns will be permanently empty. The registry-entry
approach in `email-infra.md` section 2 (new `CAMPAIGNS` entries) satisfies this for free.

---

## 3. Cell state model

### 3a. States + color semantics (existing tokens, `src/index.css`)

| state | meaning | bg token | fg token | in-cell label |
|---|---|---|---|---|
| `not_targeted` | no send row for this (family, campaign) | (none) | `var(--tr-dim)` | muted hyphen (`<Muted>-</Muted>`, matches FunnelReport) |
| `received` | delivered (or sent) but never opened/clicked | `var(--surface-container-high)` | `var(--on-surface-variant)` | "Received" |
| `engaged` | opened or clicked, no conversion yet | `var(--tertiary-container)` (gold) | `var(--on-tertiary-container)` | "Engaged" |
| `converted` | reached the campaign's conversion event after send | `var(--secondary-container)` (green) | `var(--on-secondary-container)` | "Converted" |
| `suppressed` | `status='suppressed'` (unsubscribed/bounced-gate) | `var(--surface-container-highest)` | `var(--tr-dim)` | "Suppressed" (strikethrough) |
| `failed` | `status='failed'` or hard-bounce | `var(--error-container)` | `#8b1a1a` | "Failed" |

Color is never the sole signal: every cell carries a short text label (or icon) and an
`aria-label="<campaign>: <state>"`. This matches the `Pill` tone vocabulary already used in
`FunnelReport.tsx` (`ok`/`gold`/`muted`) and `ui.tsx` `StatusBadge`; reuse those tones so the grid
reads as the same system.

### 3b. Conversion test (worker, per cell)

A cell is `converted` when the family reached the campaign's `conversion_event` AFTER the send
timestamp. Worker logic per (family, campaign):

```
sent = cell.sent_at
conv_event = CAMPAIGN_CONVERSION[campaign.template]   // e.g. 'gmwl_reserve_confirmed'
converted = funnel_events has (application_id, conv_event) with occurred_at >= sent
          OR the applications timestamp proxy for that event >= sent
            (reserve -> deposit_paid_at/reserve_start_date; tour -> tour_requested_at; fee -> fee_paid_at)
```

`occurred_at >= sent` makes conversion attributable to the send (same rule as `campaignFunnel`'s
"stages after Clicked count milestones that happened after the family clicked", FunnelReport sub-copy
line 59). If no send exists (`not_targeted`), the cell is never `converted` even if the family
converted by another path - conversion is per-touch, not global.

Precedence when multiple states apply: `failed` > `suppressed` > `converted` > `engaged` >
`received` > `not_targeted`. (A converted family that later unsubscribed still reads `converted` for
that historical send; suppression only downgrades a send that never converted.)

### 3c. T2 is a popup, not an email (special column)

T2 ("clicked T1 but did not reserve, tries to EXIT the reserve page -> book-a-tour winback popup")
has no `campaign_sends` row - it is an on-page overlay firing `gmwl_fee_exit_winback_*` funnel events
(email-infra section 6; d1-schema item 3). The endpoint SYNTHESIZES a T2 GridCell from
`funnel_events`:

- `gmwl_fee_exit_winback_shown` present -> `received` (popup was shown)
- `..._tour` or `..._stay` present -> `engaged` (family acted on the popup)
- `gmwl_tour_booked` after the popup -> `converted`
- none -> `not_targeted`

The T2 column header carries a small "popup" badge so staff know it has no email preview and no
open/click counts (its drill panel shows shown/dismissed/booked, not delivered/opened). Flag to the
site/overlay lane: T2 must fire a durable server-recorded `funnel_events` row (not only a client
gtag event) for the grid to see it; if the overlay only sends GA4, add the small
`exit_intents(application_id, page, shown_at, action)` side table from d1-schema item 3 and read
that instead.

---

## 4. Cohort resolution (acquisition variant per family)

Directive #4 wants the OPEN ENROLLMENT (tour-waiver) cohort tracked independently and compared vs
standard. "Cohort" is a per-family acquisition attribute, resolved by the worker in this order:

1. `tour_waivers.offer_code` if the family is on the waiver path (V1/V3/V5 codes) -> that code.
2. else map `applications.attribution_landing_path` / `utm_campaign` to a variant via an optional
   `offer_variants` registry (d1-schema item 6). Each `?offer=` value (V1 open-enrollment, V2
   back-to-school, V3 $100+, V4 free-tour, V5 $65-waived) -> `{code, label, waived_amount, ...}`.
3. else `standard`.

Until the `offer_variants` table ships, the worker uses a hardcoded `OFFER_VARIANTS` constant keyed
on `landing_path` (`/lp/tour-offer/` -> `open_enrollment`, `/lp/back-to-school/` -> `back_to_school`,
etc.). Cohort is a ROW attribute (shown as a chip in the family column) and a FILTER (`?cohort=`),
plus the grouping key for the comparative view (section 6). Cohort is deliberately NOT a set of grid
columns: a family "receives" campaigns, it does not "receive" its own acquisition source. (If Jarred
wants variant-as-column later, add a `columns=cohort` mode where each variant column's cell = binary
provenance "entered via this offer"; noted, not built.)

---

## 5. Drill panel (click a cell)

Click any non-empty cell -> in-portal panel (a right-side drawer or a `Card` modal, not a new page;
reuse `Card` from `ui.tsx`). Contents:

- **Header:** family name + campaign label + state Pill.
- **Event timeline** (vertical, newest-relevant last), each row = label + absolute timestamp
  (`shortTime`) + relative (`timeAgo` from `crm.ts`):
  - Sent (`sent_at`)
  - Delivered (`delivered_at`, muted "awaiting delivery webhook" if null but sent)
  - Opened (`opened_at`) with `open_count` badge ("x3"); note "Apple Mail prefetch can inflate
    opens" caption (reuse FunnelReport's verified-click caution language)
  - Clicked (`clicked_at`) with `click_count` badge - the trustworthy engagement stage
  - Converted (`converted_at` = the funnel_events `occurred_at`) with the conversion event name
- **Rendered email preview link:** `GET /api/crm/campaign-grid/preview/:token` (portal alias
  `/crm-api/campaign-grid/preview/:token`). Worker looks up the send by `token`, finds the matching
  `emails` row (`application_id` + `kind` + nearest `sent_at`), returns `{subject, body_html}`. The
  portal opens it in a sandboxed iframe (`srcdoc`, `sandbox="allow-same-origin"`) inside the panel,
  or a new tab. Fallback when no exact `emails` row: link to the campaign's existing sample preview
  (`/api/crm/campaigns/:id/preview` -> `sample_html`). T2's popup column shows no email preview (it
  has none).
- **Journey deep link:** `journeyUrl('/admin/journey/'+application_id)` opened in a new tab (worker
  admin auth), identical to the FunnelReport per-family Journey link.

Baseline drill data = `campaign_sends` first-timestamps + counts (already stored). If per-event
granularity is wanted later (each open/click with its own ts/UA/IP), add the append-only
`campaign_events(token, event_type, occurred_at, ua, ip)` table (d1-schema item 5) and the drill
lists individual events; the `open_count`/`click_count` rollup is sufficient for v1.

---

## 6. Comparative view (OPEN ENROLLMENT vs standard) - directive #4

A `Card title="OPEN ENROLLMENT vs Standard flow"` section below the grid. One row per cohort
(`cohorts[]` in the response), columns = a mini conversion funnel:

| cohort | families | received | engaged | tour booked | tour completed | reserved | conv rate |
|---|---|---|---|---|---|---|---|
| OPEN ENROLLMENT | n | n | n | n | n | n | reserved/families % |
| Back to School | ... | | | | | | |
| $65 waived | ... | | | | | | |
| Standard | ... | | | | | | |

Worker computes each cohort's rollup from the same four SELECTs:
- `families` = row count in cohort
- `received`/`engaged` = families with any cell in that state across lifecycle columns
- `tour booked` = `funnel_events gmwl_tour_booked` OR a `tour_bookings`/`tour_invites` row
- `tour completed` = `tour_outcomes.outcome='attended'` (migration 050 sibling table; the T4 signal)
  - if `tour_outcomes` absent, show "pending instrumentation" not a zero (honesty; the no-show mark
    does not exist yet per kindred-portal ground section 5 and d1-schema item 4)
- `reserved` = `deposit_paid_at` set OR `gmwl_reserve_confirmed`
- `conv rate` = reserved / families, with a small-n caution (`n<20` -> muted "directional")

This is the head-to-head numerator/denominator the E-measurement lane wants surfaced in Kindred. It
reuses the horizontal-bar + `Total` visual vocabulary from `FunnelReport.tsx`. Rate significance is
NOT asserted at these volumes (43-58 paid clicks/week account-wide, waiver-package section 1e);
label reads "directional" until n is meaningful.

---

## 7. Portal implementation (kindred-portal)

Follow the enforced view/helpers split (kindred-portal ground section 1).

### 7a. Files

- `src/api/campaignGrid.ts` - types + fetch + poller hook. Base `/crm-api`. Clone the
  `useFamilyDetail` poller shape from `crm.ts` (30s visibility-aware poll, keep-stale-on-failed-poll,
  explicit loading/error/refetch, `updatedAt` for `UpdatedStamp`). Do NOT reuse `campaigns.ts`
  `useGet` verbatim - it hardcodes the `/api/crm` error vocabulary (`campaignsErrorMessage`); the
  `/crm-api` lane uses the `crm.ts` error semantics (401/403/404/non-200). Small dedicated hook.
- `src/views/CampaignGrid/CampaignGridView.tsx` - layout + fetch wiring.
- `src/views/CampaignGrid/campaignGridHelpers.ts` - cell-state -> tone map, filter application,
  sort, cohort labels, timeline row builder. All pure, unit-tested.
- `src/views/CampaignGrid/__tests__/campaignGridHelpers.test.ts` - Vitest, mirrors
  `Campaigns/__tests__` and `AdsFunnel/__tests__`.

### 7b. Routing + nav

- `src/App.tsx`: add `<Route path="/campaign-grid" element={<CampaignGridView/>} />` inside the Shell
  route. Distinct top-level path so `Sidebar` `isActive` (`startsWith`) does not co-highlight
  `/campaigns` (kindred-portal ground section 2 warns about this exact collision).
- `src/layout/Sidebar.tsx`: add to the `navItems` array (after "Email Campaigns"):
  ```ts
  { to: '/campaign-grid', label: 'Campaign Grid',
    iconPath: 'M3 3v18h18V3H3zm8 16H5v-6h6v6zm0-8H5V5h6v6zm8 8h-6v-6h6v6zm0-8h-6V5h6v6z' },
  ```
  (a 2x2 grid glyph; distinct from the "Slot Map" grid path already in use).

### 7c. Component tree (CampaignGridView)

```
CampaignGridView
  <header> title "Campaign Grid" + sub + <UpdatedStamp updatedAt refreshError>
  <FilterBar>            // band select, cohort select, since/until date, scope toggle - inputStyle/btnOutline
  <Legend>              // 5 state chips (Pill tones) so the color key is on-screen
  <PanelFallback>       // first-load skeleton / error / retry (from ui.tsx)
  <GridTable>           // sticky header row (campaigns) + sticky first col (family)
     thead: <SortTh Family> then one <th> per campaign (label + stage + optional "popup" badge)
     tbody: one <tr className="crm-row"> per family:
        <td sticky left>: child name + email + <cohort chip> + band
        one <CellButton> per campaign -> colored state Pill, onClick -> setDrill({family, campaign})
  <DrillPanel drill={...} onClose>   // section 5, Card-based
  <ComparativeCard>     // section 6
```

Reuse verbatim: `Card`, `Muted`, `PanelFallback`, `UpdatedStamp`, `StatusBadge`/`Pill` (`ui.tsx`);
`thStyle`, `tdStyle`, `btnOutline`, `inputStyle` (`Campaigns/styles.ts`); the `SortTh` sortable
header pattern + rotate-caret SVG (`FunnelReport.tsx`); `timeAgo`/`shortTime`/`journeyUrl`
(`crm.ts`); `crm-row` hover class (`index.css`); the `overflow:auto; maxHeight:460; minWidth:<n>`
wide-table scroll wrapper (`FunnelReport.tsx` line 157). No grid library, no new CSS framework.

### 7d. Sticky-cell mechanics

Wide grid = many campaign columns. First column (family) is `position:sticky; left:0; zIndex:2;
background:var(--surface-container-lowest)` so it stays visible while scrolling columns; header row
is `thStyle` (already `position:sticky; top:0`). The family header cell needs both -> `zIndex:3`.
Cells are fixed min-width (~92px) so the grid reads as a matrix, not a ragged table.

---

## 8. Auth, performance, failure modes

- **Auth:** inherits Cloudflare Access (jarred@/ashley@) + the server-injected `CRM_SERVICE_TOKEN`
  on the `/crm-api` proxy. No new auth. The browser never holds the token (kindred-portal ground 4).
- **Performance:** applicant-scale. 12 fee-paid families x ~6 campaigns today; even at 500 families
  x 10 campaigns the payload is small and the four SELECTs are indexed
  (`idx_campaign_sends_app`, funnel_events unique `(application_id, event_name)`). One endpoint, one
  poll every 30s; no N-per-family fetches (the anti-pattern the endpoint exists to avoid).
- **Degradation:** each optional table (`tour_waivers`, `tour_outcomes`, `campaign_events`,
  `offer_variants`) is wrapped in try/catch worker-side (the `crm.ts` `campaign_touches` pattern) so
  the grid renders before those migrations land - cohort falls back to `standard`, tour-completed
  shows "pending instrumentation". `PanelFallback` owns first-load/error; failed background polls
  keep stale data on screen with the `UpdatedStamp` hinting staleness (the `useGet` contract).
- **Family key duality:** `scope=applicants` (default) sidesteps the lead/application key ambiguity
  (Waitlist view convention). `scope=all` keys leads by `lead:<email>` matching
  `campaign_sends.application_id`; leads have no journey link (null), handled like FunnelReport's
  canary rows.

---

## 9. Build checklist (ordered)

1. gm-waitlist: `src/server/campaign-grid.ts` (`registerCampaignGrid`) - the aggregate GET + the
   preview GET, SELECT-only, `crmAuthed`-gated, optional-table try/catch.
2. gm-waitlist: register in `index.ts` beside `registerAdsFunnel`. Add `CAMPAIGN_CONVERSION` +
   `OFFER_VARIANTS` constants.
3. gm-waitlist: unit test the cell-state + cohort + conversion resolvers (Vitest, mirrors
   ads-funnel tests).
4. kindred-portal: `src/api/campaignGrid.ts` types + `useCampaignGrid` poller.
5. kindred-portal: `views/CampaignGrid/CampaignGridView.tsx` + `campaignGridHelpers.ts` + tests.
6. kindred-portal: route in `App.tsx` + nav item in `Sidebar.tsx`.
7. Verify at mini `localhost:3014` (bypasses CF Access). Prod deploy is a Tier-2 Jarred gate
   (`ssh mini "~/bin/deploy-kindred-portal.sh"`, clean + on `main`).

---

## 10. Dependencies + tensions (flag, do not let slip)

1. **DEPENDENCY (hard): T1/T3/T4 lifecycle emails must write `campaign_sends` rows.** If the
   lifecycle-email lane sends them via a bespoke `sendEmail()` that only logs the `emails` table,
   the grid columns are empty. Resolution: send lifecycle emails through the `campaigns.ts` engine as
   new `CAMPAIGNS` registry entries (email-infra section 2) so open+click tracking + the
   `campaign_sends` ledger come for free. Owned by the lifecycle-email design lane; the grid is a
   consumer. NAMING SUB-DEPENDENCY: the grid's `CAMPAIGN_CONVERSION` map keys on the exact
   `campaigns.email_kind`/registry `id` the email lanes register (`campaign_lifecycle_t1_reserve`,
   `lifecycle_t4_post_tour`, etc.; see 2c table). Those values are the email lanes' to define and the
   grid must mirror them: a rename there silently empties a grid column. Reconcile at build time
   against the email lanes' registry entries and the DB/cron lane's `lifecycle_sends.stage` vocabulary.
2. **DEPENDENCY: T4 tour-completed + the comparative view need the `tour_outcomes` table + Ashley's
   no-show mark** (kindred-portal ground 5; d1-schema item 4). Until that ships, the grid shows tour
   completed as "pending instrumentation", not zero. The no-show mark itself is a separate design
   (a `mark_tour_no_show` action or worker POST); the grid only READS the outcome.
3. **DEPENDENCY: T2 needs a durable server `funnel_events` (or `exit_intents`) row**, not only a GA4
   gtag event, or its column cannot render. Owned by the site/overlay lane.
4. **DEPENDENCY: cohort attribution** is clean only once `offer_variants` exists (or the hardcoded
   `landing_path` map is maintained). If a variant LP ships without a mapped code, its families fall
   into `standard` and the comparative view undercounts the cohort. Keep the map in lockstep with the
   LP-variant lane's `?offer=` codes.
5. **TENSION: "converted" is per-campaign, and the conversion event for T3/T4 (tour booked / reserve)
   overlaps.** A family can read `converted` in both T3 and T4 if they booked after T3 and reserved
   after T4. That is correct (each touch gets credit for the milestone that followed it) but staff
   may read the row as double-counting. The comparative view dedupes at the FAMILY level (furthest
   milestone), so the rollup is honest even though per-cell credit overlaps. Document this in the
   grid's sub-copy.
6. **SCOPE NOTE: cohort as row-attribute vs column-group.** Directive #3 literally says "columns =
   campaigns T1/T2/T3/T4 + ad-variant cohorts". This spec renders cohort as a row attribute + filter
   + comparative table rather than as grid columns, because a family does not "receive" its own
   acquisition source (the received/engaged/converted cell vocabulary does not apply to a cohort).
   The optional `columns=cohort` provenance mode (section 4) is the literal reading if Jarred wants
   it; surface both at review.
```