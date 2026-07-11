# Site LP Conventions - Reusable LP Template Anatomy (2026-07-11)

Ground doc for the lifecycle-funnel ad-variant matrix. Maps the growingmindfully static
site's landing-page conventions into a **factory template**: the exact shared blocks a build
agent stamps once, and the per-campaign slots it swaps per variant (V1 OPEN ENROLLMENT, V2
Back to School, V3 $100+ fees waived, V4 free tour, V5 $65 waived).

Sources mapped (all in `~/Projects/growingmindfully`):
- `lp/state-employees/index.html` (359 ln), `lp/infant-openings/index.html` (344),
  `lp/daycare-sacramento/index.html` (361) - the three live LPs, identical skeleton.
- `tour/index.html` (653) - the live calendar-first booking page (noindex, 0 internal links).
- `_headers`, `_redirects`, `functions/_middleware.js`, `sitemap.xml`, `robots.txt`, `assets/track.js`.
- Mockup: `~/Projects/gm-master/.../2026-07-10-tour-waiver-test/lp-tour-offer-mockup.html`
  (the most complete template - adds 3-step, calendar placeholder, trust band, FAQ, reduced-motion).
- Front-end offer contract: `.../2026-07-10-tour-waiver-test/C-landing-page.md` (secs 5-6).

The three live LPs are byte-identical in head, `:root`, reset, header, footer, final-CTA,
reviews, gtag, and overlay embed. They diverge ONLY in the copy slots enumerated in section 9.
That identity IS the template. Stamp it; fill the slots.

---

## 1. Routing + directory convention (where a variant lives)

- One directory per LP: `lp/<campaign-slug>/index.html`. Pretty URL `/lp/<slug>/`.
  Proposed lifecycle-funnel slugs: `lp/open-enrollment/`, `lp/back-to-school/`,
  `lp/fees-waived/`, `lp/free-tour/`, `lp/waitlist-fee-waived/`. Kebab-case, no dates in slug.
- Static file, no build step. Edit HTML in place, commit to `main`, `git push origin main`
  (single-repo Cloudflare Pages model). Deploy of parent-facing copy is a **Tier 2 Jarred gate**.
- The tour-flavored variants reuse the `/tour/` calendar (see sec 6), not the overlay.

---

## 2. The `<head>` block (verbatim shared, 4 variant slots)

Lines below are the live LP head (`lp/state-employees` ln 3-43). Copy verbatim; swap only the
4 SLOT markers. `[[...]]` = per-variant fill.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<!-- Google Analytics 4 (GTM-less direct gtag. Ad signals + ad-personalization ON for
     Google Ads attribution / enhanced conversions.) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-QK5VPGREL8"></script>
<script defer src="/assets/track.js"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-QK5VPGREL8', {
    'allow_google_signals': true,
    'allow_ad_personalization_signals': true
  });
</script>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title>[[SLOT: title - <=60 char, brand suffix "· Growing Mindfully"]]</title>
<meta name="description" content="[[SLOT: meta description ~155 char]]">

<!-- Dedicated Google Ads landing page. Kept out of the organic index. AdsBot unaffected. -->
<meta name="robots" content="noindex, follow">
<link rel="canonical" href="https://www.growingmindfully.org/lp/[[SLOT: slug]]/">

<meta property="og:type" content="website">
<meta property="og:url" content="https://www.growingmindfully.org/lp/[[SLOT: slug]]/">
<meta property="og:site_name" content="Growing Mindfully">
<meta property="og:title" content="[[SLOT: og title]]">
<meta property="og:description" content="[[SLOT: og description]]">
<meta property="og:image" content="https://www.growingmindfully.org/assets/community.jpg">
<meta property="og:image:alt" content="Children smiling together on the Capitol lawn near Growing Mindfully in downtown Sacramento.">
<meta name="twitter:card" content="summary_large_image">

<meta name="theme-color" content="#FBF7EE">
<link rel="icon" href="/assets/mark.png">
<link rel="apple-touch-icon" href="/assets/mark.png">

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="preload" as="style" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,200..800;1,6..72,200..800&family=Manrope:wght@300;400;500;600;700&family=Caveat:wght@400;600&display=swap" onload="this.onload=null;this.rel='stylesheet'">
<noscript><link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,200..800;1,6..72,200..800&family=Manrope:wght@300;400;500;600;700&family=Caveat:wght@400;600&display=swap" rel="stylesheet"></noscript>
```

Head SLOTS = {title, meta description, canonical slug, og:title, og:description}. Everything
else (gtag id `G-QK5VPGREL8`, track.js, fonts, robots noindex, favicon, theme-color) is FIXED.

**Ads-signal variant (offer pages only):** the Ads Final URL carries `?offer=<name>` (e.g.
`?offer=tour-waiver`). No head change; a small inline script reads `location.search` and stashes
`gmwl_offer_ctx` in sessionStorage. See sec 6.

---

## 3. Brand token block (`:root`) - the canonical design system, FIXED

The mockup's `:root` is the fullest set (adds `--paper-deeper`, `--dusty*`, `--blush`,
`--gutter`, and the reduced-motion guard the 3 live LPs omit). Use the MOCKUP superset as the
template `:root`:

```css
:root {
  --paper: #FBF7EE; --paper-deep: #F0E9D8; --paper-deeper: #EAE1CB;
  --ink: #1F2A2E; --ink-soft: #3F5359; --ink-mute: #6F7F84;
  --teal: #5FAEB6; --teal-deep: #3D8189;      /* teal-deep = primary action color */
  --sage: #9BB99E; --sage-deep: #6F8F70;
  --dusty: #7AA8C4; --dusty-deep: #4F7A99;
  --gold: #C9A86A; --blush: #E8C9B5;
  --shadow-soft: 0 1px 2px rgba(31,42,46,0.04), 0 8px 24px rgba(31,42,46,0.06);
  --serif: "Newsreader", Georgia, serif;
  --sans: "Manrope", "Helvetica Neue", system-ui, sans-serif;
  --hand: "Caveat", cursive;
  --gutter: clamp(1.25rem, 4vw, 3rem);
  --radius: 6px;
}
```

Base reset (FIXED, verbatim), plus the reduced-motion guard the template should keep:

```css
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { -webkit-font-smoothing: antialiased; scroll-behavior: smooth; background: var(--paper); }
body { font-family: var(--sans); background: var(--paper); color: var(--ink); font-size: 17px; line-height: 1.65; overflow-x: hidden; }
img { display: block; max-width: 100%; height: auto; }
a { color: inherit; text-decoration: none; }
.wrap { max-width: 1100px; margin: 0 auto; padding: 0 var(--gutter); position: relative; }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } html { scroll-behavior: auto; } }
```

Type ramp (FIXED): `h1` uses `font-variation-settings: "opsz" 72, "wght" 380`, `clamp(2.3rem,
7.4vw, 4rem)`, `max-width: 18ch`, `<em>` italic in `--teal-deep`. `h2`: opsz 48 / wght 400,
`clamp(1.75rem, 4.6vw, 2.7rem)`, `<em>` teal-deep. The italic-`<em>`-in-teal accent on the
last phrase of every headline is the house signature - keep it on every stamped headline.

---

## 4. Shared CSS component inventory (which classes are universal)

The template ships ONE `<style>` block. Classes fall in two tiers:

**Tier A - ALWAYS present (every LP):** `.lp-top .brand .mark .wordmark .top-phone` (header);
`.lp-hero` (+ `::before` radial-gradient wash) `.kicker` (uppercase, leading rule) `.sub`
`.hero-cta` `.btn-primary` `.btn-tour` `.cta-note` `.chips` `.hero-fig`; `section` `.band`
`.section-lead`; `.cards .card` (generic 3-up); `.cta-final .btn-paper .cta-tel`; `footer h4
.foot-meta`. Header/footer/final-CTA markup is byte-identical across all LPs.

**Tier B - section modules, include only when that section is used:**
- `.bldgs .bldg` - 4-up building grid (state-employees only).
- `.rates-card table` + `.vip` cell - the published weekly-tuition table (state-employees).
- `.rto-points` - bulleted "return to office" list.
- `.rating-line .stars .quote` - the reviews band (shared copy, sec 8).
- `.steps .step .num` - the 3-step "how it works" row (mockup; use for offer pages).
- `.cal-*` family - calendar card (see sec 6; real interactive version in `/tour/`).
- `.trust-row .trust-item` - 4-up trust band (mockup).
- `.faq .faq-item summary .faq-toggle .faq-a` - `<details>` accordion (mockup; offer pages).
- `.condition-line` - the boxed conditional-offer disclosure (mockup; REQUIRED on any
  variant making a "$X waived / this week only" claim - carries the truthful conditions).

Button archetypes (FIXED styling):
- `.btn-primary` - dark pill (`--ink` bg, paper text), 52px min-height, hover -> `--teal-deep`.
  Hero primary. Full-width under 640px.
- `.btn-tour` - outlined pill. Secondary "Book a free tour" -> `/tour/`.
- `.btn-paper` - paper pill on the dark `.cta-final`. Final CTA action.

---

## 5. Body skeleton (fixed frame + ordered variant sections)

```
<header class="lp-top">        FIXED  (logo lockup + tel)
<section class="lp-hero">      SLOTS  (kicker, h1, sub, CTA pair, chips, hero figure)
  ... 1-3 variant sections ... VARIANT (band-striped: alternate default / .band bg)
<section reviews>              SHARED copy (sec 8) - keep on every LP for trust
<section class="cta-final">    SLOTS  (headline, lead, CTA, tel line)
<footer>                       FIXED  (3 columns + foot-meta)
<script src=".../overlay.js?v=36"></script>   FIXED (overlay-flow LPs)
```

Header (FIXED, verbatim - note real LPs use `<img>` logos, NOT the mockup's CSS-circle mark):
```html
<header class="lp-top">
  <a href="/" class="brand" aria-label="Growing Mindfully">
    <img src="/assets/mark.webp" class="mark" alt="Growing Mindfully lotus mark" width="260" height="260" decoding="async">
    <img src="/assets/wordmark.webp" class="wordmark" alt="Growing Mindfully" width="1413" height="354" fetchpriority="high" decoding="async">
  </a>
  <a href="tel:+19166262739" class="top-phone">(916) 626-2739</a>
</header>
```
Logo uniformity rule (Jarred 2026-07-09): `.brand .wordmark { height: 40px }` desktop, `38px`
+ `max-width: 46vw` under 720px. Carry this CSS into every stamp.

Footer (FIXED) = 3 columns (Growing Mindfully address / Contact / More) + `.foot-meta`
copyright line. The "More" column links can vary per LP; keep `/rates/ /privacy/ /terms/`.
`.foot-meta` verbatim: `© 2026 Growing Mindfully · Family-founded in Sacramento, 2018 ·
Licensed by California CDSS · Nut-free facility`. **Do NOT touch the CDSS badge - it is a
pre-existing licensing string that stays as-is; NEVER add any new licensing text (hard rule).**

Section band-striping: hero (plain) -> section 1 `.band` -> section 2 plain -> etc. Alternate
`class="band"` (paper-deep bg) for rhythm, exactly as the live LPs do.

---

## 6. Two CTA architectures (pick per variant)

### 6a. Overlay-flow LP (waitlist-fee variants V1, V2, V5, and any "check availability" page)
Loads the onsite waitlist overlay and hands off to it. This is what all 3 live LPs do.

- Hero primary CTA: `<a href="#cta-section" data-gm-waitlist="open" class="btn-primary">Check
  availability</a>` (in-page anchor to `#cta-section`; the `data-gm-waitlist="open"` attribute
  is what overlay.js hooks to mount the flow).
- Optional secondary: `<a href="/tour/" class="btn-tour">Book a free tour</a>`.
- Final CTA: `<a href="/waitlist/" data-gm-waitlist="open" class="btn-paper">Check availability</a>`
  inside `<section class="cta-final" id="cta-section">`.
- FIXED embed pair, both in the head and before `</body>`:
  ```html
  <!-- head -->
  <link rel="stylesheet" href="https://waitlist.growingmindfully.org/overlay/overlay.css?v=33" media="print" onload="this.media='all'">
  <noscript><link rel="stylesheet" href="https://waitlist.growingmindfully.org/overlay/overlay.css?v=33"></noscript>
  <!-- before </body> -->
  <script src="https://waitlist.growingmindfully.org/overlay/overlay.js?v=36"></script>
  ```
  The overlay is served remotely from the gm-waitlist worker; the LP never bundles it. `?v=`
  is a cache-bust - match whatever the live LPs currently ship (css v33 / js v36 as of 7/11).

### 6b. Tour-calendar LP (tour-offer variants V3, V4 - "free tour / fees waived when you tour")
Embeds the SAME calendar-first widget as `/tour/`, reading the live slots feed. Do NOT
re-implement: lift the `<section class="cal-section">` markup + the entire booking IIFE
(`tour/index.html` ln 342-651) and the `.cal-*` / `.book-*` / `.time-*` CSS.

Wiring facts (from `tour/index.html`):
- Mount point: `<div class="cal-card" id="tourCal"><div class="slots-loading">Loading the
  calendar...</div></div>`. The IIFE finds `#tourCal` and takes over.
- Slots read: `GET {API}/api/tours/slots?days=45&limit=120`. `API` =
  `https://waitlist.growingmindfully.org` (prod) or the sandbox worker when `?api=sandbox`.
- Booking write: `POST {API}/api/tours/book` with `{slotStart, name, email, phone, childDob,
  company (honeypot), t (inviteToken), gaCid, gaSessionId}`. Rate-limited 4/hr server-side.
- Times are PT; slot ISO first 10 chars = the PT date. All scheduling America/Los_Angeles.
- Fallback: on any load failure or `data.stale`, swaps to the Google-scheduler `<iframe>`
  embed (`GOOGLE_EMBED` const) and fires `tour_picker_fallback`.
- Hero CTA for this type is an in-page anchor to the calendar (`href="#tour-calendar"`), not
  the overlay.

### 6c. Offer-context handoff (tour-waiver / fee-waiver variants) - `?offer=` contract
Per C-landing-page.md secs 5-6. When the Ads Final URL is `/lp/<slug>/?offer=<name>`:
1. Inline script reads `location.search`; if `offer` matches, writes
   `sessionStorage.setItem('gmwl_offer_ctx', JSON.stringify({offer, lp, ts, ...}))`. Key name
   `gmwl_offer_ctx` deliberately sits in the same family as overlay.js's `GMWL_ATTR_KEY`.
2. On tour-booking success, fire the EXISTING `tour_booked` AND a new `tour_booked_from_offer`
   (params: offer, lp, slot), and merge `tour_booking_id` + time into `gmwl_offer_ctx`.
3. The waitlist CTA carries `data-gm-waitlist="open"` PLUS `data-gm-waitlist-offer="<name>"`;
   overlay.js's mount path also independently reads `sessionStorage gmwl_offer_ctx` so the
   waiver flag survives even if the attribute is missed. Waiver flag rides ONLY via `?offer=`.
4. New page-view event `lp_tour_offer_view` on load. (Server-side twins may be renamed to the
   `gmwl_` prefix before GA4/Ads registration - confirm names with gm-ads before wiring.)

---

## 7. Instrumentation summary (events the template already emits)

- `assets/track.js` (FIXED include, auto-delegated, capture-phase) fires:
  - `waitlist_start` on any `[data-gm-waitlist]` click - PRIMARY enrollment-intent signal,
    fires even when overlay.js also handles the click.
  - `contact_phone` on `tel:` click, `contact_email` on `mailto:` click.
- Tour calendar fires `tour_booked` (client) which stitches to server-side `gmwl_tour_booked`
  (the winback key event) via `gaCid`/`gaSessionId` carried in the POST; plus
  `tour_picker_fallback` when the Google embed is shown.
- New lifecycle events to add per sec 6c: `lp_tour_offer_view`, `tour_booked_from_offer`.
- GA4 property `G-QK5VPGREL8`; Ads account `945-427-9476`. Ad signals + ad-personalization ON
  for enhanced conversions. Wire any NEW GA4 event as a key event before importing to Ads.

---

## 8. Shared trust copy (drop-in, keeps every LP credible)

Reviews band (verbatim from live LPs - safe to reuse across all variants):
- Rating line: `★★★★★ Rated 5.0 from 27 Google reviews`.
- Three real Google-review quotes (yoga moves / homey landing place / scholar award) - see
  `lp/state-employees/index.html` ln 300-312. All attributed "Parent · Google review".
- Hero chips pool (pick 4): `Licensed by California CDSS` (existing badge, fine to keep),
  `Family-founded 2018`, `6 weeks to kindergarten`, `Mon-Fri · 7:00 AM-6:00 PM`, `5 minutes
  from the Capitol`, `State employee rate available`, `Top rated on Google`.

---

## 9. The factory stamp - per-variant slot manifest

Everything a build agent fills per campaign variant. Everything NOT listed is FIXED template.

| Slot | Where | Example (V5 "$65 waitlist fee waived") |
|---|---|---|
| slug | dir + canonical + og:url | `waitlist-fee-waived` |
| `<title>` | head | `$65 Waitlist Fee Waived This Week · Growing Mindfully` |
| meta description | head | ~155 char, truthful, conditions implied |
| og:title / og:description | head | mirror title/desc |
| hero `.kicker` | hero | `Open enrollment` / `Back to school` / `This week only` |
| `<h1>` (+ teal `<em>` tail) | hero | `Skip the fee, <em>hold your spot free.</em>` |
| `.sub` | hero | 1-2 sentences, location + offer |
| `.condition-line` | hero (REQUIRED on any $ / urgency claim) | truthful conditions + expiry |
| CTA labels | hero + final | `Waive my fee` / `Check availability` |
| CTA architecture | sec 6a vs 6b | overlay (fee variants) vs calendar (tour variants) |
| `?offer=` name + events | sec 6c | `waitlist-fee-waived`, `lp_..._view` |
| hero figure | `/assets/*.webp` | pick brand photo (Capitol lawn / classroom) |
| chips (4) | hero | from sec 8 pool |
| 1-3 body sections | between hero + reviews | steps / rates / trust / FAQ modules |
| final-CTA headline + lead + tel line | `.cta-final` | offer-specific |
| footer "More" links | footer | keep rates/privacy/terms |

**Dollar figures ARE now allowed** in these variant copies (Jarred 2026-07-11 supersedes the
7/2 "no $65 in copy" ruling FOR THESE TESTS). "$100+" = $65 waitlist + $45 enrollment stacked;
must be truthful and conditions clear. "This week only" urgency MUST actually rotate/expire
(policy risk if evergreen) - pair every such claim with a real expiry in `.condition-line`.

---

## 10. Dark-page config (make a variant ad-only + invisible to organic)

Every LP is a "dark" page: reachable only by ad click, never indexed, never internally linked.
The stack that enforces this (all already in place - a new `lp/<slug>/` inherits it):

1. **In-page:** `<meta name="robots" content="noindex, follow">` + self-canonical to
   `/lp/<slug>/`. (Verbatim in the head template, sec 2.)
2. **Zero internal links:** never link the LP from nav, footer, homepage, or sitemap. The
   `lp/` dirs are absent from `sitemap.xml` and `robots.txt` by omission - keep it that way.
   ISOLATION MANDATE (2026-07-11): test LPs get noindex + zero internal links + ad-click-only
   entry; waiver flag only via `?offer=`.
3. **`_headers`:** no per-LP entry needed. `/*.html` gets `max-age=300, must-revalidate`
   (fast content rollout) and `/*` gets HSTS + X-Frame-Options SAMEORIGIN + Permissions-Policy.
   Inherited automatically.
4. **`_redirects`:** add ONLY if a vanity/typo path is wanted (e.g. the `/tours -> /tour/`
   guard). LPs generally need no redirect. Note: Cloudflare Pages serves a real static file
   OVER a forced redirect, so `_redirects` cannot hide an existing file - use middleware.
5. **`functions/_middleware.js`:** the fail-open denylist that 404s dev paths and 301s every
   `*.pages.dev` preview host to canonical www. A public `lp/<slug>/index.html` is NOT
   blocked (only `waitlist/`, `enrollment-availability/`, `memory-bank/`, `scripts/`, `docs/`,
   root `*.md`, dotfiles are). If a variant needs to stay dark on preview too, extend the
   narrow preview-exception pattern (see the `isTourPreview` block) rather than the denylist.
6. **Sitemap:** do nothing. LPs and `/tour/` are intentionally absent - confirmed no `lp/` or
   `/tour` entries in `sitemap.xml`.

---

## 11. Hard-rule checklist baked into every stamp (verify before Tier-2 gate)

- NO em dashes anywhere (copy or code). Hyphens / colons / periods only.
- NEVER add licensing text (Lic #, H&S code, CDSS citations) to copy or ads. The existing
  `.foot-meta` "Licensed by California CDSS" badge stays; add NOTHING new.
- Parent-facing copy + prod deploy = Tier 2 Jarred gate (surface, do not self-ship).
- $ and urgency claims: truthful, conditions in `.condition-line`, urgency must really expire.
- noindex + self-canonical + zero internal links on every LP.
- Reuse `/tour/` calendar + overlay.js by reference; never fork the widget code.
- Any new GA4 event -> mark key event before Ads import; confirm `gmwl_`-prefix naming w/ gm-ads.
```
