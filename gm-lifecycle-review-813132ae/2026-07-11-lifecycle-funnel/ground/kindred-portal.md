# Ground truth: kindred-portal (admin) — 2026-07-11

Repo: `~/Projects/kindred-portal` (github `Winnsolutionsadmin/kindred-portal`). Branch inspected: `google-ads-status-summary` (HEAD `a37dbb2`). Autosynced to GitHub by `com.winn.projects-autosync`. Not in Drive.

This is a READ/WRITE admin SPA. It does NOT own any database. It reads/writes the Solace API (`:8100`) and reads the gm-waitlist worker (D1) through two distinct proxies. Everything below is verbatim from source, not memory.

---

## 1. Stack + how pages are built

- **React 19.2 + react-router-dom 7.14 + Vite 8 + TypeScript 6, Vitest 3.** No CSS framework, no component library, no state manager. Pure React function components with hooks.
- **Styling = inline `React.CSSProperties` objects + CSS custom properties** (design tokens like `var(--primary)`, `var(--surface-container-lowest)`, `var(--fs-md)`, `var(--radius-lg)`, `var(--ghost-border)`). No Tailwind, no CSS modules. Global CSS is `src/index.css` (holds the token definitions and the one shared class `.crm-row` used for hoverable table rows).
- **No build step for content**; `npm run dev` (vite), `npm run build` (`tsc -b && vite build`), `npm test` (vitest).
- **Page pattern (uniform across all views):** a `views/<Name>/<Name>View.tsx` default-export component + a sibling pure `<name>Helpers.ts` (all data-shaping/sorting logic, unit-tested in `views/<Name>/__tests__/`). Views own layout + fetch-hook wiring; helpers own logic. This split is enforced everywhere (Campaigns, AdsFunnel, Families, Waitlist, Agenda, Transitions all follow it). A campaign-grid page must follow the same split.
- **Layout:** `src/App.tsx` (router) → `src/layout/Shell.tsx` (outlet wrapper) → `src/layout/Sidebar.tsx` (nav). `MonthProvider` context wraps everything (`src/context/MonthContext.tsx`).

## 2. Routing conventions (`src/App.tsx`)

Flat `<Routes>` inside one `<Route element={<Shell/>}>`. Index + detail pairs use a URL param:

```
/campaigns            -> CampaignsView          (index/list)
/campaigns/:campaignId-> CampaignDetailView     (drill-down)
/ads                  -> AdsFunnelView
/families             -> FamiliesView
/families/:familyKey  -> FamilyDetailView       (:familyKey = application id, or email for leads)
/waitlist             -> WaitlistView
/agenda               -> AgendaView              (admin tasks — where Ashley works)
```

A per-family campaign GRID page is a NEW route. Recommended: add `/campaign-grid` (or `/campaigns/grid`) to `App.tsx`, a nav item in `Sidebar.tsx`, and a `views/CampaignGrid/CampaignGridView.tsx` + `campaignGridHelpers.ts`. Nav registration is a hand-maintained `navItems` array in `Sidebar.tsx` (each item = `{ to, label, iconPath }`, iconPath is a raw 24x24 SVG path string). `isActive` uses `location.pathname.startsWith(to)`, so put a grid under a distinct top-level path or it will co-highlight with `/campaigns`.

## 3. The /ads dashboard implementation (data source + how it reads ads_daily)

- **View:** `src/views/AdsFunnel/AdsFunnelView.tsx` (nav label "Ads Performance", route `/ads`). Helpers `adsFunnelHelpers.ts`. API client `src/api/adsFunnel.ts`.
- **Data source:** ONE endpoint, `GET /api/crm/ads-funnel?days=<n|omitted>&source=<attr|omitted>`. Path builder `adsFunnelPath()`. Hook `useAdsFunnel(days, source)` — it reuses the campaigns `useGet<T>` poller at `POLL_MS = 30_000`.
- **`ads_daily` is NOT read by the portal directly.** The portal has zero knowledge of the `ads_daily` table (grep for `ads_daily` in kindred-portal = 0 hits). The Google Ads delivery/spend numbers arrive already-aggregated inside the `AdsFunnelResponse.ads` block (`AdsBlock`: `present`, `totals{clicks,impressions,cost_usd,ctr_pct,avg_cpc_usd,conversions,first_date,last_date}`, `by_campaign[]{campaign_id,campaign,clicks,impressions,cost_usd,...}`). The `ads_daily` table lives in **gm-waitlist (D1)**; the worker rolls it up and the daily ads push populates it. The portal treats `ads` as OPTIONAL/back-compat (`ads?.present` guard everywhere) — it renders "No ads data pushed yet" until the block lands.
- **Response contract (`AdsFunnelResponse`)** owned by the worker, passed through 1:1 (do not rename fields in the client): `totals{emails_entered,leads_only,applied,fee_paid,reserved,tour_requested,tour_invited,tour_clicked}`, `stages[]{key,label,reached,drop_from_prev}`, `by_source[]{attr_source,leads,applications,fee_paid,reserved}`, `by_campaign[]{campaign,attr_source,applications,fee_paid}`, `people[]` (per-family `AdsPerson` rows with `attribution_source,utm_campaign,has_gclid,has_fbclid,landing_path,stage_reached,dropoff_screen,tour_requested,fee_paid_at,deposit_paid_at,tour_invite_sent_at,tour_invite_clicked_at,journey_path`).
- **Note the tour fields already exist** on `AdsPerson` (`tour_requested`, `tour_invite_sent_at`, `tour_invite_clicked_at`) and in `totals` (`tour_requested/tour_invited/tour_clicked`) — the ads funnel already surfaces tour state per family. There is NO no-show field yet anywhere in the portal.
- **Render:** stat "Total" strip + horizontal stage bars (`stagePct`) + two rollup tables (by source, by campaign) + a sortable per-person table. Cost-per-signup is computed client-side (`costPerFeePaid`). This is the exact visual vocabulary to reuse for the grid.

## 4. Auth model

- **No in-app login.** There is no auth code, no token, no session in the SPA. The whole portal sits behind **Cloudflare Access** at the edge.
- **Serving path (from kindred-portal CLAUDE.md):** `kindred.growingmindfully.org` → Cloudflare Access (allow-list: `jarred@` / `ashley@`) → CF tunnel → mini `localhost:3014` → `vite preview`.
- **Identity inside the app** comes from `GET /current-user` (hook `useCurrentUser()` in `src/api/hooks.ts`), which the backend resolves from CF-Access headers when present. Shape `CurrentUser{email,name,role,staff_id,known}`. Used for greeting, default task assignee, and `performed_by` on writes. Fallback assignee when `staff_id` is empty is literally `'stf_ashley'` (see FamilyDetailView follow-up handler) and `performed_by` falls back to `'portal'`.
- **Two proxies, two auth stories (`vite.config.ts`):**
  - `/api/*` → `http://localhost:8100` (strips `/api`). This is the **Solace API** (docker container running `server.py` via supervisord; the old launchd `:8150` is RETIRED per the 2026-06-24 cutover comment — CLAUDE.md still says `:8150` in places and is stale there). No token injected; endpoints are open behind CF Access. Serves `/tasks`, `/children`, `/forecast`, `/current-user`, `/staff`, `/admin/action`, and — importantly — proxies onward to the worker for `/api/crm/campaigns`, `/api/crm/ads-funnel` (browser `/api/crm/*` → solace-api `/crm/*` → gm-waitlist worker `/api/crm/*`; the worker's `CRM_SERVICE_TOKEN` lives server-side on solace-api).
  - `/crm-api/*` → `https://waitlist.growingmindfully.org`, rewritten to `/api/crm/*`, with `Authorization: Bearer ${CRM_SERVICE_TOKEN}` injected in the vite proxy `configure` hook (secret set via the `com.openclaw.kindred-portal` launchd `EnvironmentVariables`, never shipped to the browser). This is the **direct read-only worker path** the Families/Waitlist views use (`src/api/crm.ts`, base `/crm-api`).
  - Consequence for the grid: campaign/engagement data is reachable BOTH ways. Campaigns + AdsFunnel go through `/api/crm/*` (solace proxy). Families detail (`/crm-api/families/:key`) already returns `campaign_touches[]` per family. Pick one lane and stay in it; do not invent a third.

## 5. Admin task module — where Ashley works, how a no-show mark gets entered

- **View:** `src/views/Agenda/AgendaView.tsx` (route `/agenda`, nav "Agenda"). This is the directors' task cockpit — the place Ashley operates. Rich module set under `views/Agenda/` (TaskCard, TaskCreateModal, TemplatePicker, TaskFilters, ReportingStrip, checklist items, toasts).
- **Data:** `GET /tasks` (hook `useTasksLive()`, 30s poll + manual refetch), plus `/staff`, `/task-templates`, `/tasks/metrics`, `/current-user`. `TaskData` shape (in `api/hooks.ts`) includes `task_id,title,description,category,source('manual'|'enrollment'|'recurrence'|'compliance'|'gusto'),status('open'|'in_progress'|'done'|'cancelled'),priority,assignee_staff_id,child_id,child_name,due_date,dedup_key,checklist[]`.
- **The ONE write path for the whole admin surface:** `POST /api/admin/action` with body `{ action_type, details:{...}, performed_by }` (helper `postJSON` in `src/api/client.ts`). Existing `action_type`s: `complete_task`, `update_task_status`, `toggle_checklist_item`, `assign_task`, `create_task`, `instantiate_template`. Writes are OPTIMISTIC: stage a local patch → POST → refetch → drop patch on success, roll back + toast on failure (`optimisticWrite` in AgendaView). `putJSON` exists (`api/client.ts`) but is used only by the accountability config endpoint.
- **How a "no-show" mark would be entered (ground truth — nothing exists yet):** there is NO no-show concept in the portal today. The natural, convention-matching implementation is a new `action_type` on the existing `POST /admin/action` (e.g. `action_type:'mark_tour_no_show'`, `details:{application_id, tour_id?, no_show:true}`, `performed_by`). Two realistic entry points, both already built as surfaces:
  1. **Agenda task:** a tour produces/updates a task (the T4 lifecycle email is gated on "Ashley marked no-show"). A tour task could carry a checklist item or a bespoke "Mark no-show" button on `TaskCard`; toggling it fires `/admin/action`. This keeps the no-show flag in the Solace task store the lifecycle worker can read.
  2. **Family record:** `FamilyDetailView` already has action buttons (Create follow-up, All-dates link) and writes via `/admin/action`. A "Mark tour no-show" button there is the lowest-friction add.
  - IMPORTANT: the no-show flag must live somewhere the lifecycle-email worker (gm-waitlist) can read to SUPPRESS T4. The portal write goes to Solace (`:8100`/`solace-mirror.db`), but tour bookings + emails live in gm-waitlist (D1). So a no-show mark needs either (a) Solace → worker notify, or (b) the mark written directly to the worker via a new `/crm-api` (or `/api/crm`) mutation. This is a cross-repo seam the design agents must resolve; the portal side is trivial (one button, one `action_type` or one worker POST).

## 6. Where a per-family campaign GRID page would live + what to reuse

- **Location:** new `src/views/CampaignGrid/CampaignGridView.tsx` + `campaignGridHelpers.ts` + `__tests__/`, new route in `App.tsx`, new nav item in `Sidebar.tsx`. Follow the view/helpers split.
- **Grid shape asked for:** rows = per-waitlist-family, columns = campaigns, cell states = received / engaged-not-converted / converted; click a cell → drill (sends, opens, clicks, timestamps).
- **The cell-state substrate ALREADY EXISTS in two places:**
  1. `FamilyCampaignTouch` (in `api/crm.ts`, returned inside `FamilyDetail.campaign_touches[]`): `{campaign_id,campaign_name,wave,status,sent_at,opened_at,open_count,clicked_at,click_count}`. That is exactly received (`sent_at`) / engaged (`opened_at`/`clicked_at`) / converted (join to deposit) plus the drill-level counts + timestamps. Per-family it's one fetch (`/crm-api/families/:key`); for a full grid you'd want a new aggregate worker endpoint (e.g. `/api/crm/campaign-grid`) returning families × campaigns in one payload rather than N family fetches.
  2. `ReportResponse.families[]` (`FamilyFunnel`, per campaign) from `/api/crm/campaigns/:id/report` already has per-family `times{sent,delivered,opened,clicked,reserved}` + `stage_reached` + `deposit_cents` — the per-campaign column already exists; the grid is the transpose/union across campaigns.
- **Table/grid components already in use (reuse verbatim, do not introduce a grid lib):**
  - Shared cell/header styles: `src/views/Campaigns/styles.ts` — `thStyle` (sticky header, uppercase), `tdStyle`, `btnPrimary`, `btnOutline`, `inputStyle`.
  - Sortable header button pattern (`SortTh`) + `aria-sort` + rotate-caret SVG: copy from `FunnelReport.tsx` or `AdsFunnelView.tsx` (identical implementations). Sorting logic lives in helpers (`sortFamilies`, `sortPeople`).
  - Row hover: className `crm-row` (defined in `index.css`).
  - Cards/wrappers: `src/views/Campaigns/ui.tsx` exports `Card`, `Muted`, `PanelFallback`, `StatusBadge`, `UpdatedStamp`. `Card{title,sub}` is the standard section container used by every data panel.
  - Pill/badge state chips: local `Pill`/`StatusBadge` (tones `ok`/`gold`/`muted`/`solid`) — perfect for received/engaged/converted cell coloring.
  - Stat strip: local `Total` component (display-font number + muted label).
  - Scroll container pattern for wide tables: `overflow:auto; maxHeight:460; minWidth:<n>` wrapper (see FunnelReport / AdsFunnelView People table).
- **Fetch/polling contract to reuse:** `useGet<T>(path, POLL_MS)` from `src/api/campaigns.ts` (30s visibility-aware poll, keeps data on screen through failed polls, `UpdatedStamp` shows staleness, `PanelFallback` shows first-load/error). Every data view uses it; the grid should too. `POLL_MS = 30_000` (`campaignHelpers.ts`).
- **Journey drill link convention:** `journeyUrl(path)` (`api/crm.ts`) → `https://waitlist.growingmindfully.org<path>`; per-family journey is `/admin/journey/<application_id>`, opened in a new tab (worker admin auth, not proxied). Cell drill-downs can deep-link here or open an in-portal modal.

## 7. Load-bearing constraints for design/build agents

- Portal owns NO schema. New grid/no-show data must come from an endpoint the worker (D1) or Solace (`:8100`) already serves or newly serves. Do not add DB columns from here.
- All admin writes go through `POST /api/admin/action` (Solace) OR a worker `/api/crm` (solace-proxy) / `/crm-api` (direct, tokened) mutation. The public waitlist flow's write rules (never `children`, never Solace enroll gate) are a gm-waitlist concern, but any no-show/lifecycle write the portal issues must respect them.
- Family key duality: application id for `type:'application'`, email for `type:'lead'`. Leads have no application/reserve calendar (worker returns 404 on reserve/override mints for leads). A campaign grid keyed on families must handle both, or scope to applicants only (as `WaitlistView` does with `tag:'applicant'`).
- Deploy is guarded: `ssh mini "~/bin/deploy-kindred-portal.sh"` (served tree is `/Users/clawd/kindred-portal-app`, must be clean + on `main`). Verify at mini `localhost:3014` (bypasses CF Access). Prod deploy is a Tier-2 Jarred gate.
- No em dashes in any copy/code (repo-wide hard rule).
