# DESIGN: T3 tour-nudge email + T2 reserve-exit winback popup (2026-07-11)

Lane deliverable for the lifecycle funnel. Two parent-facing assets, both drafted ready-to-build,
both **Tier-2 (parent-facing copy + waitlist mutation) so they surface to Jarred before send**:

1. **T3 email** - "Book a tour and waive your enrollment fee!" Fires +24h after the family engaged
   with T1 but still has no tour booked. Marketing kind, suppression-gated, CAN-SPAM compliant.
2. **T2 winback popup** - exit-intent overlay on the reserve page, reusing the existing fee-exit
   winback module mechanics, routing to `/tour/` and tracking the booking.

No em dashes. No licensing language. Team voice ("we"), signed "With love, The Growing Mindfully
team", never Jarred. Every "waive"/"fee" claim carries its condition in the same sentence.

Grounded in: `ground/email-infra.md` (emailShell + picture pattern + suppression), `ground/tours-fees-code.md`
(fee-exit popup mechanics §3, /api/tours/book, /t/:token), `ground/enrollfee-noshow.md` (the $45 fee
is 7 call sites, waiver NOT automated yet - see BLOCKER below), `ground/waiver-package.md` (offer-code
+ gmwl_offer_ctx contract, condition-in-same-asset rule).

---

## 0. BLOCKER that governs both assets (read first)

Both T3 and T2 dangle **the $45 enrollment-fee waiver as the tour incentive**. Per
`ground/enrollfee-noshow.md` Part A, the $45 fee is bundled into the deposit PaymentIntent across
**7 call sites** (index.ts:1928/2192/2992/3005/4924/4995/6510 + a hardcoded `45` in docusign.ts:117),
plus the signed clickwrap terms and the DocuSign agreement all state it. **There is no waiver plumbing
today.** The email may PROMISE the waiver, but the charge will not reflect it until the single
choke-point helper `enrollmentFeeDue(row, waiverFlag)` ships through all 7 sites AND a counsel-reviewed
clickwrap/agreement version bump lands.

**Hard sequencing rule for this copy:** do NOT enable T3/T2 sends until (a) `enrollmentFeeDue` is live,
(b) the waiver flag is a real side-table state (attaches via `?offer=`), and (c) the clickwrap +
agreement text is version-bumped to reflect a conditional-waivable $45. This mirrors the A-lane
"do not advertise Test B before it is automated / verified-SOP" gate. Copy below is authored and staged;
it is not cleared to fire. Flagged to the waitlist-flow + policy lanes.

**Naming:** the $45 waiver offer code used by these lifecycle assets is **`offer=enroll-waiver`**
(distinct from the V1 `offer=tour-waiver` $65 waitlist-fee code). One family, one active waiver code.

---

## 1. T3 EMAIL - "Book a tour and waive your enrollment fee!"

### 1a. Trigger + audience (for the code lane; copy is what this doc owns)
- Fires **+24h after T1 engagement** (T1 clicked, per campaign_sends.clicked_at) when the family is
  still: `fee_paid=1`, `deposit_paid=0`, no `tour_bookings` row (no active booking), no
  `tour_requested_at`, not suppressed, `marketing_consent=1`. In America/Los_Angeles.
- Piggybacks the existing `*/10` cron leg (no new trigger; 5-cron limit) with a `lifecycle_sends`
  idempotency row `(application_id, stage='t3')` copying the `reservation_reminders` PK idiom.
- New `CAMPAIGNS` registry entry (extends the engine, does NOT rebuild the mailer). Marketing kind ->
  auto suppression-gated + unsubscribe footer + RFC 8058 headers appended by `sendEmail`. Physical
  address already in the shell footer (`750 N Street, Sacramento CA 95814`). CAN-SPAM satisfied.

### 1b. Subject lines (x3 - rotate / A-B; all condition-bearing, no isolated "fee waived")
Use `childName()` personalization the same way the existing templates do (`{child}` = the child's
first name, or "your child" fallback).

1. `Come see us, and we'll waive {child}'s $45 enrollment fee`
2. `Book a tour this week: your $45 enrollment fee is on us`
3. `{child}'s spot is saved. Tour with us and skip the $45 enrollment fee`

Notes: each names the $45 AND the condition (tour / come see us) in the same line. No "free tour"
phrasing (banned - tours never carried a price). Keep under ~55 chars where possible; subject 1 and 3
personalize, subject 2 is the neutral fallback when `child_first` is empty.

### 1c. Preheader (hidden pre-header text, one line)
`A quick visit is all it takes, and your $45 enrollment fee comes off at reservation.`

(Rendered as a hidden span at the very top of `bodyInner`, standard pattern:
`<span style="display:none;max-height:0;overflow:hidden;opacity:0">...preheader...</span>`.)

### 1d. Picture (DIFFERENT from T1)
T1 uses the standard `community.jpg` hero. T3 uses **`play.jpg`** (children engaged in the classroom -
message-matched to "come see the space"). Confirmed live at
`https://www.growingmindfully.org/assets/play.jpg`.
> Coordination note for the T4 lane: T4 must use a THIRD distinct asset (suggest `joy.jpg` or
> `seated.jpg`) so T1/T3/T4 each carry a different picture. Available: breathe / joy / play / seated /
> walk / hero .jpg.

### 1e. CTA + tracking + offer-param contract (this is the load-bearing plumbing spec)
- **Button label:** `Book your tour`
- **Destination the family must reach:** `https://www.growingmindfully.org/tour/?offer=enroll-waiver`
  so the `/tour/` page's inline script reads `offer` from `location.search`, writes
  `sessionStorage.gmwl_offer_ctx = {offer:'enroll-waiver', source_lp:'email_t3', captured_at}`, and on a
  successful `/api/tours/book` attaches `offer_code:'enroll-waiver'` + `tour_booking_id` to the booking
  (waiver-package §1c contract). That is how the enrollment-fee waiver attaches to their booking.
- **Click tracking:** the authored `href` must be a tracked redirect so the campaign grid stamps
  `clicked_at`. Recommended (cleanest, reuses tour-link identity):
  - Mint a `tour_invites` token for this family and store the offer on it; extend `tourRedirectDest()`
    so `/t/:token` appends the server-controlled enum `?offer=enroll-waiver` to the fixed `/tour/`
    destination (NOT user input - safe). Authored href = `<base>/t/<token>`. Stamps
    `tour_invites.clicked_at` (existing) AND lands on `/tour/?offer=enroll-waiver`.
  - Fallback if `/t/` is not extended: wrap `https://www.growingmindfully.org/tour/?offer=enroll-waiver`
    through the campaign `/c/:token` click tracker (stamps `campaign_sends.clicked_at`), and make the
    `/c/` redirect preserve the query string for tour destinations.
- **On booking, events fan out (directive item 1 "update ALL databases"):** existing server-side MP
  `gmwl_tour_booked` + `funnel_events` + `/tour/` client `gmwl_tour_booked`, PLUS a new
  `gmwl_tour_booked_from_offer` (params `{offer_code:'enroll-waiver', source:'email_t3'}`) so the
  offer-attributed bookings are isolated from organic ones. Event names are the code lane's to wire;
  listed here so the CTA copy and the instrumentation agree.

### 1f. Body copy (the `bodyInner`, faithful to emailShell voice; `{parent}` / `{child}` / `{childPoss}` from the row)
Shell heading (the `<h2>` passed to `emailShell`): **`A short visit, and the enrollment fee is on us`**

`bodyInner` (paragraphs; `heroImg` = play.jpg at 524px border-radius:6px; keep the "Family founded
since 2018" trust line the campaign templates use):

```
[hidden preheader span]
<p style="text-align:center;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#6F7F84;margin:0 0 14px">Family founded since 2018</p>
<img src="https://www.growingmindfully.org/assets/play.jpg" alt="Children at play in a Growing Mindfully classroom" width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">
<p>Hi {parent}!</p>
<p>{child}'s place on our waitlist is saved, and we would love for you to come see where the days actually happen: the sunny classrooms, the garden light, the calm little rhythm of a Growing Mindfully morning.</p>
<p>Here is a warm nudge to make it easy. Book a tour with us, and we will waive {childPoss} $45 enrollment fee when you reserve a space after your visit. A short weekday visit is all it takes, and there is nothing to pay to come see us.</p>
<p>Tours run about 30 minutes, Monday through Friday. Pick a time that fits your week using the button below, and we will hold it for you.</p>
<p>Questions about rates, start dates, or your child's age group? Just reply to this email and we will help personally :)</p>
<p>With love,<br>The Growing Mindfully team</p>
```

`afterCta` (below the button, muted): `<p style="text-align:center;font-size:12px;color:#9a9590;margin:14px 0 0">The $45 enrollment fee is waived when you complete a tour and reserve a space. Your spot on the waitlist is unchanged either way.</p>`

**Copy discipline checks passed:**
- "$45 enrollment fee" always paired with its condition ("when you reserve a space after your visit" /
  "when you complete a tour and reserve a space"). No isolated waiver claim.
- "nothing to pay to come see us" states the tour has no cost WITHOUT the banned "free tour" phrasing.
- No em dashes (verified: hyphens/colons/periods only). No licensing text.
- Team voice, "With love, The Growing Mindfully team". The ":)" where natural.
- The waiver applies at RESERVATION (deposit step) and only after a completed tour - matches the
  no-show gate + the $45-lives-in-the-deposit reality (enrollfee-noshow Part A). It never claims the
  $45 is refunded or already off; it says it comes off going forward, which stays truthful even before
  the family reserves.

### 1g. emailShell call (for the code lane)
```
emailShell(
  'A short visit, and the enrollment fee is on us',
  bodyInner,           // §1f
  'Book your tour',    // CTA label
  urls.tourUrl,        // tracked /t/<token> resolving to /tour/?offer=enroll-waiver (§1e)
  undefined,           // default footer (address)
  afterCta             // §1f muted condition line
)
```

---

## 2. T2 WINBACK POPUP - reserve-page exit-intent -> book a tour

### 2a. What exists vs what is net-new (from tours-fees-code §3 + GAPS)
The fee-exit winback popup already exists in `overlay.js`: `onUserDismiss` (:1335) -> `showFeeWinback`
(:1354), a top-layer scrim with three buttons and the `gmwl_fee_exit_winback_*` events. **Net-new for
T2 (do not re-invent the module, extend it):**
1. The dismiss hook only fires on the `pay`/`child` STEPS. The reserve flow screens are MODES
   (`calendar`, `reserve-disclaimer`, `welcome`), so nothing fires on reserve-page exit today. T2 adds a
   reserve-mode branch to `onUserDismiss`.
2. The existing tour button POSTs `/api/portal/:token/request-tour` (queues an admin email, no booking).
   T2 must instead **route to `/tour/` and record the booking** (open `/tour/?offer=enroll-waiver` so
   the same waiver + tracking contract as T3 applies).
3. New events namespaced for the reserve surface so it reports separately from the fee-exit popup.

This is a distinct trigger context; reuse the scrim builder, swap the copy + the button destination +
the event names.

### 2b. Trigger condition (for the code lane)
Fire at most once per session (a `reserveWinbackSeen` flag, mirroring `feeWinbackSeen`) when a family
tries to dismiss the overlay while in a reserve mode (`calendar` / `reserve-disclaimer` before the
deposit is paid), and the family has NOT completed a tour (`gmwl_offer_ctx` has no `tour_booking_id`).
Any other mode closes immediately, exactly like today.

### 2c. Popup copy (headline + subtext + buttons)

**Headline:** `Not ready to reserve just yet?`

**Subtext:** `Come see us first. Book a quick tour, and we will waive your $45 enrollment fee when you reserve after your visit. Your spot is saved while you decide.`

**Buttons (three, same layout as the fee-exit popup):**
- **Primary - `Book a tour`** (`#gmwl-reserve-winback-tour`): fires `gmwl_reserve_exit_winback_tour`,
  then routes to `https://www.growingmindfully.org/tour/?offer=enroll-waiver` (new tab or same-window
  redirect) so the visit is booked through `/api/tours/book` and tracked (the offer + booking-tracking
  contract from §1e). Replaces today's `request-tour` POST.
- **Secondary - `Keep reserving`** (`#gmwl-reserve-winback-stay`): fires
  `gmwl_reserve_exit_winback_stay`, removes the scrim, returns to the reserve flow.
- **Tertiary (muted text link) - `No thanks, close`** (`#gmwl-reserve-winback-leave`): fires
  `gmwl_reserve_exit_winback_leave`, removes the scrim and closes the overlay.

**Copy checks:** "$45 enrollment fee" paired with condition ("when you reserve after your visit").
"Book a tour" not "free tour". No em dashes. Warm, low-pressure, team voice. No signature needed in a
popup. Never claims the deposit or the $45 is refundable.

### 2d. Events (new, namespaced to the reserve surface)
- `gmwl_reserve_exit_winback_shown` (on render)
- `gmwl_reserve_exit_winback_tour` (primary click)
- `gmwl_reserve_exit_winback_stay` (secondary)
- `gmwl_reserve_exit_winback_leave` (tertiary / dismiss)

All via the existing `gmwlTrackFunnel` -> `gmwlTrack('gmwl_'+name)` path (fire-and-forget, auto-merges
attribution). These are the T2 numerator for the funnel report (shown -> tour -> booked -> completed).

### 2e. Mechanics reused verbatim (no change)
Scrim build (fixed, z-index `2147483647`, DOM-sibling paint order for hit-testing), the once-per-session
guard pattern, and the `gmwlTrack` wiring are all inherited from `showFeeWinback` unchanged. T2 is a
copy + destination + event-name variant of that module on a new dismiss branch.

---

## 3. Open questions / handoffs (do not let these slip)

1. **BLOCKER (§0):** T3 + T2 cannot SEND until the `enrollmentFeeDue` choke-point + clickwrap/agreement
   version bump land. Copy is staged, not cleared. Owner: waitlist-flow + policy lanes, Jarred gate.
2. **Waiver on completion vs booking.** Copy says the $45 comes off "when you complete a tour and
   reserve." That means the waiver flag attaches at BOOK time (`offer=enroll-waiver` in `gmwl_offer_ctx`)
   but only APPLIES at the deposit step AFTER the tour is marked attended (the T4 no-show gate). The code
   lane must not zero the $45 for a family who booked but no-showed. Confirm this activation timing with
   the D-lane state machine (mirror `tour_waivers` waiver_state: pending -> waived on completion).
3. **`/t/:token` offer passthrough** (§1e) is a small backend extension (store offer on the invite row,
   append the server-controlled enum to the fixed `/tour/` dest). If the code lane prefers not to touch
   `/t/`, use the `/c/:token` query-preserving fallback. Either way the authored href must both stamp a
   click AND deliver `?offer=enroll-waiver` to `/tour/`.
4. **Email-only tour visitors with no application** cannot have a $45 deposit waiver (no deposit exists).
   T3's audience is fee-paid applicants only, so this is safe here, but the `/tour/?offer=enroll-waiver`
   landing must no-op the waiver gracefully for any non-application visitor (waiver-package §3 / gap #1).
5. **Suppression + quiet window.** T3 is marketing: it inherits the auto suppression gate and must
   respect the existing 72h quiet-window overlap with the winback sweep so a family is not hit by T3 and
   a winback email in the same window. Code lane to reconcile the cadence in the `*/10` leg.
6. **T4 picture coordination:** T4 lane must pick a third distinct hero (not community.jpg, not play.jpg).

## 4. Files this touches (for downstream code lanes)
- Email template: new registry entry in `~/Projects/gm-waitlist/src/server/campaigns.ts` using
  `emailShell` from `email.ts` (heading/body/CTA/afterCta per §1f-1g).
- Popup: `~/Projects/gm-waitlist/src/web/overlay/overlay.js` - new reserve-mode branch on
  `onUserDismiss` (:1335) + a `showReserveWinback` variant of `showFeeWinback` (:1354).
- Tour link offer passthrough: `tourRedirectDest()` / `/t/:token` in `index.ts` (or `/c/:token`
  fallback), + `tour_invites` offer column (side table / additive).
- `/tour/` inline offer-capture script already specified by the waiver-package §1c contract
  (`gmwl_offer_ctx`); reuse, add `offer=enroll-waiver` as a recognized code.
