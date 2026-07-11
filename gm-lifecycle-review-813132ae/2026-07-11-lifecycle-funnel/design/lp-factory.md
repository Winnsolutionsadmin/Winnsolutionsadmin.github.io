# DESIGN: LP Factory - Uniform Template + V1-V5 Variant Stamps (2026-07-11)

Lane deliverable for the lifecycle-funnel ad-variant matrix. Designs ONE uniform landing-page
template and the per-variant stamp registry for V1-V5, so a build agent can cut five (or more)
message-matched, isolation-compliant LPs from a single source of truth. Companion artifact:
`design/lp-open-enrollment-mockup.html` (the built V1 mockup).

Grounded in: `ground/site-lp-conventions.md` (template anatomy), `ground/waiver-package.md`
(reusable backend + policy), `CONTEXT-PACK2.md` (directive + HOOTL mandate), and the built
`2026-07-10-tour-waiver-test/lp-tour-offer-mockup.html` (V1's ancestor). Nothing here executes;
parent-facing copy + prod deploy are Tier 2 Jarred gates.

Zero em dashes. Zero new licensing text. Every dollar/urgency claim is conditioned in the same
asset. Verify against `ground/site-lp-conventions.md` sec 11 before any Tier-2 gate.

---

## 0. The factory model in one paragraph

Every variant LP is the SAME file with a handful of slots swapped. The FIXED spine (head gtag +
track.js + fonts + noindex + canonical, `:root` brand tokens, reset, header lockup, section CSS,
reviews band, footer, instrumentation contract) is stamped identically. The VARIANT layer is a
short manifest per campaign: slug, title/meta, hero (kicker + H1 + sub + condition-line), CTA
architecture (overlay-flow vs tour-calendar), `?offer=` code, utm entry, hero photo, chips, body
sections, final-CTA copy. Two source-of-truth files govern it: this doc (copy + registry) and
`ground/site-lp-conventions.md` (the verbatim shared blocks). A build agent reads the FIXED spine
from site-lp-conventions sec 2-8 and fills the slots from section 3 + 5 below.

---

## 1. Variant registry (the authoritative stamp table)

Slugs are from the direct lane instruction (they win over the site-lp-conventions proposed slugs
where they differ; `fee-waived-65` here, not `waitlist-fee-waived`). One directory per LP:
`growingmindfully/lp/<slug>/index.html`, pretty URL `/lp/<slug>/`.

| V | Slug (`/lp/<slug>/`) | Public brand | `?offer=` code | Offer class | CTA arch | Backend mechanic | Distinct `landing_path` |
|---|---|---|---|---|---|---|---|
| V1 | `open-enrollment` | OPEN ENROLLMENT! | `open-enrollment` | WAIVER-BEARING | tour-calendar (6b) | $65 waitlist fee waived on tour completion (`tour_waivers`, `pending_tour`) | `/lp/open-enrollment/` |
| V2 | `back-to-school` | Back to School | `back-to-school` | TRACKING-ONLY | overlay-flow (6a) | Standard flow, $65 fee normal. Seasonal availability push. | `/lp/back-to-school/` |
| V3 | `fees-waived` | $100+ in fees waived | `fees-waived` | WAIVER-BEARING (STACKED, gated) | tour-calendar (6b) | $65 waitlist + $45 enrollment stacked. $45 half NOT automated - see sec 7 T-1. | `/lp/fees-waived/` |
| V4 | `free-tour` | Free no obligation tour | `free-tour` | TRACKING-ONLY | tour-calendar (6b) | Pure tour booking, no fee mechanic. | `/lp/free-tour/` |
| V5 | `fee-waived-65` | $65 waitlist fee waived | `fee-waived-65` | WAIVER-BEARING | tour-calendar (6b) | Same backend as V1, different creative framing (explicit dollar). | `/lp/fee-waived-65/` |

**Offer-code class is the single most load-bearing field for the waitlist-flow lane.** Split:

- **WAIVER-BEARING** (`open-enrollment`, `fees-waived`, `fee-waived-65`): the backend
  `POST /api/applications` waiver branch (waiver-package 1a) MUST recognize these codes, require a
  matching `tour_booking_id`, insert `status='pending_tour'`, `fee_paid=0`, create a `tour_waivers`
  row, and return `waiver:true` so the front end skips Stripe. The `tour_waivers.offer_code`
  column (defaulted `'tour-waiver'` in the source design) becomes per-variant here: store the exact
  `?offer=` code so V1 vs V5 vs V3 are separable in the DB, not just in GA4.
- **TRACKING-ONLY** (`back-to-school`, `free-tour`): the code rides for attribution
  (`gmwl_offer_ctx`, GA4 event params, `landing_path`) but the backend does NOT treat it as a
  waiver. Standard flow, standard $65 fee. If one of these codes ever reaches the waiver branch it
  must be rejected as not-a-waiver-code (whitelist the three waiver codes server-side; do not
  waive on any unknown `offer`).

This split is the guardrail against V2/V4 accidentally waiving fees. The build + waitlist-flow lanes
must implement a server-side allowlist `WAIVER_OFFER_CODES = {open-enrollment, fees-waived,
fee-waived-65}`; everything else is tracking-only.

---

## 1b. Cross-lane registry reconciliation (READ THIS, synthesizer) - one canonical `?offer=` set

The sibling `design/ad-variants.md` (AD-VARIANT-MATRIX lane) independently chose DIFFERENT slugs and
`?offer=` codes for three variants and added two bench variants. Two design docs handing the
waitlist-flow lane two different code sets is a real defect: `tour_waivers.offer_code`, the
`WAIVER_OFFER_CODES` server allowlist, and the LP `?offer=` param MUST be byte-identical or waivers
silently fail (an unrecognized code falls through the waiver branch and the family is charged, or a
tracking-only code reaches the waiver branch and is wrongly waived). There must be exactly ONE set.

**This doc (the LP factory, which owns the LP layer) is canonical. It matches the direct lane
instruction's slug list and the already-built V1 mockup.** Alias map + recommended harmonization:

| V | CANONICAL slug + `?offer=` (this doc) | ad-variants.md value | Resolution |
|---|---|---|---|
| V1 | `open-enrollment` / `open-enrollment` | same | agree, no action |
| V2 | `back-to-school` / `back-to-school` | same | agree, no action |
| V3 | `fees-waived` / **`fees-waived`** | `fees-waived` / `fees-waived-100` | offer code differs: canonical drops the `-100` suffix (slug and code match; simpler allowlist entry). ad-variants updates its Final URL. |
| V4 | `free-tour` / **`free-tour`** | `book-a-tour` / `tour` | slug + code differ. See NUANCE below - this is the one the synthesizer should actively arbitrate. |
| V5 | `fee-waived-65` / **`fee-waived-65`** | `waitlist-fee-waived` / `waitlist-fee-waived` | canonical keeps the instructed `fee-waived-65`; ad-variants harmonizes. (Both are fine; pick one and lock it.) |

**V4 NUANCE (flag for synthesizer, do not silently override):** the direct lane instruction gave the
slug `free-tour`, so this doc keeps it as canonical. BUT ad-variants' `book-a-tour` is arguably more
compliant: the A-lane "no free tour" precision rule bans manufacturing a "free" claim, and Google
reviewers see the Final URL. `book-a-tour` keeps "free" out of the URL entirely, matching the LP copy
that already scrubs it (V4 hero, sec 3). Recommendation: if the synthesizer weights policy-precision
over the instruction's literal slug, switch V4 canonical to `book-a-tour` / `tour`. Either way, ONE
value propagates to the LP dir, the `?offer=` param, the utm registry (sec 2), and ad-variants. This
is the only genuinely open naming call; the other three are mechanical harmonizations to this table.

**Bench audience-cuts (from ad-variants, folded in so the registry is complete):** V6 Infant
(`/lp/infant-tour/`, `?offer=infant-tour-waiver`, WAIVER-BEARING) and V7 State-employee
(`/lp/state-tour/`, `?offer=state-tour-waiver`, WAIVER-BEARING) are wave-2 audience narrows of the
wave-1 winning offer, not new mechanics. They inherit the winner's backend gate and MUST be added to
`WAIVER_OFFER_CODES` when deployed. Slug-collision guard: distinct `infant-tour` / `state-tour` slugs
avoid clobbering the LIVE `lp/infant-openings/` and `lp/state-employees/` LPs (see ad-variants sec 4).

**Canonical `WAIVER_OFFER_CODES` (the single allowlist the waitlist-flow lane implements):**
`{open-enrollment, fees-waived, fee-waived-65}` at launch, `+ {infant-tour-waiver, state-tour-waiver}`
when V6/V7 deploy. `back-to-school`, `free-tour` (V4) are tracking-only and MUST NOT appear in it.
If the synthesizer flips V4 to `book-a-tour`/`tour`, then `tour` is the tracking-only V4 code (still
NOT in the allowlist). Everything not in the allowlist is charged the standard $65.

---

## 2. UTM + Ads Final URL registry

Google Ads auto-tagging (`gclid`) is the primary attribution key; explicit utm params give GA4 a
clean channel/campaign grouping and feed the Kindred campaign grid's per-campaign columns. The
`?offer=` param is the waiver-flag + variant key and is ALWAYS present. Final URL pattern:

```
https://www.growingmindfully.org/lp/<slug>/?offer=<code>&utm_source=google&utm_medium=cpc&utm_campaign=<camp>&utm_content=<content>
```

| V | utm_campaign | utm_content | Ads Final URL (offer + utm) |
|---|---|---|---|
| V1 | `gm-open-enrollment` | `v1-open-enrollment` | `/lp/open-enrollment/?offer=open-enrollment&utm_source=google&utm_medium=cpc&utm_campaign=gm-open-enrollment&utm_content=v1-open-enrollment` |
| V2 | `gm-back-to-school` | `v2-back-to-school` | `/lp/back-to-school/?offer=back-to-school&utm_source=google&utm_medium=cpc&utm_campaign=gm-back-to-school&utm_content=v2-back-to-school` |
| V3 | `gm-fees-waived` | `v3-fees-waived-100` | `/lp/fees-waived/?offer=fees-waived&utm_source=google&utm_medium=cpc&utm_campaign=gm-fees-waived&utm_content=v3-fees-waived-100` |
| V4 | `gm-free-tour` | `v4-free-tour` | `/lp/free-tour/?offer=free-tour&utm_source=google&utm_medium=cpc&utm_campaign=gm-free-tour&utm_content=v4-free-tour` |
| V5 | `gm-fee-waived-65` | `v5-fee-waived-65` | `/lp/fee-waived-65/?offer=fee-waived-65&utm_source=google&utm_medium=cpc&utm_campaign=gm-fee-waived-65&utm_content=v5-fee-waived-65` |

Notes: keep utm_medium=cpc (not "ppc") to match the existing account convention. Auto-tagging must
stay ON; do not strip `gclid`. The campaign-grid lane keys columns on `utm_campaign` (stable) and
can drill to `utm_content` for creative-level reads. Confirm final campaign/adgroup names with the
gm-ads lane before wiring; the utm_campaign values above are the proposed canonical set.

---

## 3. ALL variant heroes (write ALL, per lane instruction)

Each hero fills: `.kicker` (uppercase, leading rule), `<h1>` with the italic teal `<em>` tail (house
signature), `.sub` (1-2 sentences, location + offer), `.condition-line` (REQUIRED on any $/urgency
claim), CTA label. Copy is Tier-2 gated; these are the drafts for Jarred read. `[[EXPIRY]]` marks a
build-time real date that MUST be filled and MUST actually rotate (see sec 8).

### V1 - OPEN ENROLLMENT! (`/lp/open-enrollment/`, tour-calendar, waiver-bearing)
- **kicker:** `Open enrollment`
- **H1:** `Open enrollment is here. <em>Tour us, skip the waitlist fee.</em>`
- **sub:** `Growing Mindfully sits on the top floor of 750 N Street, a five minute walk from the Capitol. Come see the infant, toddler, and preschool rooms in person, then join our waitlist with the fee waived.`
- **condition-line:** `The waiver is conditional: <strong>book a tour and complete it</strong>, and we waive the $65 waitlist fee that normally holds your family's place. If the tour is cancelled or skipped, the standard $65 fee applies.`
- **CTA label:** `See tour times` (hero + final, anchors `#tour-calendar`)
- Built in full at `design/lp-open-enrollment-mockup.html`.

### V2 - Back to School (`/lp/back-to-school/`, overlay-flow, tracking-only)
- **kicker:** `Back to school`
- **H1:** `Start the school year <em>somewhere calm.</em>`
- **sub:** `Fall spots are opening at Growing Mindfully in downtown Sacramento. Infant rooms have the most room right now, with preschool openings too. Check your child's room and hold a place before the school year fills.`
- **condition-line:** OMIT. V2 makes no dollar or urgency claim, so no conditional disclosure is
  needed. (Adding an unconditioned "spots filling" line is fine only if truthful; keep it soft, e.g.
  a chip, not a fear claim.)
- **CTA label:** `Check availability` (hero `data-gm-waitlist="open"` anchor to `#cta-section`;
  final `.btn-paper` same). Optional secondary `Book a free tour` -> `/tour/`.
- Body sections: 3-step "how the waitlist works" (adapt from steps), reviews, final CTA.

### V3 - $100+ in fees waived, this week only (`/lp/fees-waived/`, tour-calendar, STACKED-gated)
- **kicker:** `This week only`
- **H1:** `Over $100 in fees waived <em>when you tour this week.</em>`
- **sub:** `Tour Growing Mindfully in downtown Sacramento this week and we waive both the $65 waitlist fee and the $45 enrollment fee. See the rooms, meet the teachers, hold your family's place.`
- **condition-line:** `Here's the fine print, in plain terms: <strong>complete a tour by [[EXPIRY]]</strong> and reserve your space, and both the $65 waitlist fee and the $45 enrollment fee are waived, a total over $100. Miss the tour or the date and the standard fees apply.`
- **CTA label:** `See tour times`
- **BLOCKED until sec 7 T-1 resolves.** The $45 enrollment-fee waiver is NOT automated (manual
  Brightwheel). Do not run V3 on the current process. Options in sec 7.
- If de-scoped to $65-only, V3 collapses into a duplicate of V5 and should be dropped or reframed.

### V4 - Free no obligation tour (`/lp/free-tour/`, tour-calendar, tracking-only)
- **kicker:** `Come visit`
- **H1:** `See our school first. <em>No pressure, no obligation.</em>`
- **sub:** `Book a 30 minute visit to Growing Mindfully on the top floor of 750 N Street, five minutes from the Capitol. Walk the infant, toddler, and preschool rooms, ask anything, and decide in your own time.`
- **condition-line:** OMIT (no dollar claim). A soft note line is fine: `Tours are 30 minutes, family-friendly, and there is never any obligation to enroll.`
- **CTA label:** `See tour times`
- **Copy-precision flag (sec 7 T-2):** the ad brand is "Free no obligation tour," but tours never
  carried a price, so the LP must NOT manufacture a "free tour" claim (A-lane "no free tour" rule).
  On the page say "book a tour" / "no obligation," not "free tour." The word "free" stays in the ad
  headline (Jarred listed V4 explicitly) but is scrubbed from the destination to avoid a double-free
  ambiguity. This variant has no fee mechanic, so there is no fee-waiver claim to condition.

### V5 - $65 waitlist fee waived (`/lp/fee-waived-65/`, tour-calendar, waiver-bearing)
- **kicker:** `Waitlist fee waived`
- **H1:** `Your $65 waitlist fee, <em>waived when you tour.</em>`
- **sub:** `Growing Mindfully is enrolling in downtown Sacramento. Book a tour, see the rooms in person, and the $65 fee that normally holds your family's place is on us.`
- **condition-line:** `One condition: <strong>book a tour and complete it</strong>, and the $65 waitlist fee is waived. If the tour is cancelled or skipped, the standard $65 fee applies.`
- **CTA label:** `See tour times`
- Same backend as V1; the ONLY differences from V1 are kicker/H1/sub framing (explicit dollar vs
  "open enrollment" brand) and the `?offer=` code. This is the deliberate head-to-head: does the
  dollar-explicit frame or the brand frame convert better? Keep everything else byte-identical so the
  read is clean.

**Optional V6+ (brainstorm, CONTEXT-PACK2 item 8):** a `state-employees` waiver crossover
(`/lp/state-employee-tour/`, priority-rate + tour-waiver stack) is the highest-EV extra variant given
the account's one real conversion (Flynn, a state employee) came from that intent. Hold as a fast
follow, not part of the first V1-V5 batch.

---

## 4. The FIXED spine (what a build agent copies verbatim, does NOT author)

Pulled from `ground/site-lp-conventions.md`; do not re-invent. A build agent stamps these unchanged:

1. **`<head>`** (site-lp-conventions sec 2): gtag `G-QK5VPGREL8` block, `track.js`, fonts preload,
   `robots noindex, follow`, self-canonical, og block. Swap only {title, meta desc, canonical slug,
   og:title, og:desc, og:image}. The mockup shows the exact filled head for V1.
2. **`:root` + reset + type ramp** (sec 3): the mockup superset tokens, reduced-motion guard, and the
   `opsz`/`wght` `font-variation-settings` on h1/h2 with the teal `<em>` signature. FIXED.
3. **Header lockup** (sec 5): `<img src="/assets/mark.webp">` + `<img src="/assets/wordmark.webp">`,
   `.brand .wordmark { height: 40px }` desktop / `38px` + `max-width:46vw` under 720px. ISOLATION
   CHOICE: on test LPs the lockup is NOT wrapped in `<a href="/">` (removes the top-left escape hatch;
   honors zero-internal-links). See sec 5 decision D-LP-1.
4. **Reviews band** (sec 8): verbatim 5.0/27 rating line + 3 real Google-review quotes, all
   attributed "Parent · Google review". Keep on EVERY variant for trust. Present in the mockup.
5. **Footer** (sec 5): 3 columns + `.foot-meta` verbatim (CDSS badge stays, add nothing). ISOLATION
   CHOICE: the "More" column carries ONLY `/privacy/` + `/terms/` (legal necessity), dropping
   `/rates/` and any cross-LP marketing link. See sec 5 decision D-LP-2.
6. **Instrumentation** (sec 7 of conventions): `track.js` auto-fires `waitlist_start`,
   `contact_phone`, `contact_email`. Tour calendar fires `tour_booked` stitched to server
   `gmwl_tour_booked`. Lifecycle adds `lp_tour_offer_view` + `tour_booked_from_offer` (sec 6 below).
7. **Overlay embed pair** (sec 6a): only on overlay-flow LPs (V2). `overlay.css?v=33` +
   `overlay.js?v=36` from `waitlist.growingmindfully.org`. Never bundle the widget.

---

## 5. Isolation posture per variant (the ISOLATION MANDATE, applied)

Every variant LP is a dark page (site-lp-conventions sec 10). Per-variant checklist:

- `<meta name="robots" content="noindex, follow">` + self-canonical to its own `/lp/<slug>/`.
- Absent from `sitemap.xml` and `robots.txt` (by omission - keep it that way).
- ZERO internal marketing links. Reachable only by ad click. Waiver flag only via `?offer=`.
- `functions/_middleware.js` does NOT block `lp/<slug>/` (only the enumerated dev paths); a public
  LP file serves normally. If a variant must also stay dark on `*.pages.dev` previews, extend the
  narrow `isTourPreview` exception pattern, not the denylist.

Two isolation decisions this lane makes (defaults chosen; flagged for the synthesizer, not
Jarred-blocking since they are architecture, not parent-facing copy):

- **D-LP-1 (logo not linked):** the header lockup renders as a non-clickable `<span>` on test LPs,
  not `<a href="/">`. Rationale: a home link is the single biggest "leave the conversion path"
  affordance and the exact discovery path isolation wants closed. The live evergreen LPs
  (`/lp/state-employees/`) DO link the logo home; this is a deliberate divergence for the noindexed
  test set. Reversible with one attribute if the synthesizer prefers brand-consistency over strict
  isolation.
- **D-LP-2 (footer legal-only):** footer "More" column = `/privacy/` + `/terms/` ONLY. Rationale:
  privacy/terms are a legal necessity on a data-capture page (waitlist + CAN-SPAM adjacency);
  `/rates/` and cross-LP links are pure marketing internal links that leak the funnel and entangle
  the test. Same-tab, standard links. This is stricter than site-lp-conventions sec 5 ("keep
  /rates/ /privacy/ /terms/"); the isolation mandate (2026-07-11) is later and stricter, so it wins.

**Per-deploy verification (extends the source package grep to the full matrix):** before any push,
for EACH slug run `grep -rn "lp/<slug>" growingmindfully/` and confirm the ONLY hits are the LP's own
dir (plus `_redirects`/`_headers` if a vanity path was added). No nav, footer, homepage, or sitemap
hit. Also grep every LP for `fee` and confirm each hit is conditioned (the standing
`/state-employees/` "no application fee" bug-class guard).

---

## 6. Two CTA architectures, mapped per variant

Full wiring in `ground/site-lp-conventions.md` sec 6. Assignment:

- **Overlay-flow (6a):** V2 only. Hero `<a href="#cta-section" data-gm-waitlist="open">Check
  availability</a>`; final `.btn-paper` same. Loads `overlay.css?v=33` + `overlay.js?v=36`.
  `track.js` fires `waitlist_start` on the click.
- **Tour-calendar (6b):** V1, V3, V4, V5. Lift `<section class="cal-section">` + the booking IIFE
  from `tour/index.html` ln 342-651 + `.cal-*`/`.book-*`/`.time-*` CSS. Mount `<div id="tourCal">`.
  Slots read `GET https://waitlist.growingmindfully.org/api/tours/slots?days=45&limit=120`; booking
  `POST /api/tours/book` (rate-limited 4/hr). Times PT, America/Los_Angeles. Google-scheduler iframe
  fallback on `data.stale`. Hero CTA anchors `#tour-calendar` (not the overlay).

**Offer-context handoff (6c), all variants:** an inline script reads `location.search`, writes
`sessionStorage.gmwl_offer_ctx = {offer, lp, ts, utm_campaign, utm_content, gclid}` (mockup has the
exact code, hostname-guarded). Fire `lp_tour_offer_view` on load. On tour-booking success (calendar
variants), fire `tour_booked` AND `tour_booked_from_offer` (params `offer, lp, slot`) and merge
`tour_booking_id` + slot ISO into `gmwl_offer_ctx`. For waiver-bearing variants, the overlay/app mount
reads `gmwl_offer_ctx` and attaches `offer_code` + `tour_booking_id` to the application payload
(waiver-package 1c two-layer capture). "Update all databases" (directive item 1) = this fan-out:
booking writes D1 (`tour_bookings` + `tour_waivers`), GA4 (`gmwl_tour_booked` server MP +
`tour_booked_from_offer` client), and the dashboards/grid (`landing_path` + `utm_*` carried through).

New GA4 events to register as key events before Ads import (confirm `gmwl_` prefix with gm-ads):
`lp_tour_offer_view`, `tour_booked_from_offer`. `gmwl_tour_booked` already exists (server MP), just
needs promotion to key-event + import per directive item 1.

---

## 7. Flagged tensions this lane surfaces (do NOT let slip)

- **T-1 (V3 stacked $45, blocking):** V3 "$100+" advertises the $45 enrollment-fee waiver, which is
  NOT automated (manual Brightwheel; waiver-package sec 3 change #3 + A-lane "unavailable offer"
  exposure). Resolve before V3 or lifecycle T3/T4 runs: (a) build the $45 waiver automation /
  verified SOP, (b) scope V3 so the $45 half is honored by an airtight gated process, or (c) drop V3
  to $65-only (which duplicates V5 - then drop or reframe V3). Recommendation: hold V3 out of the
  first batch; ship V1/V2/V4/V5 first, add V3 once the $45 path is real.
- **T-2 (V4 "free tour" precision):** scrub "free tour" from the V4 destination (tours never had a
  price; manufacturing a second "free" claim trips the A-lane rule). Ad headline may keep "free" per
  Jarred's explicit V4 listing; the LP says "book a tour" / "no obligation." Handled in the V4 hero
  above.
- **T-3 (clickwrap v2, blocking for waiver variants):** V1, V3, V5 defer the $65 fee, which
  contradicts the current `waitlist-v1.ts` clickwrap ("$65 non-refundable... regardless"). A
  counsel-reviewed `waitlist-v2.ts` (SHA-256 version bump, D4) is REQUIRED before any waiver-bearing
  variant launches. Tracking-only V2/V4 are not blocked by this.
- **T-4 (urgency must expire):** V3's "this week only" and any time-boxed claim must carry a REAL
  `[[EXPIRY]]` date in `.condition-line` and actually rotate (sec 8). Evergreen = policy risk.
- **T-5 (isolation surface multiplies):** five slugs = five per-deploy grep checks (sec 5). Bake the
  per-slug grep into the deploy checklist; a single missed internal link entangles the whole A/B read.
- **T-6 (V2/V4 must not waive):** the server-side `WAIVER_OFFER_CODES` allowlist (sec 1) is the guard;
  without it, a tracking-only `?offer=` could reach the waiver branch. Non-negotiable for the
  waitlist-flow lane.

---

## 8. Urgency / expiry design (V3 and any time-boxed variant)

"This week only" claims must expire and rotate, or they are deceptive-urgency policy risk. Two
mechanisms, in preference order:

1. **Real date in the condition-line + weekly rotation (recommended, simplest, HOOTL-friendly):** the
   `.condition-line` states an actual date (`complete a tour by Friday, July 18`). The offer is
   genuinely honored only through that date; a scheduled weekly swap updates the date (and the offer
   window resets). Implement as a small dated content rotation in the deploy cadence or a scripted
   swap; the date is a build-time slot `[[EXPIRY]]`, never hardcoded evergreen. Because the whole
   lifecycle system is HOOTL, the rotation should be agent-owned (a scheduled job flips the date and
   re-verifies), not a manual weekly edit.
2. **Ad-schedule / campaign flighting:** run V3 in genuine weekly flights (campaign scheduled to a
   real window), so "this week" maps to an actual served window. Heavier; pairs with mechanism 1.

If neither can be guaranteed at build time, DROP the urgency phrasing and run V3 as an evergreen
"$100+ in fees waived when you tour" (still conditioned, no false "this week"). Never ship an
evergreen page that says "this week only."

---

## 9. HOOTL governance mapping (per CONTEXT-PACK2 mandate)

Every LP-factory component mapped to autonomy class / evidence trail / escalation target / kill
switch, for the MASTER-PLAN "HOOTL Governance" section:

| Component | Autonomy class | Evidence at act time | Escalation target | Kill switch |
|---|---|---|---|---|
| LP serve + `?offer=` capture | Autonomous (static) | `gmwl_offer_ctx` in sessionStorage; `lp_tour_offer_view` GA4 event; `landing_path` in D1 attribution | none (static asset) | pause/remove the Ads campaign (traffic source); LP left dark = zero traffic |
| Tour booking fan-out (D1 + GA4 + dashboards) | Autonomous | `tour_bookings` row + `gmwl_tour_booked` (server MP) + `tour_booked_from_offer` (client) + grid `landing_path`/`utm` | `#biz-gm-ads` on booking-write failure | `TOURS_KILL=1` / `TOURS_ENABLED=0` (existing double gate) |
| Waiver-flag application branch | Autonomous, allowlist-gated | `tour_waivers` row (`offer_code`, `waiver_state='pending_tour'`); `waiver:true` payload | `#biz-gm-ads` on mismatch/abuse | `WAIVER_OFFER_CODES` allowlist emptied = no waivers honored; per-code removable |
| Urgency date rotation (V3) | Autonomous (scheduled swap) | change-log entry per date flip; deploy record | `#biz-gm-ads` if a swap fails (stale date is the risk) | disable the rotation job; pull V3 campaign |
| Per-deploy isolation grep + `fee`-conditioned grep | Autonomous verify (CI/pre-deploy) | grep output logged in deploy record | `#biz-gm-ads` on any unexpected internal-link hit | deploy blocked on grep failure (fail-closed) |

Human gates that STAY (Tier 2, the single batched inquiry, never drip): parent-facing LP copy
approval (sec 3 heroes), clickwrap v2 (T-3), budget for the V1-V5 matrix, prod deploy of each LP,
and the D1-D9 waiver decisions. These are the ONLY LP-factory items that reach Jarred; everything
else self-heals or pauses the traffic source.

---

## 10. Build-order recommendation (what ships first)

1. **V1 `open-enrollment` + V5 `fee-waived-65`** first: same proven backend mechanic (tour-waiver),
   clean head-to-head (brand frame vs dollar frame), both gated only by clickwrap v2 (T-3). V1 mockup
   is built; V5 is a near-clone (swap hero + offer code).
2. **V2 `back-to-school`**: tracking-only, overlay-flow, no waiver/clickwrap dependency, lowest risk.
   Ships as soon as copy is approved.
3. **V4 `free-tour`**: tracking-only, tour-calendar, gated only on the T-2 copy scrub.
4. **V3 `fees-waived`**: LAST. Blocked on T-1 ($45 automation) + T-4 (urgency rotation) + T-3
   (clickwrap). Do not include in the first batch.

Each ship is a Tier-2 Jarred-gated prod deploy of parent-facing copy; surface as part of the single
batched launch report, not as five separate asks.

---

## 11. File index

- Built V1 mockup: `design/lp-open-enrollment-mockup.html` (this dir).
- Template anatomy (verbatim shared blocks): `ground/site-lp-conventions.md`.
- Reusable backend + policy + measurement: `ground/waiver-package.md` and the source lanes in
  `2026-07-10-tour-waiver-test/` (D/A/B/C/E + `lp-tour-offer-mockup.html`).
- Directive + HOOTL mandate: `CONTEXT-PACK2.md` (this dir).
