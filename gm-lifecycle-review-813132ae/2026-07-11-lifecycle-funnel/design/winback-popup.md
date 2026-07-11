# Design: T2 Reserve-Exit Winback Popup (end-to-end)

Lane: T2 of the lifecycle funnel (CONTEXT-PACK2 directive item 2). The popup a fee-paid family
sees when they try to EXIT the reserve-a-space flow WITHOUT reserving. It offers a free tour,
routes them to `/tour/` carrying their family token plus T2 campaign attribution, so the tour
booking is tracked back to the T2 stage.

Grounded in: `ground/tours-fees-code.md` (fee-exit module + reserve flow), `ground/ga4-ads-state.md`
(event inventory), `ground/site-lp-conventions.md` (offer/attribution handoff), and verbatim reads
of `~/Projects/gm-waitlist/src/web/overlay/overlay.js`, `src/server/routes/tours.ts`,
`src/server/winback.ts`, and `~/Projects/growingmindfully/tour/index.html`.

Design principle: this is a NARROW extension of the EXISTING fee-exit winback module
(`showFeeWinback`, overlay.js:1354), not a new subsystem. Same scrim mechanics, same
`gmwlTrackFunnel` wiring, same one-per-session posture. The two deltas are (a) it fires on
reserve MODES instead of the pay/child STEPS, and (b) its primary button NAVIGATES to `/tour/`
with a real tour token instead of POSTing `request-tour`.

---

## 0. Why this is net-new (the gap it closes)

The existing fee-exit popup only fires from `onUserDismiss` (overlay.js:1335) when
`currentStepDef()` returns a step whose id is `pay` or `child`. The reserve-a-space screens are
MODES (`reserve-question`, `availability-check`, `secure-space`, `calendar`, `reserve-disclaimer`,
`welcome`), and `currentStepDef()` returns `null` for all of them (overlay.js:1577). So today a
family who exits the reserve page gets NO winback. T2 is: make the dismiss hook (and two exit-intent
heuristics) fire a book-a-tour popup on the reserve modes, and route the tour booking so it credits
T2. This is exactly GAP #1 and #2 in `ground/tours-fees-code.md` section 7.

---

## 1. Where it plugs in (files + hooks)

| File | Hook | Change |
|---|---|---|
| `gm-waitlist/src/web/overlay/overlay.js` | `onUserDismiss()` (:1335) | Add a reserve-mode branch that calls `showReserveExitWinback()` before `close()`. |
| same | new `showReserveExitWinback()` | Clone `showFeeWinback` (:1354); different copy, different button action (navigate to `/tour/`), new event names. |
| same | new `armReserveExitIntent()` / `disarmReserveExitIntent()` | Desktop `mouseout` + mobile back-intent + mobile scroll-to-top listeners, armed only while eligible. Call from the reserve render paths (`renderCalendarScreen`/`renderSecureSpaceScreen`/`renderReserveDisclaimerScreen`) and disarmed on `close()`/`unmount()`. |
| same | `escListener` (:1329) | Unchanged. The scrim installs its OWN capture-phase Esc handler so Esc dismisses the POPUP, not the sheet (see A11y). |
| `gm-waitlist/src/server/routes/tours.ts` OR a small portal route | new `POST /api/portal/:token/tour-invite` | DEPENDENCY (backend lane): mint/return the family's tour token so the popup can build `/tour/?t=<token>`. Reuses `ensureTourToken` (winback.ts:88). Details in section 5. |
| `growingmindfully/tour/index.html` | booking IIFE prefill (:608) | OPTIONAL fallback: accept `?email=&name=` prefill when no `t` token. Lets the popup degrade gracefully if the mint endpoint is unavailable. |

The overlay is served remotely (`waitlist.growingmindfully.org/overlay/overlay.js?v=36`), so this
ships as an overlay version bump. No LP edits required for T2 (the reserve flow lives inside the
overlay SPA, which every ad LP already loads).

---

## 2. Trigger conditions

Three layered signals, all funneling through ONE eligibility gate and ONE render (`showReserveExitWinback`),
so no two signals can double-fire.

### 2a. Eligibility gate (the single source of truth)
```js
// Reserve screens where an exit means "leaving without reserving". Excludes 'welcome'
// (post-deposit success) and all intake/pay steps (those own the fee-exit popup).
const T2_RESERVE_MODES = ['reserve-question','availability-check','availability',
                          'secure-space','calendar','reserve-disclaimer'];

let t2WinbackSeen = false; // once-per-session, INDEPENDENT of feeWinbackSeen

function t2ReserveWinbackEligible() {
  if (t2WinbackSeen) return false;                       // session cap
  if (!mounted) return false;
  if (T2_RESERVE_MODES.indexOf(mode) === -1) return false; // only on reserve screens
  if (state && (state._deposit_paid || state._reserve_done)) return false; // already reserved
  if (t2PerFamilyCapHit()) return false;                 // once-per-family (localStorage)
  return true;
}
```
Notes:
- Fee-paid is implied: the deposit gate ladder (`ground/tours-fees-code.md` section 4) requires
  `fee_paid=1` before any reserve mode is reachable via the portal, so "in a reserve mode" already
  means the family cleared the $65 fee. That is the T1 precondition, so T2's audience is correct by
  construction. If desired, tighten by reading a cached `state._fee_paid` when present.
- `welcome` is deliberately excluded: a family who just paid the deposit is done, never win-back them.

### 2b. Signal A - deterministic dismiss (primary, reliable)
Extend `onUserDismiss()`. This is the X button, backdrop tap, and Esc on the sheet - the same
gesture the fee-exit popup already intercepts.
```js
function onUserDismiss() {
  let step = null;
  try { step = currentStepDef(); } catch (_) {}
  // ...existing draft-flush block unchanged...

  // Fee-exit popup (existing) - pay/child steps only.
  if (step && !feeWinbackSeen && (step.id === 'pay' || (step.id === 'child' && !state.fee_ack))) {
    showFeeWinback(); return;
  }
  // T2 reserve-exit popup (new) - reserve modes only.
  if (t2ReserveWinbackEligible()) { showReserveExitWinback('dismiss'); return; }

  close();
}
```
The reserve flow uses `saveDraft()` internally, so the chosen start date / agreement state persist in
localStorage even though navigating to `/tour/` is a full-page nav; a family who books a tour and comes
back resumes their reserve draft.

### 2c. Signal B - desktop exit-intent (`mouseout` toward browser chrome)
Classic top-edge exit intent. Armed only while eligible; fires the SAME popup.
```js
function onDesktopExitIntent(e) {
  // Cursor left the viewport through the TOP (toward tabs / URL bar / close), not a child element.
  if (e.clientY > 0) return;
  if (e.relatedTarget || e.toElement) return;
  if (!t2ReserveWinbackEligible()) return;
  showReserveExitWinback('mouseout');
}
```
Arm with a settle delay so it never fires on the mouse motion that OPENED the reserve screen:
```js
function armReserveExitIntent() {
  if (t2ExitArmed) return;
  // Pointer-fine only (skip touch, which has no hover/mouseout). >1.2s dwell before arming.
  if (!window.matchMedia || !window.matchMedia('(pointer:fine)').matches) return;
  t2ExitArmTimer = setTimeout(() => {
    document.addEventListener('mouseout', onDesktopExitIntent);
    t2ExitArmed = true;
  }, 1200);
}
```

### 2d. Signal C - mobile back-intent (history guard)
Touch devices have no `mouseout`. Use a single pushed history entry as a back-button trap: the first
Back press pops our sentinel and fires the popup instead of unwinding the SPA. Conservative,
one-shot, and self-cleaning.
```js
function armMobileBackIntent() {
  if (t2BackArmed) return;
  if (window.matchMedia && window.matchMedia('(pointer:fine)').matches) return; // touch only
  history.pushState({ gmwlT2: 1 }, '');   // sentinel
  window.addEventListener('popstate', onMobileBackIntent);
  t2BackArmed = true;
}
function onMobileBackIntent() {
  if (t2ReserveWinbackEligible()) { showReserveExitWinback('back_intent'); }
  // Either way, stop trapping Back after the first press so a second Back really leaves.
  disarmMobileBackIntent();
}
```
`pagehide` / `visibilitychange:hidden` are NOT used to trigger the popup (you cannot reliably render
a modal during unload); they are used only to fire a best-effort `gmwl_reserve_exit_winback_missed`
beacon so the campaign grid can see silent abandons.

### 2e. Signal D - mobile scroll-to-top exit intent (velocity heuristic)
Back-intent (Signal C) only catches the hardware/gesture Back. Many mobile abandons instead flick
the page rapidly upward to reach the address bar, the tab switcher, or the browser close affordance,
which the history trap never sees. Signal D is a conservative velocity heuristic for that gesture:
the family must first engage the reserve screen (scroll DOWN past a threshold), then flick UP fast
and land near the top. It is touch-only, one-shot, and funnels through the same eligibility gate, so
it can never double-fire with the back-intent or dismiss signals.
```js
let t2ScrollArmed = false, t2MaxScroll = 0, t2LastY = 0, t2LastT = 0;
function armReserveScrollIntent() {
  if (t2ScrollArmed) return;
  if (window.matchMedia && window.matchMedia('(pointer:fine)').matches) return; // touch only
  t2LastY = window.scrollY || 0; t2LastT = Date.now(); t2MaxScroll = t2LastY;
  window.addEventListener('scroll', onMobileScrollIntent, { passive: true });
  t2ScrollArmed = true;
}
function onMobileScrollIntent() {
  const y = window.scrollY || 0, now = Date.now();
  t2MaxScroll = Math.max(t2MaxScroll, y);
  const dt = now - t2LastT;
  const v = dt > 0 ? (t2LastY - y) / dt : 0;   // px/ms upward (positive = scrolling up)
  t2LastY = y; t2LastT = now;
  // Require prior engagement (scrolled >=320px into the screen), a fast upward flick
  // (>1.4 px/ms), and arrival near the top (<80px). All three -> exit intent.
  if (t2MaxScroll >= 320 && v > 1.4 && y < 80) {
    if (!t2ReserveWinbackEligible()) return;
    showReserveExitWinback('scroll_top');
  }
}
function disarmReserveScrollIntent() {
  window.removeEventListener('scroll', onMobileScrollIntent);
  t2ScrollArmed = false;
}
```
Thresholds (320px engagement, 1.4 px/ms flick, 80px top band) are deliberately strict so ordinary
"scroll back up to re-read the calendar" motion does not trip it; tune against real session replay
before widening. Signal C (back-intent) and Signal D (scroll) both arm on touch and are NOT mutually
redundant: C catches the Back button, D catches the flick-to-chrome. Whichever fires first sets
`t2WinbackSeen=true` and disarms the other.

Arm all three heuristics (mouseout, back-intent, scroll) from the reserve render entry points via a
single `armReserveExitIntent()` wrapper that dispatches by pointer type (fine -> mouseout;
coarse -> back-intent + scroll); `disarmReserveExitIntent()` tears all of them down. Disarm on
`close()`, `unmount()`, mode change out of `T2_RESERVE_MODES`, and immediately inside
`showReserveExitWinback` (so the popup can never re-trigger itself). Because every path funnels
through `t2ReserveWinbackEligible()` and sets `t2WinbackSeen=true` on show, the four signals are
mutually exclusive per session.

---

## 3. Frequency cap

Two independent caps, matching the fee-exit posture and the CAN-SPAM-adjacent "do not nag" intent.

1. Once per SESSION - `t2WinbackSeen` boolean (set true inside `showReserveExitWinback`), mirrored to
   `sessionStorage['gmwl_t2wb_session']='1'` so an overlay remount within the same tab session does
   not re-offer. Read it back into `t2WinbackSeen` on mount.
2. Once per FAMILY - `localStorage['gmwl_t2wb_seen:'+familyKey] = Date.now()`. `familyKey` =
   `state._created?.application_id` (fresh flows) OR a truncated non-reversible marker of the portal
   token for portal-launched reserve (store only the last 8 chars, never the full token, to avoid
   persisting a bearer credential in localStorage). `t2PerFamilyCapHit()` returns true if the key is
   present. This survives across sessions on the same device.

Optional cross-device authority (RECOMMENDED for the campaign grid, flagged dependency): on show, fire
`bridgeEnqueue('t2_reserve_winback_shown', { application_id })` (server, via the same
`request-tour`-style path). This gives the Kindred per-family x campaign grid a real T2 "received"
cell and lets the T3 email lane avoid double-nudging a family who already saw the onsite popup. Not
required for the popup to function; the localStorage cap is the client MVP.

The fee-exit `feeWinbackSeen` and the T2 `t2WinbackSeen` are SEPARATE flags on purpose: a family who
paid the fee earlier in the same session (and possibly saw the fee-exit popup) can still receive the
distinct reserve-exit popup later. They gate on disjoint modes so they never collide on one dismiss.

---

## 4. The component (reuse the fee-exit scrim architecture verbatim)

`showReserveExitWinback(trigger)` is a near-clone of `showFeeWinback` (overlay.js:1354). It reuses the
proven scrim mechanics unchanged:
- Fixed top-layer `div.gmwl-winback-scrim` appended to `document.body` (NOT inside `.gmwl-backdrop`),
  `z-index:2147483647` matching `.gmwl-sheet`; because it is a LATER DOM sibling at equal z-index it
  wins the paint order, so its buttons are hittable over the max-int sheet. This is the exact trick
  documented at overlay.js:1361-1366. Do not deviate.
- `role="dialog"`, `aria-modal="true"`, brand-token inline styles (`--gm-bg`, `--gm-serif`,
  `--gm-green-deep`, `--gm-ink`, `--gm-ink-soft`), 360px max-width card.

```js
function showReserveExitWinback(trigger) {
  t2WinbackSeen = true;
  try { sessionStorage.setItem('gmwl_t2wb_session','1'); } catch (_) {}
  t2MarkPerFamilySeen();
  disarmReserveExitIntent();  // kill both heuristics so the popup can't re-arm
  try {
    gmwlTrackFunnel('reserve_exit_winback_shown', {
      lifecycle_stage: 'T2', reserve_mode: mode, trigger: trigger || 'dismiss',
      from_t1: !!(state && state._from_t1)
    });
  } catch (_) {}

  const prevFocus = document.activeElement;              // A11y: restore on close
  const wrap = document.createElement('div');
  wrap.className = 'gmwl-winback-scrim';
  wrap.setAttribute('role','dialog');
  wrap.setAttribute('aria-modal','true');
  wrap.setAttribute('aria-labelledby','gmwl-t2wb-title');
  wrap.setAttribute('aria-describedby','gmwl-t2wb-desc');
  wrap.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;'
    + 'justify-content:center;padding:20px;background:rgba(31,42,46,.55);backdrop-filter:blur(2px)';
  wrap.innerHTML =
    '<div class="gmwl-winback-card" role="document" style="background:var(--gm-bg,#FBF7EE);border-radius:14px;max-width:360px;width:100%;padding:22px 22px 20px;box-shadow:0 18px 48px rgba(31,42,46,.28);text-align:center">'
    +  '<h3 id="gmwl-t2wb-title" style="font-family:var(--gm-serif,Newsreader),serif;font-size:20px;color:var(--gm-green-deep,#3D8189);margin:0 0 8px">Come see us before you decide?</h3>'
    +  '<p id="gmwl-t2wb-desc" style="font-size:14px;color:var(--gm-ink,#1F2A2E);line-height:1.55;margin:0 0 18px">You have paid your waitlist fee, so your place is safe. Book a free tour of our downtown Sacramento space, meet the teachers, and reserve when you are ready.</p>'
    +  '<div style="display:flex;flex-direction:column;gap:10px">'
    +    '<button class="gmwl-next" id="gmwl-t2wb-tour" type="button" style="width:100%">Book a free tour</button>'
    +    '<button class="gmwl-back" id="gmwl-t2wb-stay" type="button" style="width:100%">Keep reserving my space</button>'
    +    '<button id="gmwl-t2wb-leave" type="button" style="background:none;border:none;color:var(--gm-ink-soft,#6F7F84);font-size:13px;text-decoration:underline;cursor:pointer;padding:4px">No thanks, exit</button>'
    +  '</div>'
    + '</div>';
  document.body.appendChild(wrap);

  // A11y wiring (section 7)
  const focusable = wrap.querySelectorAll('button');
  focusable[0].focus();
  const onKey = (ev) => {
    if (ev.key === 'Escape') { ev.stopPropagation(); ev.preventDefault(); doStay(); return; }
    if (ev.key === 'Tab') { trapFocus(ev, focusable); }
  };
  wrap.addEventListener('keydown', onKey, true); // capture phase: beat the sheet's escListener

  const removeScrim = () => {
    wrap.removeEventListener('keydown', onKey, true);
    if (wrap.parentElement) wrap.parentElement.removeChild(wrap);
    try { if (prevFocus && prevFocus.focus) prevFocus.focus(); } catch (_) {}
  };
  function doStay() { try { gmwlTrackFunnel('reserve_exit_winback_stay', { lifecycle_stage:'T2' }); } catch(_){} removeScrim(); }

  document.getElementById('gmwl-t2wb-stay').onclick  = doStay;
  document.getElementById('gmwl-t2wb-leave').onclick = () => {
    try { gmwlTrackFunnel('reserve_exit_winback_leave', { lifecycle_stage:'T2' }); } catch(_){}
    removeScrim(); close();
  };
  document.getElementById('gmwl-t2wb-tour').onclick  = async () => {
    const btn = document.getElementById('gmwl-t2wb-tour');
    btn.disabled = true; btn.textContent = 'One moment...';
    try { gmwlTrackFunnel('reserve_exit_winback_tour', { lifecycle_stage:'T2' }); } catch(_){}
    try { saveDraft(); } catch (_) {}                 // keep the reserve draft resumable
    const url = await buildT2TourUrl();               // section 5
    window.location.assign(url);                       // same-tab nav keeps GA session continuity
  };
}
```

Copy is DRAFT and parent-facing, so it is a Tier-2 Jarred gate before ship. No em dashes. Voice is the
team "we", never signed Jarred. Note the copy leans on "you have paid your waitlist fee, so your place
is safe" - true for every family in a reserve mode, and it reframes the tour as low-pressure rather
than a downgrade.

---

## 5. Routing to `/tour/` carrying family token + campaign attribution

The whole point of T2: the tour booking must be attributable to the T2 stage AND stitched to the
family. Two attribution planes, both filled by the URL the popup navigates to:

- D1 / family plane: the `?t=<tourToken>` param. `/tour/` reads it (tour/index.html:367), prefills
  contact from `GET /api/tours/prefill?t=`, and carries it into `POST /api/tours/book` as `t`.
  `tours.ts` then resolves `subject_type/subject_key` from `tour_invites` (tours.ts:302), stamps
  `tour_invites.tour_booked_at` (tours.ts:329), and writes `funnel_events` for the application subject
  (`ground/tours-fees-code.md` section 1 side-effects). That is the family + T2 stitch in D1.
- GA4 / Ads plane: `utm_*` params on the `/tour/` URL tag the GA session to T2, and re-passing the
  original `gclid` keeps the downstream `gmwl_tour_booked` conversion rolled up to the ad campaign that
  first drove this family. `/tour/` grabs `client_id`/`session_id` off gtag and rides them into the
  booking POST (tour/index.html:378-382), so the server-side `gmwl_tour_booked` (tours.ts:341) stitches
  to this session.

### URL builder
```js
async function buildT2TourUrl() {
  const base = 'https://www.growingmindfully.org/tour/';
  const attr = gmwlCaptureAttribution();               // overlay.js:649 (sessionStorage-backed)
  const p = new URLSearchParams();
  const token = await t2MintTourToken();               // family token (below); may be null
  if (token) p.set('t', token);
  p.set('utm_source', 'lifecycle');
  p.set('utm_medium', 'onsite_winback');
  p.set('utm_campaign', 't2_reserve_exit_winback');
  if (attr.gclid) p.set('gclid', attr.gclid);          // preserve original ad credit
  if (attr.campaign) p.set('utm_content', attr.campaign);
  // Fallback prefill when there is no token (see dependency): pass contact so the family
  // does not retype. /tour/ needs the small prefill patch below to honor these.
  if (!token) {
    const c = t2FamilyContact();                        // {name,email} from cached quote/portal
    if (c && c.email) p.set('email', c.email);
    if (c && c.name)  p.set('name',  c.name);
  }
  return base + '?' + p.toString();
}
```

### Family token source - DEPENDENCY (backend lane owns this)
The reserve flow holds `state._availability_portal_token` (the family's portal bearer), NOT a
`tour_invites` token. The clean way to get a bookable, family-stitched tour token is one small route
that reuses the existing helper:

```
POST /api/portal/:token/tour-invite            (portal_token in path = login-bypass, same as
                                                 /api/portal/:token/request-tour, index.ts:3710)
  rate-limit: 8/min/IP (mirror request-tour)
  body (optional): { gclid?, campaign? }        // stamp onto the invite for server-side attribution
  behavior:
    - resolve application_id from portal_token
    - token = ensureTourToken(db, 'application', application_id)   // winback.ts:88, idempotent
    - (optional) stamp tour_invites.lifecycle_stage='T2', source='reserve_exit_winback'
    - bridgeEnqueue('t2_reserve_winback_shown', { application_id })  // campaign-grid "received"
  returns: { token }                            // the 24-char base62 tour token
```
`t2MintTourToken()` POSTs to this route with `state._availability_portal_token` and returns
`data.token`. `tours.ts` already knows how to book against an application-subject token, so NO change
to the booking path is needed; the invite carries the family + T2 linkage.

### Zero-backend fallback (degraded, ships even if the route is not ready)
If `t2MintTourToken()` returns null (route absent or failed), `buildT2TourUrl` omits `t` and passes
`?email=&name=` instead. Add a tiny prefill branch to the `/tour/` IIFE (tour/index.html near :608):
if there is no `t` token but `email`/`name` query params exist, use them as `prefill` and skip the
`/api/tours/prefill` fetch. In this mode the GA/Ads plane still credits T2 (via utm + gclid), but the
D1 application-subject stitch is lost (no invite token). Acceptable for a first ship; the mint route is
the correct long-term path. This is the same trade the fee-exit popup makes today when there is no
portal token (it falls back to a mailto). Do NOT route through `/t/:token` - that redirect is for
email-link click stamping and 302s to a fixed destination with no query passthrough.

---

## 6. GA4 / gtag events

New T2 event family, prefixed `gmwl_` per the naming rule, fired through the existing
`gmwlTrackFunnel` -> `gmwlTrack` -> `gtag('event', ...)` path (overlay.js:813, 746). These land in GA4
on every ad LP and `/rates` and `/` (all carry gtag `G-QK5VPGREL8` per `ground/ga4-ads-state.md`
section 1). The reserve flow itself runs inside the overlay embedded on those pages, so the events reach
GA4.

| Event | Fires when | Key params |
|---|---|---|
| `gmwl_reserve_exit_winback_shown` | popup rendered | `lifecycle_stage:'T2'`, `reserve_mode`, `trigger` (`dismiss`/`mouseout`/`back_intent`/`scroll_top`), `from_t1` |
| `gmwl_reserve_exit_winback_tour` | "Book a free tour" clicked | `lifecycle_stage:'T2'` |
| `gmwl_reserve_exit_winback_stay` | "Keep reserving" / Esc | `lifecycle_stage:'T2'` |
| `gmwl_reserve_exit_winback_leave` | "No thanks, exit" | `lifecycle_stage:'T2'` |
| `gmwl_reserve_exit_winback_missed` | best-effort on `pagehide`/hidden while eligible+unseen | `reserve_mode` |

Attribution auto-merges via `gmwlCaptureAttribution` (source/medium/campaign/gclid/fbclid), so each
event already carries the ad click. These are ENGAGEMENT diagnostics, not conversions - the actual
conversion is the downstream `gmwl_tour_booked` (server MP, tours.ts:341), which now carries the T2
utm + the `t` invite linkage. Recommend: do NOT import any `_winback_*` event to Ads as a conversion
(avoids the low-value-primary trap flagged in `ground/ga4-ads-state.md` section 3); import stays on
`gmwl_tour_booked` once it is starred as a key event. If a T2-specific conversion cut is wanted later,
segment `gmwl_tour_booked` by `utm_campaign=t2_reserve_exit_winback` in GA4 rather than minting a new
key event.

The `shown -> tour -> (downstream) tour_booked` chain plus the `_missed` beacon give the Kindred
campaign grid a full received / engaged / converted read for the T2 column (directive item 3).

---

## 7. Accessibility

- Focus management: on show, move focus to the primary button; on close, restore focus to
  `document.activeElement` captured before show (`prevFocus`). Prevents focus landing on `<body>`.
- Focus trap: `trapFocus(ev, focusable)` cycles Tab/Shift+Tab among the three buttons so keyboard
  users cannot tab behind the modal into the (inert) sheet.
- Esc precedence: the scrim registers its keydown handler in the CAPTURE phase
  (`addEventListener('keydown', onKey, true)`) and calls `stopPropagation()`, so Esc dismisses the
  POPUP (as "stay") and never reaches the sheet's `escListener` (overlay.js:1329) - Esc must not blow
  past the winback and close the whole overlay.
- Labelling: `role="dialog"`, `aria-modal="true"`, `aria-labelledby` -> title id, `aria-describedby`
  -> body id. Inner card is `role="document"`.
- Real controls: all three actions are `<button type="button">` (keyboard + AT operable). The "exit"
  affordance is a styled button, not a bare link, so it is reachable and announced.
- Hit-testing: the max-z + later-sibling paint trick (section 4) guarantees the buttons are clickable
  over the max-int sheet; without it they would be visually present but dead.
- Reduced motion: the only motion is the cosmetic `backdrop-filter: blur(2px)`; the popup has no
  entrance animation, so it is already `prefers-reduced-motion` safe. Do not add a transition that the
  reduced-motion guard would need to strip.
- Contrast: title `#3D8189` on `#FBF7EE` and body `#1F2A2E` on `#FBF7EE` both clear WCAG AA; the
  underline on the tertiary "exit" button gives a non-color affordance.
- Touch targets: primary/secondary buttons inherit `.gmwl-next`/`.gmwl-back` sizing (>=44px);
  the tertiary exit link has `padding:4px` plus text - acceptable as the lowest-priority action.

---

## 8. Interaction with the rest of the lifecycle funnel

- Upstream (T1): the "Reserve Your Space" T1 email deep-links to `/portal/<token>?...`, which boots
  straight into the reserve flow (overlay.js:1209-1224). Tag that link `utm_campaign=lifecycle_t1` (or
  `src=t1`); the boot reads it and sets `state._from_t1=true`, which the `_shown` event records. This
  is attribution enrichment, NOT a gate - any fee-paid family exiting the reserve page is a valid T2
  target, whether or not they came from T1.
- Downstream (T3): T3 ("book a tour + waive enrollment fee", +24h) is an EMAIL lane. If the family
  booked a tour from this popup, the tour is on the books and T3 should suppress (the C-segment /
  lifecycle sweep already excludes families with a tour invite/booking). The optional
  `t2_reserve_winback_shown` bridge event (section 3) also lets T3 skip a family who saw the onsite
  offer, avoiding same-day double-touch (CAN-SPAM courtesy).
- Downstream (T4): T4 fires 1h after a tour ENDS unless no-show. A tour booked via this popup flows
  into the exact same `tour_bookings` row and `gmwl_tour_booked` event as any other tour, so T4's
  completion sweep picks it up with no special-casing. T4's no-show gate is a separate lane's build
  (`ground/tours-fees-code.md` GAP #3); this popup only needs to produce a real, tracked booking, which
  it does via the `t` token.
- Campaign grid (directive item 3): the `_shown` (received), `_tour`/`_stay`/`_leave` (engaged), and
  downstream `gmwl_tour_booked` (converted) give the T2 column its three cell states with drill-down
  timestamps.

---

## 9. Dependencies and open flags

1. BACKEND (required for clean attribution): `POST /api/portal/:token/tour-invite` returning a
   `tour_invites` token (section 5). Small, reuses `ensureTourToken`. Owner: tours/fees backend lane.
   Until it lands, the popup ships in fallback mode (email/name prefill, GA-only T2 credit).
2. SITE (fallback only): the `/tour/` `?email=&name=` prefill branch (tour/index.html ~:608). One small
   client edit; skip if dependency #1 ships first.
3. OPTIONAL: `bridgeEnqueue('t2_reserve_winback_shown', {application_id})` for cross-device once-per-family
   and the campaign-grid "received" cell. Server change; the client localStorage cap works without it.
4. GA4: register `gmwl_tour_booked` as a key event so the T2-segmented conversion is importable
   (already flagged cold-start-blocked in `ground/ga4-ads-state.md`; not this lane's job but this popup
   is the first thing that will actually FIRE a booking from the reserve flow).
5. POLICY: parent-facing popup copy = Tier-2 Jarred gate. Copy in section 4 is a draft. Overlay version
   bump (prod deploy of `overlay.js`) is also Tier-2.
6. SCOPE NOTE: `availability` / `availability-check` ("just checking") can in principle be reached
   pre-fee; if we ever expose those outside the fee-paid portal path, add an explicit `state._fee_paid`
   check to the eligibility gate so T2 never targets a non-fee-paid visitor.

---

## 10. Hard-rule compliance checklist

- No em dashes in any copy or code (verified: hyphens/colons/periods only).
- No licensing text added anywhere.
- No new D1 columns: reuses the existing `tour_invites` table via `ensureTourToken`; no schema change
  for the popup. (The optional `lifecycle_stage`/`source` stamp would be an additive column on
  `tour_invites`, a side table, not `applications` - consistent with the additive-only rule.)
- Public flow untouched on the money path: the popup only navigates to `/tour/` and (optionally) mints
  a tour invite; it never writes `children`, never fires the Solace enroll gate, never charges. A tour
  booking is the existing paid-nothing `tour_bookings` path.
- Timezone: all tour scheduling stays America/Los_Angeles (the `/tour/` slot feed already is); the popup
  adds no scheduling logic.
- Voice: team "we", never signed Jarred; low-pressure, truthful ("your place is safe" is true for any
  fee-paid family).
- Tier-2 gates respected: copy + prod overlay deploy surfaced to Jarred, not self-shipped.

---

## 11. File / line touchpoints (implementation map)

- `gm-waitlist/src/web/overlay/overlay.js`
  - `onUserDismiss` (:1335) - add reserve-mode branch.
  - new `showReserveExitWinback` - clone of `showFeeWinback` (:1354).
  - new `t2ReserveWinbackEligible` / `t2WinbackSeen` / per-family cap helpers.
  - new `armReserveExitIntent` / `disarmReserveExitIntent` (mouseout + back-intent + scroll-to-top), called from
    `renderCalendarScreen` (:3258), `renderSecureSpaceScreen` (:2681), `renderReserveDisclaimerScreen`
    (:3572), disarmed in `close()` (:1300) / `unmount()` (:1321).
  - new `buildT2TourUrl` / `t2MintTourToken` / `t2FamilyContact` (uses `gmwlCaptureAttribution` :649,
    `state._availability_portal_token`).
  - version bump the overlay asset (`?v=37`) so LPs pull the new build.
- `gm-waitlist/src/server/routes/tours.ts` or index.ts portal routes - new
  `POST /api/portal/:token/tour-invite` (reuses `ensureTourToken`, winback.ts:88).
- `growingmindfully/tour/index.html` - optional `?email=&name=` prefill fallback near :608.
