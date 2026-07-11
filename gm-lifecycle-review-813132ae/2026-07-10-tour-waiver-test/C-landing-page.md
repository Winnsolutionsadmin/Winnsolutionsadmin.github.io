# C - Landing Page: /lp/tour-offer/ (tour-waiver test)

Lane: landing page (site: `~/Projects/growingmindfully`, Cloudflare Pages, static, no build step).
Status: SPEC + DRAFT COPY + FRONT-END CONTRACT. Nothing here is deployed. Mockup at
`lp-tour-offer-mockup.html` in this same folder.

Grounding read before drafting (per task instructions): `lp/state-employees/index.html`,
`tour/index.html`, `index.html` (FAQ pattern), `waitlist/docs/ARCHITECTURE.md`,
`gm-waitlist/src/web/overlay/overlay.js`. All patterns below are copied from those live files,
not invented.

## 1. URL, indexing, launch posture

- URL: `/lp/tour-offer/` (file: `lp/tour-offer/index.html`), consistent with the existing
  `/lp/state-employees/` paid-LP convention.
- `<meta name="robots" content="noindex, follow">` + self-referencing
  `<link rel="canonical" href="https://www.growingmindfully.org/lp/tour-offer/">`. Verbatim
  pattern from `/lp/state-employees/index.html` and `/tour/index.html`; both are already dark
  this way and neither appears in `sitemap.xml` (confirmed via grep, 0 matches each).
- Do NOT add the URL to `sitemap.xml` (manually maintained file; exclusion is by omission,
  matching `/tour/` and `/lp/state-employees/`).
- Zero internal links to it from any other page, nav, or footer. Reachable only via the Ads
  final URL. This mirrors exactly how `/tour/` was launched dark before its 2026-07-09 go-live
  (see `memory-bank/activeContext.md`), except this page is NOT going fully public at this
  stage - it stays a dedicated ad-only LP indefinitely, same posture as `/lp/state-employees/`.
- GATE (Tier 2, production deploy): shipping this file to `main` and pushing is a
  `/safe-site-push`-only action. Nothing in this deliverable executes that; it is a
  build-ready draft for Jarred + the gm-website agent to deploy when the test goes live.
- GATE (Tier 2, parent-facing copy): every word of section 4 below is parent-facing copy and
  needs a Jarred read before it ships, per this repo's standing rule.

## 2. Page architecture

1. Header: same brand mark + wordmark + phone number pattern as every other page.
2. Hero: the offer stated with its condition immediately visible (not buried in fine print).
   Single CTA (anchor-scroll to the calendar section). No secondary CTA, no nav distractions,
   matching single-purpose paid-LP best practice already used on `/lp/state-employees/` and
   `/tour/` (both are effectively single-CTA pages).
3. How it works: 3 numbered steps, book, apply (fee waived pending), tour (waiver locks in).
4. Tour calendar: same calendar-first widget as `/tour/`, reading the same
   `GET /api/tours/slots` feed. This is a reuse of live code, not new build. See section 5 for
   the one addition needed (offer-context capture on booking success).
5. Trust band: 4 chips, no numeric Google rating, no licensing anything, ratios described as a
   benefit rather than a raw ratio table.
6. FAQ: `<details>`/`<summary>` pattern from `index.html`, same CSS classes
   (`.faq-item`, `.faq-q`, `.faq-toggle`, `.faq-a`). Six questions, see section 4.5.
7. Final CTA band (dark `--ink` background, same as other LPs' closing section) + phone
   fallback.
8. Footer: address, hours, contact, links to `/rates/`, `/privacy/`, `/terms/`. Existing
   "Licensed by California CDSS" badge line stays (it is already on every page); nothing new
   licensing-related is added, per the hard site rule.

## 3. Copy-consistency check (explicit, required by CONTEXT-PACK.md)

`/state-employees/` currently says "No application fee" twice with no condition attached - a
contradiction Jarred has flagged as pending fix. This LP must never repeat that class of bug.

**Rule for this page: the words "fee waived" or "no application fee" may never appear without
the tour condition attached in the SAME sentence or the immediately adjacent sentence.** Every
instance of the waiver claim on this page (hero, step 2, step 3, trust band, FAQ, final CTA) has
been written to carry "when you book and complete your tour" / "pending your tour" /
"once your tour is complete" alongside the waiver claim. Before this page ships, whoever reviews
it should specifically grep the draft HTML for "fee" and confirm every hit is conditioned. This
check should be added to `memory-bank/lessons.md` as a standing rule for any future LP that
mentions the $65 fee.

## 4. Full draft copy

### 4.1 Hero
- Kicker: `Tour offer`
- H1: `Book a tour, and your application fee is waived.`
- Sub: `Growing Mindfully sits on the top floor of 750 N Street, a five minute walk from the
  Capitol. Come see the infant, toddler, and preschool rooms in person, then join our waitlist
  with the application fee waived.`
- Condition block (fine print, distinct visual treatment from the hero headline):
  `The waiver is conditional: book your tour and complete it, and the fee that normally holds
  your family's place is waived. If your tour is cancelled or skipped, the standard fee applies.`
  - JARRED DECISION FLAGGED: the task brief for this lane permits the literal `$65` figure to
    appear in this fine-print condition block (distinct from the CONTEXT-PACK's binding rule
    that `$65` never appears in AD COPY). The draft above deliberately omits the number and
    says "the fee" instead, to stay furthest from any FTC-clarity ambiguity and to avoid a
    second place on the site where the number has to be kept in sync if pricing changes. Two
    variants for Jarred to choose between:
    - Variant A (drafted above, no number): "...the fee that normally holds your family's place
      is waived."
    - Variant B (with number, if Jarred wants maximum FTC-clarity explicitness): "...the $65
      application fee that normally holds your family's place is waived."
  - Recommend Variant A unless counsel specifically wants the number stated for clarity of the
    "material condition" disclosure. Both are precise about the condition either way.
- CTA: `See tour times` (anchor to `#tour-calendar`).
- CTA note: `30 minute visit on the top floor of 750 N Street. Infant through preschool.`
- Chips: `Top rated on Google` / `Family-founded, 2018` / `5 minute walk from the Capitol` /
  `State employee rate available`.

### 4.2 How it works (3 steps)
1. **Book your tour below.** `Pick an open day and time on the calendar. Takes about a minute,
   no application yet.`
2. **Complete your waitlist application.** `Right after you book, finish your application.
   Because you came through this offer, the fee is waived, pending your tour.`
3. **Complete your tour, the waiver locks in.** `Show up for your visit and your application
   activates in our queue with the fee waived. Miss it, and the standard fee applies.`

### 4.3 Calendar section intro
- Kicker: `Pick a day`
- H2: `Come see the space, then join the list.`
- Lead: `Real build: same calendar-first widget as /tour/, reading the live gm-waitlist
  /api/tours/slots feed.` (This line is a dev note in the mockup only; the shipped page's lead
  copy should instead read something parent-facing, e.g. `Every visit is 30 minutes, one on
  one with a member of our team. No obligation, just a look at the rooms and the routine.`)

### 4.4 Trust band
- `Top rated on Google, from real Growing Mindfully families` (no star count, no numeric score)
- `Family-founded in Sacramento, 2018` (matches homepage phrasing exactly)
- `5 minute walk from the Capitol`
- `Ratios built for real attention, tighter than the state requires` (benefit-framed per task
  instruction; deliberately omits the specific 1:3/1:4/1:9-style numbers so this section reads
  as a benefit statement, not a stat block. If Jarred wants the exact ratio numbers included,
  that is a one-line addition, flagged here as optional.)

### 4.5 FAQ
1. **What exactly is waived?**
   `The one-time application fee that normally holds your family's place on our waitlist. It is
   waived when you book your tour through this page and complete that tour. The fee is not
   charged upfront while your tour is pending.`
2. **What happens if I have to cancel or miss my tour?**
   `Your application does not activate, and the standard application fee applies. Reschedule
   instead of cancelling; the waiver stays available for any tour time you complete.`
3. **Can I join the waitlist without touring, to keep the waiver?**
   `You're welcome to apply without a tour at any time, on our standard application, but the fee
   waiver on this page applies only when a tour is booked and completed.`
4. **I already booked a tour a different way. Do I still qualify?**
   `Call us at (916) 626-2739 and we'll confirm the waiver applies to your existing tour.`
   (FLAGGED: this is a real edge case, e.g. a parent who booked via the plain `/tour/` page
   separately from this offer. The front-end contract in section 5 does not currently resolve
   this automatically; it is a phone-fallback answer on purpose so the page never promises a
   waiver the backend cannot yet honor. If the waitlist-flow lane wants to make this
   self-service, that is their call, flagged to them below.)
5. **Does the tour itself cost anything?**
   `No. Tours are always free at Growing Mindfully, with or without this offer. This page
   waives the separate waitlist application fee, not the tour.`
6. **What ages can tour?**
   `Every age we serve, six weeks through preschool. You'll see the room that fits your child's
   age on your visit.`

### 4.6 Final CTA
- Kicker: `Next step`
- H2: `Book your tour, waive the fee.`
- Lead: `Pick a day that works. Your waitlist application waives its usual fee once your tour
  is complete.`
- CTA: `See tour times` (same anchor).
- Phone fallback: `Prefer to talk first? (916) 626-2739`

All copy above: no em dashes, no numeric Google rating, no licensing additions, no unconditioned
"fee waived" claim, no dollar amount in ad-facing sections (dollar amount discussion confined to
the flagged hero fine-print decision in 4.1).

## 5. Waiver mechanics: front-end contract (for the waitlist-flow lane)

Scope note: this lane does not design or change backend eligibility logic (when a tour counts as
"completed", how a no-show reverts the waiver, where in `waitlist_pipeline` the offer context
lands). This section specifies only what the LANDING PAGE emits and where, so the waitlist-flow
lane can decide how to consume it.

**Ad-to-page signal.** The Ads final URL for this test should include a static `?offer=tour-waiver`
query param alongside the usual ValueTrack params (flagged to the gm-ads/campaign-architecture
lane, since the final URL itself is their asset to define, not mine).

**Page-load capture.** On `/lp/tour-offer/` load, an inline script reads `offer` from
`location.search`. If `offer === 'tour-waiver'`, it writes to `sessionStorage`:

```js
sessionStorage.setItem('gmwl_offer_ctx', JSON.stringify({
  offer: 'tour-waiver',
  source_lp: '/lp/tour-offer/',
  captured_at: new Date().toISOString()
}));
```

Key name `gmwl_offer_ctx` is chosen to sit alongside the overlay's existing `GMWL_ATTR_KEY`
sessionStorage entry (`overlay.js` ~line 617-696), same naming family, same storage mechanism,
no new infrastructure.

**Booking-success capture.** This LP embeds the same tour-calendar widget as `/tour/`
(`POST /api/tours/book` with `{slotStart, name, email, phone, childDob, company, t, gaCid,
gaSessionId}`). On a successful booking response, the LP's script should:
1. Fire the existing `tour_booked` GA4 event exactly as `/tour/` does today (no change to that
   event, so existing tour-funnel reporting stays intact).
2. ALSO fire a new `tour_booked_from_offer` event (see section 6).
3. Update the `gmwl_offer_ctx` sessionStorage object to add the booking's id and time, e.g.
   `tour_booking_id: <id from the /api/tours/book response>` and `tour_start_iso: <slotStart>`.
   Exact field name for the booking id in the API response needs confirming against the
   waitlist-flow lane's actual response shape; treat `tour_booking_id` here as a placeholder
   key name on the LP side, not a claim about the API's field name.

**Application-open signal (two layers, redundant on purpose).**
- Layer 1 (click-time, simple): the "Complete your waitlist application" trigger on this page
  carries both `data-gm-waitlist="open"` (existing) and a new `data-gm-waitlist-offer="tour-waiver"`
  attribute. ASK to waitlist-flow lane: the overlay's click delegate in
  `src/web/overlay/overlay.js` (`document.addEventListener('click', ...)` block, ~line 5283-5302,
  which currently calls `openWithHrefFallback(trigger, entry)` -> `open(entry)` and does NOT
  forward any data-attribute-derived options) would need a small extension to read
  `trigger.dataset.gmWaitlistOffer` and forward it as `opts.offer` into `open(entryMode, opts)`.
  This is the single smallest change needed on the overlay side for this test.
- Layer 2 (durable, recommended): rather than relying only on that click-time pass, which breaks
  if the parent leaves and returns later (e.g., clicks an emailed tour confirmation days after
  booking, or opens the overlay from a different page on tour day), the overlay's own
  `open()`/mount path should also independently check `sessionStorage.getItem('gmwl_offer_ctx')`
  (mirroring how it already self-reads `GMWL_ATTR_KEY`) and, if present and within a reasonable
  window (suggest 30 days, matching typical waitlist decision timelines), attach `offer_code`
  and `tour_booking_id` to the application payload the overlay submits. This makes the signal
  survive across sessions and pages, which matters here because tour and application often
  happen on different days. This is a request to the waitlist-flow lane, not something this
  lane is implementing.

**Payload field names proposed** (additive, consistent with the existing attribution approach
described in `waitlist/docs/ARCHITECTURE.md`): `offer_code: "tour-waiver"`, `tour_booking_id`,
`tour_scheduled_at`. Whether these land in `waitlist_pipeline.attribution_json` (additive JSON
column, no schema change) or a new dedicated column is the waitlist-flow lane's call, not
decided here. `solace-mirror.db` schema stays additive-only either way per the standing rule.

**Explicitly out of scope for this lane:** eligibility logic (does the tour count as
"completed"? who marks it? what happens on no-show, does the fee get charged automatically or
does it queue an admin task?), any Stripe/fee-charge timing change, and any `waitlist_pipeline`
/ `waitlist_holds` schema work. Flagged to the waitlist-flow and gm-kindred lanes.

## 6. GA4 event wiring

New events proposed:
- `lp_tour_offer_view`: fires once on page load of `/lp/tour-offer/`. Params:
  `{ lp: 'tour-offer', offer: 'tour-waiver' }`. Distinct from the standard GA4 `page_view` so
  Ads can build a "saw the offer" audience/segment independent of generic traffic, and so this
  specific LP's view-to-booking rate can be isolated from `/tour/`'s baseline funnel.
- `tour_booked_from_offer`: fires in addition to (never instead of) the existing `tour_booked`
  event, immediately after a successful `/api/tours/book` response on this LP. Params:
  `{ slot: <slotStart>, offer: 'tour-waiver', lp: 'tour-offer' }`.

NAMING FLAG for the gm-ads / waitlist-flow lanes: production GA4 events on this system already
use a consistent `gmwl_` prefix (`gmwl_overlay_open`, `gmwl_email_submitted`,
`gmwl_application_submitted`, `gmwl_fee_paid` / `gmwl_fee_paid_confirmed`,
`gmwl_fee_exit_winback_shown`, `gmwl_waitlist_terms_signed`, `gmwl_tour_booked`, per
CONTEXT-PACK.md and the live overlay code). My task instructions gave me the event names
`lp_tour_offer_view` and `tour_booked_from_offer` verbatim, but for consistency with the
existing convention I'd recommend renaming to `gmwl_lp_tour_offer_view` and
`gmwl_tour_booked_from_offer` before these are wired into GA4 or registered as Ads conversions.
Decision left to Jarred / gm-ads, since gm-ads owns the GA4 event registry and conversion setup.

Also flagged to gm-ads/waitlist-flow: should `tour_booked_from_offer` (or its renamed form)
become its own GA4 key event / Google Ads conversion action, separate from the existing
`gmwl_fee_paid_confirmed` Purchase conversion? That is a conversions/attribution decision, not
a landing-page decision, surfaced here so it isn't lost.

## 7. Page-level technical notes

- GA4 snippet: identical direct `gtag` install as every other page
  (`G-QK5VPGREL8`, `allow_google_signals`/`allow_ad_personalization_signals` enabled), copied
  verbatim from `/tour/index.html`, not GTM.
- Overlay assets: same two tags as every other LP:
  `<link rel="stylesheet" href="https://waitlist.growingmindfully.org/overlay/overlay.css?v=33"
  media="print" onload="this.media='all'">` and
  `<script src="https://waitlist.growingmindfully.org/overlay/overlay.js?v=36"></script>`.
  If the waitlist-flow lane ships the click-handler extension from section 5, that is a version
  bump (v37) on the overlay script tag across every page that includes it, which is a
  waitlist-flow deploy concern, not this lane's.
- Calendar widget: same `/api/tours/slots` fetch + booking POST + Google Calendar iframe
  fallback pattern as `/tour/index.html`, reused verbatim with the additions in section 5.
- JSON-LD `ChildCare` schema block: same as `/tour/index.html` (address, geo,
  openingHoursSpecification, sameAs). No changes needed for this offer.

## 8. Gates summary

- Tier 2, parent-facing copy: all of section 4 needs a Jarred read before ship.
- Tier 2, production deploy: shipping `/lp/tour-offer/` to `main` is `/safe-site-push` only.
- Jarred decision flagged: hero fine-print `$65` numeral, Variant A vs B (section 4.1).
- Jarred/gm-ads decision flagged: event name convention, `lp_tour_offer_view` /
  `tour_booked_from_offer` vs `gmwl_`-prefixed equivalents (section 6).
- Jarred/waitlist-flow decision flagged: whether to solve the "already booked a tour a
  different way" edge case with anything beyond a phone-call fallback (section 4.5, item 4).
- Not this lane's decision, flagged to waitlist-flow + gm-kindred: eligibility/no-show logic,
  where offer context lands in the DB, overlay click-handler + sessionStorage-read extension
  (section 5).
