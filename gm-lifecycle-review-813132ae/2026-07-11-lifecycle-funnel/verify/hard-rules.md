# VERIFY: Hard-Rule Adversarial Scan (2026-07-11, refreshed)

Adversarial pass over every file in `design/` (12 files) + `ground/` against the CONTEXT-PACK2 HARD
RULES and the project CLAUDE.md non-negotiables. Dash scan is a codepoint check (U+2012/13/14/15 +
`&mdash;`/`&#8212;` HTML entities + double-hyphen-as-dash), not a visual skim. Every cited line was
re-read against the CURRENT file, not a cached copy: several design files were regenerated after the
prior scan (ad-variants 12:32, winback-popup 12:02, lp-factory 12:11), which SHIFTED line numbers.
Coordinates below are current as of this pass; the prior scan's numbers (winback 217/219/349,
ad-variants 211/240/277) are STALE - do not act on them.

**Bottom line:** the design DELIVERABLES are clean on the enumerated non-negotiables that would make
copy unsafe: 0 em dashes in any shipping copy, no children-table writes, no Solace enroll gate fired,
additive-only schema, no Stripe SDK introduced, honest 5PM promo, CAN-SPAM satisfied. The real
findings are: (HIGH) a licensing citation stamped onto five net-new LP surfaces; (MED) "free tour"
copy shipped in the T2 winback popup AND specced into the V2 LP, both breaking the house "no free
tour" rule; (MED) the V3 hero hardcodes "This week only" as a static string with no rotation binding;
(MED) two footer legal links vs the zero-internal-links isolation mandate. All are fixable pre-build;
none is a hidden copy-safety landmine. The $45-waiver send-gate is correctly flagged in every design.

Severity: HIGH = literal breach of an "ever"/non-negotiable, needs a Jarred ruling before ship.
MED = house/policy-rule breach or a latent trap a build agent would copy verbatim. LOW = self-flagged
or housekeeping, confirm-and-move.

---

## HIGH-1. Licensing citation on FIVE net-new landing-page surfaces ("Licensed by California CDSS")

- **File:** `design/lp-open-enrollment-mockup.html` line 435.
- **Exact text:** `<div class="foot-meta">© 2026 Growing Mindfully · Family-founded in Sacramento, 2018 · Licensed by California CDSS · Nut-free facility</div>`
- **Propagated by:** `design/lp-factory.md` line 215 - "Footer (sec 5): 3 columns + `.foot-meta`
  verbatim (CDSS badge stays, add nothing)." That instruction stamps this footer onto all five new
  test-LP slugs (`/lp/open-enrollment/`, `/lp/waitlist-fee-waived/`, `/lp/fees-waived/`,
  `/lp/free-tour/`, `/lp/back-to-school/`), so this is five net-new pages carrying a licensing
  citation, not a single mockup. Echoed as a "keep existing badge, add nothing new" guardrail in
  `design/ad-variants.md` lines 174-175 and `design/policy-compliance.md` line 421.
- **Rule breached:** CLAUDE.md, Jarred verbatim 2026-07-07: "do not add anything licensing related to
  our website or ads. ever." plus "Existing 'Licensed by California CDSS' badges stay as-is; add
  nothing new." CONTEXT-PACK2 line 59: "NEVER anything licensing-related in ads/site/emails." A brand
  new `/lp/<slug>/` page is net-new website surface; putting the CDSS citation on it is adding
  licensing text to the website.
- **Designers' rationale (represented fairly):** they read "badge stays, add nothing new" as "copy the
  EXISTING live footer verbatim (which already contains the badge)" - the string is not new, only its
  location is. The badge is on every current page; Jarred may bless it.
- **Why still flagged HIGH:** the rule is an emphatic "ever" that "overrides any compliance suggestion
  from any audit, counsel pass, or agent." The safe adversarial reading of an absolute rule is: do not
  propagate licensing text onto newly-authored surfaces. Literal breach until Jarred rules.
- **Fix (recommended):** drop the ` · Licensed by California CDSS` clause from the new-LP `.foot-meta`
  (keep copyright + "Family-founded in Sacramento, 2018" + "Nut-free facility"). Change the
  lp-factory.md:215 instruction from "CDSS badge stays" to "OMIT the CDSS clause on new test LPs." One
  Jarred decision: keep-verbatim-footer vs strip-licensing-on-new-pages.

---

## MED-2. "free tour" shipped in T2 winback LIVE copy (breaks house rule, contradicts sibling design)

- **File:** `design/winback-popup.md` (current coordinates; prior scan's 217/219 are stale).
- **Exact text, line 260 (body `<p>`):** `You have paid your waitlist fee, so your place is safe. Book a free tour of our downtown Sacramento space, meet the teachers, and reserve when you are ready.`
- **Exact text, line 262 (primary button):** `<button class="gmwl-next" id="gmwl-t2wb-tour" type="button" style="width:100%">Book a free tour</button>`
- **Also:** line 4 (module intro prose "It offers a free tour"), line 392 (event table label `"Book a free tour" clicked`).
- **Rule breached:** the house "no free tour" precision rule (`ground/waiver-package.md`; enforced by
  `policy-compliance.md` V4 lines 115, 130 and `email-tour-nudge.md` line 62). Tours were never
  priced, so "free tour" manufactures a claim; Google editorial also disfavors "Free."
- **Direct contradiction:** the OTHER design of this SAME T2 popup, `email-tour-nudge.md`, specs the
  button as "Book a tour" and line 62 states verbatim `No "free tour"`. Two files disagree on the same
  component; winback-popup.md is the non-compliant one.
- **Self-check miss:** winback-popup.md's own compliance checklist (line 483 "No licensing text added
  anywhere") has NO "no free tour" line and did not catch its own body/button copy.
- **Fix:** in `winback-popup.md` change lines 260 + 262 "Book a free tour" -> "Book a tour", update the
  intro (line 4) and the event-label (line 392). Aligns with the sibling design and the house rule.

---

## MED-3. "free tour" specced into the V2 landing page (design-doc trap, prior scan missed it)

- **File:** `design/lp-factory.md` line 157 (V2 Back to School LP spec).
- **Exact text:** `final ` + "`" + `.btn-paper` + "`" + ` same). Optional secondary ` + "`" + `Book a free tour` + "`" + ` -> ` + "`" + `/tour/` + "`" + `.`
  (i.e. the V2 LP spec offers a secondary CTA labeled "Book a free tour" linking to `/tour/`.)
- **Two rules touched:**
  1. **House "no free tour" rule ON-page:** lp-factory.md's OWN line 177 says "the LP must NOT
     manufacture a 'free tour' claim." Line 157 contradicts it by putting "Book a free tour" as a
     literal on-page button label. A build agent copying the V2 spec verbatim ships the banned phrase.
  2. **Isolation "zero internal links":** `-> /tour/` is an internal navigation link off the isolated
     test LP to the main-site tour page (see MED-4 for the mandate). Lower risk than a marketing link
     (/tour/ is itself noindex + 0 internal links), but it is still an outbound internal link.
- **Fix:** change the V2 secondary CTA label to "Book a tour" and route it to the same on-page tour
  calendar / `#cta-section` anchor rather than a cross-page `/tour/` link, so V2 keeps the flow on the
  isolated LP. If a `/tour/` handoff is truly wanted, log it as the isolation exception (MED-4 fix a).

---

## MED-4. V3 hero hardcodes "This week only" as a STATIC string (un-rotated urgency latent trap)

- **File:** `design/lp-factory.md` lines 161-163 (V3 `/lp/fees-waived/` hero).
- **Exact text, line 161 (kicker):** `This week only`
- **Exact text, line 162 (H1):** `Over $100 in fees waived <em>when you tour this week.</em>`
- **The gap:** only the fine-print `.condition-line` (line 164) uses a rotating `[[EXPIRY]]` token. The
  kicker and H1 embed "This week only" / "this week" as literal, unrotatable strings. If a build agent
  stamps this LP and the flight runs, the page says "This week only" every week regardless of date -
  exactly the evergreen-urgency policy landmine CONTEXT-PACK2 line 29 forbids ("'this week only'
  urgency claims must actually expire/rotate").
- **Why the prior scan cleared this wrongly:** it checked the DOC-LEVEL urgency policy (ad-variants
  section 5 rejects evergreen "this week only") and passed. It did not notice the V3 HERO COPY BLOCK
  itself hardcodes the urgency words while only the fine print rotates. V3 is currently HOLD (blocked
  on the $45 automation, line 166), which caps severity at MED, but the copy is a trap for whoever
  un-holds it.
- **Fix:** bind the kicker + H1 urgency to the same flight gate as `[[EXPIRY]]` (build-time token,
  emitted only during an armed dated flight), OR drop the urgency words from the V3 hero and let the
  dated `.condition-line` carry the deadline. Never ship a hardcoded "this week only" string.

---

## MED-5. Isolation "zero internal links" vs two footer legal links on the LP

- **File:** `design/lp-open-enrollment-mockup.html` lines 431-432.
- **Exact text:** `<li><a href="/privacy/">Privacy Policy</a></li>` and `<li><a href="/terms/">Terms of Use</a></li>`
- **Rule breached (letter):** CONTEXT-PACK2 line 41 + `lp-factory.md` sec 5 (D-LP-2, lines 215-217):
  test LPs are "noindex + ZERO internal links + ad-click-only entry." Two internal-navigation links to
  the indexed main site are present.
- **Designers' rationale (fair):** D-LP-2 consciously keeps ONLY `/privacy/` + `/terms/` as a "legal
  necessity on a data-capture page," drops `/rates/` and all cross-LP marketing links.
- **Assessment:** the SPIRIT of isolation holds - the LP is noindex, self-canonical, absent from the
  sitemap, logo NOT linked home (D-LP-1, verified: `<span class="brand">` at line 230, no `<a href="/">`
  wrap), zero inbound links, no cross-LP marketing link. The LETTER ("zero internal links") is broken
  by two outbound legal links to already-indexed pages, which does not make the LP organically
  discoverable. Confirmable, not a ship-stopper.
- **Fix options:** (a) Jarred blesses the legal-links exception and it is documented in the isolation
  checklist so the per-slug grep does not later flag it as a regression; or (b) render privacy/terms as
  same-page collapsible text / unlinked legal snapshots to hold "zero internal links" literally.
  Recommend (a) + an explicit exception note.

---

## LOW-6. Two near-bare dollar ad assets (self-flagged; confirm drop)

- **File:** `design/ad-variants.md`.
- **Line 226:** `Skip the $65 Waitlist Fee (25)  *(pair with a tour-conditioned partner; do not run isolated - see note)*`
- **Line 255:** `$100+ in Fees Waived (20)  *(bare - LP must carry both conditions; policy-lane call)*`
- **Issue:** each names a dollar figure without the waiver condition IN the same string. Google rotates
  RSA assets independently, so either could surface alone, tripping the condition-in-same-asset rule.
- **Status:** already self-flagged (ad-variants line 238-241 recommends DROP for the $65 one; line 518
  lists both as "the 2 near-bare dollar assets"). Not a hidden violation.
- **Fix:** drop both. Conditioned partners already exist ("$65 Fee Waived When You Tour" line 219;
  "Up to $110 in Fees Waived" line 252 pairs with the split-condition descriptions). Confirm at the
  Tier-2 copy gate.

---

## LOW-7. One "free" ad asset in V4 (self-flagged; scrub from destination)

- **File:** `design/ad-variants.md` line 292: `Book a Free Visit Online (24)  *(the one "free" asset; flagged, drop if policy prefers)*`
- **Status:** self-flagged (lp-factory.md T-2 lines 176-180 and policy-compliance.md V4 keep "free" in
  the ad headline per Jarred's verbatim V4 name but scrub it from the LP destination).
- **Fix:** keep at most one "free" ad asset; ensure the `/lp/free-tour/` destination never renders
  "free tour" (already the instruction). Confirm keep-or-reword at the Tier-2 gate.

---

## LOW-8. Em dashes in GROUND research files (design deliverables are clean)

- **Files:** `ground/tours-fees-code.md` (13 em dashes) and `ground/kindred-portal.md` (12 em dashes).
- **Example, tours-fees-code.md line 83:** the header `## 2. FEE FLOW ($65 waitlist fee)` is followed
  by a literal em-dash glyph (U+2014) then a backticked `src/server/index.ts`. (Glyph not reproduced
  here to keep this file dash-clean.)
- **Nature:** all instances are internal research prose / section headers, NOT parent-facing copy,
  email body, ad asset, or LP that ships. No em dash appears in any copy block lifted to a live surface.
- **Rule:** CONTEXT-PACK2 line 59 "NO EM DASHES anywhere." Repo-wide this is a technical breach; as a
  copy-safety matter it is inert.
- **Fix:** if enforced repo-wide, sweep the two ground files (replace each em-dash glyph with ` - ` or `:`). Otherwise
  note them as internal-notes-only and out of scope for shipping copy.

---

## LOW-9. Soft market-demand line in T1 email (watch, not a fabricated claim)

- **File:** `design/email-reserve.md` (T1 body soft-scarcity line).
- **Nature:** a generalized "return-to-office push, demand has jumped, start months filling quickly"
  statement. NOT a dark pattern (no fabricated deadline, no seat-count, no countdown). Defensible only
  while broadly true against the live forecast (Toddler full til Aug, Infant 10-11 open, Preschool 6-9
  open - directionally supportable).
- **Fix (optional):** keep, but never let it drift into a specific-room fullness claim; the "query the
  live forecast, never assert fullness from memory" rule (CLAUDE.md) applies if it gets more specific.

---

## Cross-cutting SEND-GATE (correctly flagged everywhere; not a copy violation)

The $45 enrollment-fee waiver dangled by T3 (`email-tour-nudge.md`), T4 (`email-post-tour.md`), and V3
(`ad-variants.md` / `lp-factory.md`) is NOT automated (7 hardcoded call sites + `docusign.ts:117`, per
`ground/enrollfee-noshow.md`). Advertising it before the `enrollmentFeeDue(row, waiverFlag)` choke
point + a counsel-reviewed `reserve-agreement-v4.ts` clickwrap bump land = the Google "unavailable
offer" exposure. Every relevant design flags this as a HARD SEND-GATE and none proposes sending before
it (email-post-tour.md section 0, email-tour-nudge.md section 0, ad-variants.md sections 2/5, lp-factory.md
T-1). This is a build-sequencing gate, not a copy hard-rule breach: the copy is honest IF the plumbing
exists. Confirmed staged "authored, not cleared to fire." Same logic time-boxes the T4 5PM waiver flag
server-side (email-post-tour.md lines 159-161): the promo is honest only if the backend enforces the
5PM expiry, which is part of this gate.

---

## Attacked and CLEARED (no violation found)

- **Em dashes in shipping deliverables:** 0 across all 12 `design/` files (U+2012/13/14/15 codepoints +
  `&mdash;`/`&#8212;` entities + double-hyphen-as-dash all scanned). Clean. The LP mockup HTML is clean.
- **Children-table writes:** none. `winback-popup.md` line 488 explicitly disclaims writing `children`
  or firing the Solace enroll gate; `data-tracking.md` line 459-460 states every new table is
  worker-owned and never touches `children`; `campaign-grid.md` uses the `/crm-api` direct-tokened lane
  and only SELECTs. The only "children" hits in the corpus are photo `alt` text and room-capacity prose.
- **Solace enroll / approval gate:** never fired. Reserve stays a paid hold + queued admin task;
  `Enrolled` remains a manual Ashley/Jarred step (`measurement-v2.md` line 93, consistent with CLAUDE.md).
- **Non-additive schema:** none. `tour_outcomes` (data-tracking.md lines 142-150) is a new
  `CREATE TABLE IF NOT EXISTS` side table with its own PK; the alternative `attendance`/
  `attendance_marked_at`/`attendance_marked_by` columns (lines 152-157) are additive ADD-only on
  `tour_bookings` (a side table, not `applications`). `applications` is untouched (99/100 D1 cols,
  closed). No rename, reorder, or DROP of any existing column anywhere. `campaign_events`,
  `lifecycle_sends`, `offer_variants`, `tour_waivers` are all additive side tables.
- **Stripe SDK vs httpx:** no design introduces the Stripe SDK or changes the payment transport. The
  only mentions ("skips Stripe", "Stripe skipped", lp-factory.md:50, measurement-v2.md:97) describe the
  front end BYPASSING payment on a waived flow. The "Stripe via httpx" rule governs the standalone
  Python waitlist SERVICE, which none of these designs modify. (`ground/tours-fees-code.md` line 100
  reports the EXISTING TS worker already uses the Stripe SDK over a fetch client, not httpx - a
  pre-existing reality surfaced in ground, not introduced by any design.)
- **Dark patterns in the 5PM T4 promo (`email-post-tour.md`):** PASS. Real dated deadline with
  timezone, full downside disclosure ("the fee applies, tour still counts, place unchanged, no
  penalty", lines 152-153), NO countdown GIF, NO seat-scarcity, NO "hurry/act now/final chance" (line
  154), NO deadline-extension chaser (one send per booking, line 157), server-side time-boxed waiver
  (lines 159-161), and a mandatory anti-coercion deadline-edge guard (rolls to 5PM tomorrow when runway
  is under ~4h, lines 165-177). This is the model for honest urgency.
- **Un-rotated "this week only" in the AD layer:** the ad copy layer is compliant. Evergreen urgency is
  explicitly rejected (`ad-variants.md` lines 378-394: "Default state = NO fake deadline"; the "This
  Week: Tour and Save" asset, line 256, is gated to a time-boxed flight only). The residual trap is in
  the LP HERO copy (MED-4), not the ad assets.
- **CAN-SPAM:** satisfied by construction for T1/T3/T4. All three keep their kinds OUT of
  `TRANSACTIONAL_KINDS` (email-reserve.md section 1, email-tour-nudge.md section 1, email-post-tour.md
  section 0.3), so `sendEmail`'s suppression gate + unsubscribe footer + RFC 8058 `List-Unsubscribe`
  headers auto-fire and the `750 N Street, Sacramento CA 95814` physical address is in the shell footer.
  T3 additionally requires `marketing_consent=1` before sending. No gap. T2 winback is an on-site popup,
  not email, so CAN-SPAM does not apply to it.
- **Brightwheel money ops (`improvements.md` #6 referral credit):** routed through Bw* skills,
  "dry-run -> confirm -> execute -> verify", Tier-2 gated. SMS (#11) is correctly gated on TCPA
  prior-express-written-consent + counsel. No direct-money-op bypass.
- **Dollar figures:** allowed per the 7/11 supersession for these variants. Every "$65/$45/$100+" claim
  in shipping copy carries its condition in the same asset EXCEPT the two self-flagged near-bare assets
  (LOW-6). Rate-card figures ($1,436 / $2,074 / $1,839) appear only in internal analysis
  (ad-variants, measurement-v2, policy-compliance, improvements), never in creative. The "$100+" claim
  is truthfully $110 ($65 + $45); policy-compliance.md line 161 recommends the precise "up to $110"
  over "$100+", which is the safer construction.

---

## Fix checklist (ranked)

1. **[HIGH, Jarred ruling]** Strip `Licensed by California CDSS` from the new-LP `.foot-meta`
   (`lp-open-enrollment-mockup.html:435` + the `lp-factory.md:215` instruction) OR Jarred blesses
   verbatim-footer reuse on new pages. Decide before any LP ships.
2. **[MED]** Reword T2 winback "Book a free tour" -> "Book a tour" (`winback-popup.md:260,262,392` +
   intro line 4); reconcile with `email-tour-nudge.md:62` which already has it right.
3. **[MED]** Reword the V2 LP secondary CTA "Book a free tour" -> "Book a tour" and keep it on-page
   rather than linking `/tour/` (`lp-factory.md:157`).
4. **[MED]** Bind the V3 hero "This week only" kicker + "this week" H1 to the flight gate / `[[EXPIRY]]`
   token, or drop the urgency words and keep only the dated condition-line (`lp-factory.md:161-162`).
5. **[MED, Jarred confirm]** Bless the `/privacy/` + `/terms/` footer-link exception to "zero internal
   links" and document it in the isolation checklist, or convert them to non-internal legal text
   (`lp-open-enrollment-mockup.html:431-432`).
6. **[LOW]** Drop the two near-bare dollar RSA assets (`ad-variants.md:226,255`).
7. **[LOW]** Confirm V4 "free" is ad-headline-only, scrubbed from the LP destination
   (`ad-variants.md:292`).
8. **[LOW]** Sweep em dashes from `ground/tours-fees-code.md` + `ground/kindred-portal.md` if the "no em
   dashes anywhere" rule is enforced repo-wide (internal notes; nothing ships).
9. **[gate, not a fix]** Keep T3/T4/V3 send-gated on the $45 automation + `reserve-agreement-v4`
   clickwrap + server-side 5PM time-box (already flagged in every relevant design).
