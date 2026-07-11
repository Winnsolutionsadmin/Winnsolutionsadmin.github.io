# DESIGN: Policy + Compliance Pass - Lifecycle Funnel + Ad Variant Matrix (2026-07-11)

Lane: POLICY-COMPLIANCE. Scope = everything NEW this turn: dollar figures in ad copy, the "$100+ in
fees waived" math, "this week only" urgency, "Back to School" seasonal, the T1-T4 promotional emails
(CAN-SPAM + CA), the T4 "5PM today" deadline, and the clickwrap implications of the $45 enrollment-fee
waiver. Builds on `2026-07-10-tour-waiver-test/A-policy-compliance.md` (Test A/B verdicts, disclosure
rule, `waitlist-v2.ts` conflict, sources) - that frame is inherited, not repeated. Nothing here
executes anything. No em dashes. No licensing language anywhere.

Verdict vocabulary:
- **CLEAR** = runnable once the standing conditions (condition-in-asset, clickwrap, LP disclosure) are met.
- **CLEAR WITH FIXES** = runnable after the enumerated required fixes land.
- **HOLD** = do NOT put into paid media / do not send until a named blocker is resolved.

---

## 0. Executive verdict table

| Variant / component | Claim as written | Verdict | Top blocker |
|---|---|---|---|
| V1 "OPEN ENROLLMENT!" | $65 waitlist fee waived (tour-gated), branded | CLEAR WITH FIXES | Google editorial caps/"!"; implied-availability; waitlist-v2 clickwrap |
| V2 "Back to School" | seasonal enrollment push | CLEAR WITH FIXES | Must run in-season; any fee claim inherits waiver conditions |
| V3 "$100+ in fees waived this week only! Tour our location for FREE!" | $65+$45 stacked, urgency, free tour | **HOLD** | $45 not automated (unavailable-offer); false urgency; "FREE" editorial; double clickwrap |
| V4 "Free no obligation tour" | tour only, no fee waiver | CLEAR WITH FIXES | "free tour" house-rule reword; "!" editorial |
| V5 "$65 waitlist fee waived!" | $65 waitlist fee waived (tour-gated) | CLEAR WITH FIXES | Condition-in-asset; caps/"!"; waitlist-v2 clickwrap |
| T1 "Reserve Your Space" email | marketing nudge, no fee claim | CLEAR | Keep marketing-kind (suppression-gated); truthful subject |
| T2 reserve-exit winback popup | on-site "book a tour" overlay | CLEAR | On-site UI, not email; route to /tour/; truthful copy |
| T3 "Book a tour and waive your enrollment fee!" email | $45 waiver, tour-gated | **HOLD** | $45 not automated; reserve-agreement-v4 clickwrap; condition line |
| T4 "reserve by 5PM today, waive the $45" email | $45 waiver, same-day deadline | **HOLD** | $45 not automated; deadline must be enforced; clickwrap |

Two blockers dominate and are the single inquiry for Jarred (section 10): **(A) the $45 enrollment-fee
waiver is not automated** (manual Brightwheel, no `enrollmentFeeDue` choke point - `enrollfee-noshow.md`
Part A), so V3/T3/T4 advertise an offer the system cannot reliably honor; and **(B) every fee-deferring
variant needs a counsel-reviewed clickwrap version bump** before launch.

---

## 1. Dollars in ad copy: what Google still requires (the 7/2 rule is lifted, not the law)

Jarred's 7/11 supersession lets dollar figures into ad copy for these tests. That removes an INTERNAL
rule; it does not remove Google's or the FTC's. Four Google policies still bind every dollar claim:

1. **Dishonest Pricing Practices (effective Oct 28, 2025).** All pricing a user will bear must be
   available at the destination. A "$65 waived" or "$100+ waived" ad may NOT point to an LP that hides
   the real numbers. **Required:** every LP that makes a dollar-savings claim carries a pricing-transparency
   line stating the real fee amounts ($65 one-time waitlist application fee, $45 one-time enrollment fee)
   AND that monthly tuition is separate (link to `/rates/`). The savings claim cannot be the only price
   information on the page. This INVERTS the naive "no $65" reading: the $65 must appear on the LP.
2. **Unreliable Claims / Misrepresentation.** A waived-fee claim must be a real, currently-available
   offer with its condition clear. A conditional waiver advertised as if unconditional is the textbook
   violation shape (this WAS the `/state-employees/` "no application fee" bug; verified fixed in the live
   tree 2026-07-11, D7 - see section 11. Cited here as the pattern the new variants must not recreate).
3. **Unavailable Offers.** Do not advertise an offer families cannot actually get from the destination.
   This is the load-bearing reason V3/T3/T4 are on HOLD: the $45 waiver has no automation and no verified
   SOP, so a family who does everything right may still be charged $45 by the manual Brightwheel process.
   One such family = a live Google Misrepresentation complaint on the account carrying the primary
   `gmwl_fee_paid_confirmed` conversion. Do not accept that risk for a test.
4. **Editorial (caps + punctuation) - a concrete auto-disapproval, verified current 2026-07-11.** Google
   disapproves excessive capitalization (the word "FREE" is Google's own cited example) and gimmicky /
   repeated punctuation (headlines ending in "!" , "!!!"). Brand/product-name caps are allowed ONLY via a
   manual review request. **Every variant string as written trips this:** "OPEN ENROLLMENT!", "...for
   FREE!", "$65 waitlist fee waived!". **Required fix (all variants):** in the AD CREATIVE use sentence
   or title case, no all-caps words except acronyms, and drop the exclamation points from the claim.
   "OPEN ENROLLMENT" / "FREE" stay as INTERNAL campaign labels only; the rendered headline reads
   "Open Enrollment" / "book a tour" / "$65 waitlist fee waived when you tour". Do not rely on a caps
   review-request for a generic phrase; it will not clear.

Standing disclosure rule (inherited, NOT waived by the dollar supersession): the waiver CONDITION must
sit in the SAME asset as the claim. "$65 waitlist fee waived when you complete a tour" is compliant;
"$65 fee waived" as an isolated headline is not.

---

## 2. Per-variant verdict + required fixes

### V1 "OPEN ENROLLMENT!" (the $65-waived / tour-waiver campaign, public brand name)
**Verdict: CLEAR WITH FIXES.** Mechanically this is Test A (COMPLIANT WITH CONDITIONS) rebranded, so it
inherits Test A's whole compliant frame. Two NEW risks from the brand name:
- **Implied availability.** "Open Enrollment" reads like health-insurance / school open-enrollment: seats
  are open now, enroll immediately, or a defined window is closing. Reality is a WAITLIST with constrained
  capacity (Toddler full til Aug per CONTEXT-PACK2). Advertising "open enrollment" while the honest state
  is "join the waitlist" is a Misrepresentation surface. **Required fix:** the LP and ad must frame it as
  "join the waitlist, application fee waived when you tour," never "enroll now" or "seats open." Add a
  truthful availability line ("Openings vary by room; joining the waitlist holds your place in line").
- **Implied enrollment WINDOW.** If "open enrollment" implies a limited period, that period must be real
  (same rule as "this week only", section 4). If the campaign runs continuously, drop any "window closing"
  language.
Required fixes: (1) editorial - "Open Enrollment", no "!"; (2) condition-in-asset ("...fee waived when
you complete a tour"); (3) LP pricing-transparency line (section 1.1); (4) `waitlist-v2.ts` clickwrap
(section 8); (5) noindex + zero internal links + `?offer=` isolation (inherited).

### V2 "Back to School"
**Verdict: CLEAR WITH FIXES.** The theme itself is low legal risk. Concerns:
- **Seasonality truthfulness.** "Back to School" is a real season (roughly late July through September).
  Running it in, say, February would be an odd but not strictly deceptive theme UNLESS it implies a
  time-limited back-to-school offer that isn't. **Required fix:** run the seasonal creative in-season; if
  it carries any "before school starts" urgency, that framing must align with the actual season and any
  stated deadline must be real (section 4).
- **Category-fit honesty.** Infants/toddlers are not literally "going back to school." Keep claims
  truthful: this is an enrollment season, not a claim that a child returns to school. Avoid copy that
  implies a school-calendar guarantee (start dates, class placement) the program does not promise.
- **Any fee claim inherits everything.** If V2 pairs with a fee waiver, all of section 1 + the
  condition-in-asset rule + clickwrap apply. If V2 is a pure brand/enrollment push with no dollar claim,
  it only needs editorial (no "!") + the standard LP posture.

### V3 "$100+ in fees waived this week only! Tour our location for FREE!"
**Verdict: HOLD.** Highest-risk variant; four distinct violations stacked in one line:
1. **$45 half is an unavailable offer.** "$100+" = $65 waitlist + $45 enrollment. The $45 waiver is not
   automated (7 call sites, manual Brightwheel, no choke point - `enrollfee-noshow.md` A2/A4). Advertising
   it before automation or a verified airtight SOP exists is the Unavailable-Offers / Misrepresentation
   violation. This is the same D9 / Test-B gate the source package flagged, now reopened by V3.
2. **False urgency.** "this week only" must genuinely expire and the offer must genuinely be unavailable
   outside the window (section 4). Evergreen = deceptive under FTC Section 5 (verified: a "limited" offer
   that is always available is deceptive, no intent required).
3. **"Tour our location for FREE!"** trips both the house "no free tour" rule (tours never carried a
   price, so "free" manufactures a second false-ish free claim) AND Google editorial ("FREE" caps + "!").
4. **Two differently-conditioned waivers bundled in one number.** The $65 is tour-gated; the $45 is
   same-day-reserve-gated. A single "$100+ waived" claim hides that these have different conditions.
**Required fixes to make V3 runnable (all must land):** (a) build the $45 automation (`enrollmentFeeDue`
choke point through all 7 sites + docusign) OR a verified, logged, airtight manual SOP; (b) real rotation
calendar (section 4); (c) reword "free tour" -> "tour our Sacramento location"; strip caps/"!"; (d) state
BOTH conditions in the same asset and on the LP; (e) `reserve-agreement-v4.ts` clickwrap (section 8);
(f) LP pricing-transparency line. **Recommendation:** descope V3 to $65-only for the first test window
(making it a V5 twin with urgency), and hold the "$100+" stacked claim for a phase-2 flight AFTER the $45
plumbing ships. Do not let V3 launch on the current manual $45 process.

### V4 "Free no obligation tour"
**Verdict: CLEAR WITH FIXES (safest variant legally).** A genuinely free, no-obligation tour is TRUTHFUL
- there is no purchase requirement, so it is not an FTC "free" (16 CFR 251) violation. Two fixes only:
- **House-rule reword.** "free tour" still trips the internal precision rule and Google editorial ("Free"
  leading + "!"). **Required:** "Book a tour, no obligation" / "Tour us, no strings." Keep "no obligation"
  (a true, meaningful differentiator: touring does not commit the family to enroll or pay). Drop "Free"
  and the "!".
- **No hidden hook.** Because V4 makes no fee-waiver claim, do NOT let the LP or overlay imply a waiver
  the ad didn't promise. V4 is the clean control: tour intent, no dollar claim, no clickwrap change.

### V5 "$65 waitlist fee waived!"
**Verdict: CLEAR WITH FIXES.** This is V1's mechanic with the explicit dollar (now allowed). Fixes:
- **Condition-in-asset (non-negotiable).** "$65 waitlist fee waived" alone is a bare conditional claim.
  Render "$65 waitlist fee waived when you complete a tour."
- **Editorial.** Drop the "!"; "$65" is fine (numerals are not "excessive capitalization").
- **LP discloses $65** in the condition/fine-print (Dishonest Pricing Practices) - it already is the
  waived amount, state it once with the tour condition and the fallback (fee applies if no tour in N days).
- **`waitlist-v2.ts` clickwrap** (section 8).

---

## 3. The "$100+ in fees waived" claim math (V3 / T3 / T4)

$65 (one-time waitlist application fee) + $45 (one-time enrollment fee) = **$110**. "$100+" is
arithmetically truthful ONLY if BOTH are actually waived under their stated conditions. Compliance
requirements if the "$100+" claim is ever used:
- **Both waivers must be real and available** (kills V3/T3/T4 today on the $45 automation gap).
- **Both conditions disclosed in the same asset / LP:** "waitlist application fee waived when you complete
  a tour; enrollment fee waived when you reserve your space same-day." A reader must be able to see that
  the two halves are earned differently.
- **No tuition confusion.** "$100+ in fees waived" must not read as "$100+ off your cost of care." These
  are one-time fees, not tuition. The LP pricing-transparency line must make clear tuition is separate and
  unchanged (this is exactly the state-employees contradiction class - a waiver must not read as a
  backdoor tuition discount or tier change).
- **Exact wording:** prefer "up to $110 in one-time fees waived" over "$100+", because "$110" is precise
  and "$100+" invites the question of what else is included. If Jarred prefers "$100+", it is defensible
  at $110, but the precise figure is the safer construction.

---

## 4. "this week only" urgency: the honest rotation calendar

FTC test (verified current): a time-limited claim is deceptive if the offer is actually always available,
if the window resets when the user returns, or if the "limited" thing never runs out. Section 5, no proof
of intent required. So "this week only" is compliant ONLY if the offer genuinely turns off and is genuinely
unavailable outside the stated window. Two honest ways to run it:

**Preferred: concrete dated expiry, run in discrete flights with real gaps.** Replace the vague "this week
only" with a real end date the system enforces, and run the offer in bounded flights separated by genuine
OFF gaps (the gap is what makes "only" true - an offer that returns every week with no gap is functionally
always-on and the "only" is a lie).

All three surfaces move together per flight:
- **Google Ads:** each flight's creative has a hard start/end (ad-schedule end date); at flight end the ad
  is PAUSED (never-drop = pause, not delete), logged in the change-log.
- **LP `.condition-line`:** shows the flight's real end ("Offer ends Sunday, [Month D], 11:59 PM Pacific").
  Between flights the ad is paused so no paid traffic reaches a stale claim.
- **Backend:** the `?offer=` waiver code is honored ONLY during the flight window (a D1 config row / date
  gate). A family arriving after expiry does not get the waiver, which keeps the claim truthful end-to-end.

**Concrete calendar (6-week test window, launch ~7/16 batch; adjust dates to the real launch):**
| Flight | Live window (PT) | LP expiry stamp | Pause | Gap after |
|---|---|---|---|---|
| A | Mon Jul 20 - Sun Jul 26 | "Offer ends Sun Jul 26, 11:59 PM PT" | Jul 27 | Jul 27 - Aug 2 (offer OFF) |
| B | Mon Aug 3 - Sun Aug 9 | "Offer ends Sun Aug 9, 11:59 PM PT" | Aug 10 | Aug 10 - Aug 16 (offer OFF) |
| C | Mon Aug 17 - Sun Aug 23 | "Offer ends Sun Aug 23, 11:59 PM PT" | Aug 24 | evaluate at ~100 sessions / 6 wks |

Each flight is a genuinely distinct, bounded availability window with a real gap between, so "this week
only" is literally true for the week it runs and the offer is not always available. **Alternative if
Jarred wants continuous running:** drop the urgency language entirely and state availability plainly
("Waitlist application fee waived when you tour"). You cannot have both continuous running AND a
"this week only" claim - pick one.

---

## 5. "Back to School" seasonal claims

Covered in V2 (section 2). Legal summary: a seasonal THEME is not a deceptive claim by itself. It becomes
one only if (a) it is used off-season in a way that implies a current season, or (b) it carries a
"before school starts / limited back-to-school offer" urgency that is not real. Keep it in-season
(late July - September), keep any deadline real (section 4 mechanism), and do not imply a school-calendar
placement guarantee the infant-through-preschool program does not make. No dollar claim in V2 = no clickwrap
change; a dollar claim in V2 = inherits sections 1, 3, 8.

---

## 6. The T4 "reserve by 5PM TODAY" deadline: pressure-tactics analysis

The T4 email says "reserve your space by 5PM TODAY and we waive the $45 enrollment fee." This is a same-day
deadline aimed at a $1,436-$2,074/mo, multi-year childcare decision. Analysis:

- **It CAN be honest, because it is per-family.** T4 fires 1h after THIS family's own tour ends. "Reserve
  by 5PM today" is a genuine per-recipient deadline, not a broadcast fake countdown - so it is not the
  "timer that resets for everyone" dark pattern the FTC targets, PROVIDED the backend actually enforces it.
- **Enforcement is the compliance condition.** The $45 waiver must genuinely expire at 5:00 PM Pacific the
  day of the tour. If the family reserves at 5:01 PM and the system still waives the $45, the deadline is
  fake and the claim is deceptive under FTC Section 5. **Required:** the `enrollmentFeeDue` logic must key
  the waiver to a real cutoff (tour date, 5:00 PM PT) and charge the standard $45 after it. If the system
  cannot enforce a same-day cutoff, do not make a same-day-deadline claim - use "reserve within [N] days"
  tied to the real waiver window instead.
- **No re-sent / resetting deadline.** T4 must be idempotent per booking (one send, one deadline). Do NOT
  send a fresh "5PM today" the next day with a new date - that is a resetting countdown, the exact FTC
  target. The `tour_followups` idempotency row (per `enrollfee-noshow.md` Part B) enforces this.
- **Brand-tone flag (not a legal blocker, a Jarred call).** A same-day high-pressure close sits in tension
  with a mindfulness brand. This is defensible if truthful and enforced, but it is a parent-facing tone
  decision for Jarred, not something compliance resolves. Softer-but-still-real alternative: "Reserve by
  Friday and we waive the $45" (a 2-3 day real window) reads less high-pressure while staying honest.

---

## 7. Promotional email law: CAN-SPAM + California (T1, T3, T4)

T1 / T3 / T4 are commercial (marketing) emails to waitlist applicants. T2 is an on-site popup, not email,
so CAN-SPAM does not reach it (it must still be truthful and route to `/tour/`). The good news from
`email-infra.md`: the mechanical CAN-SPAM controls are ALREADY wired. The requirement is to keep them on
and classify these kinds as marketing (not transactional), so the allowlist suppression gate covers them.

**CAN-SPAM requirements, each mapped to existing state:**
1. **Working unsubscribe + honor it promptly.** DONE: footer `Unsubscribe` link + RFC 8058 one-click
   `List-Unsubscribe` / `List-Unsubscribe-Post` headers; `email_suppressions` blocks future marketing sends
   immediately (well inside CAN-SPAM's 10-business-day requirement). Requirement: T1/T3/T4 must be MARKETING
   kinds so the gate applies. Do NOT add them to `TRANSACTIONAL_KINDS`.
2. **Physical postal address.** DONE: `Growing Mindfully · enrollment@growingmindfully.org · 750 N Street,
   Sacramento CA 95814` in the shell footer. Keep it in every marketing send.
3. **No deceptive subject lines or headers.** From `hello@growingmindfully.org` (real, Postmark-verified
   domain); subjects sanitized by `safeSubject()`. Requirement: subjects must be truthful. "Reserve your
   space" and "Book a tour and waive your enrollment fee" are fine (they describe the content). Do NOT use
   a subject implying a state that is false ("Your reservation is confirmed", "Re: your enrollment") on a
   promotional send.
4. **Identify as an advertisement.** These go to a first-party audience (families who entered their email
   in the waitlist flow, `leads.marketing_consent=1`). Ad-identification is satisfied by that context plus
   the "you joined the waitlist" line in the footer block (section 9). No magic words required, but the
   footer's origin line carries it.
5. **Don't email harvested/suppressed addresses.** DONE: allowlist gate + suppression on bounce/complaint
   via the Postmark/Resend webhooks.

**Unsubscribe scope (important, and already correct in the plumbing):** unsubscribing from marketing must
NOT stop transactional mail. The gate already delivers transactional kinds (receipts, verification, tour
confirmation, reserve-abandon) to suppressed addresses. The footer copy must say so (section 9) so a family
who opts out of promos still knows they will get their own service messages.

**California specifics:**
- **Cal. Bus. & Prof. Code 17529.5** (CA anti-spam, $1,000-per-email statutory exposure) prohibits
  falsified/misrepresented header information, misleading subject lines, and third-party-relayed sends
  without permission. Satisfied here: truthful headers, real first-party domain, truthful subjects,
  first-party sends. This is why the section-7.3 subject-line honesty rule is not optional in CA.
- **CalOPPA / privacy link.** Keep the `/privacy/` link reachable (the site footer has it; the email footer
  should link it too). CCPA/CPRA are privacy, not email-content, obligations - out of scope for the send
  itself but the privacy policy must remain accurate about marketing email use.
- **CA quiet-hours / consent:** no CA statute imposes email quiet hours (that is SMS/TCPA territory). The
  existing 72h winback quiet-window is a deliverability/courtesy control, not a legal one - keep it to avoid
  colliding sends, but it is not a compliance requirement.

**Suppression / frequency hygiene (design requirement):** T1/T3/T4 plus the existing winback A1/A2/C plus
manual campaigns can stack on one family. A family who unsubscribes must drop out of ALL marketing legs at
once (the suppression list already does this globally - verify the lifecycle sweep checks it before every
send, same as `winback.ts`). Cap promotional frequency per family so the lifecycle + winback + campaigns do
not exceed a reasonable cadence (recommend no more than ~2 marketing emails / family / week across all legs).

---

## 8. Clickwrap implications of the fee waivers

Two SEPARATE clickwrap surfaces are implicated, one per fee. Both are Tier-2, counsel-reviewed, SHA-256
version-bumped, and BLOCK the launch of the variant that touches them.

**8a. $65 waitlist fee waiver (V1, V5) -> `waitlist-v2.ts` required.**
Inherited from A-lane: `waitlist-v1.ts` states the $65 is "non-refundable... regardless" and is shown
"upon payment." The tour-waiver mechanic defers the fee and may remove the payment event entirely for a
family who completes a tour. v1 does not describe a deferred conditional fee at all; reusing v1's hash for
a materially different mechanic breaks the file's own byte-for-byte-enforceability invariant. Required:
`waitlist-v2.ts` adding a paragraph describing the tour-waiver condition, the deadline (N days), and the
fallback (standard $65 applies if the tour is not completed). v1 was "COUNSEL-READY" - a fee-mechanic
change is not a copyedit; route v2 back through the same counsel review, not a rubber stamp.

**8b. $45 enrollment fee waiver (V3, T3, T4) -> `reserve-agreement-v4.ts` + choke-point required.**
This is a DIFFERENT set of documents from the $65 clickwrap. Per `enrollfee-noshow.md` A3/A4, the $45 is
named as non-refundable in: the reserve overlay `ack-prepayment` clickwrap (`overlay.js`), the rendered
reserve agreement (`agreement-template.ts`), the hashed reserve-agreement terms (`reserve-agreement-v1/v2/
v3.ts`), the DocuSign quote object (`docusign.ts:117`, hardcoded `45`), and the portal quote card. A T4
"$45 waived" that changes the charged amount but NOT these documents makes a family sign an agreement
stating a $45 fee they were not charged - a terms/charge mismatch. Required before V3/T3/T4:
1. `reserve-agreement-v4.ts` (copy-on-change, counsel + Jarred) describing the conditional enrollment-fee
   waiver, its condition (same-day reserve after a completed tour), and the deadline (the 5PM cutoff).
2. The single `enrollmentFeeDue(row, waiverFlag)` choke point routed through all 7 money/display sites
   (incl. the hardcoded `docusign.ts:117`) so a waived family's charge, quote, refund math, abandon email,
   and agreement all reflect $0 consistently.
3. The waiver flag is side-table state (a `tour_completions` / waiver row keyed by `application_id`), never
   a new `applications` column (table closed at 99/100).

**Hard sequencing rule (both fees):** the promo email or ad may not go live before ALL of {backend waiver
mechanic, LP disclosure, updated clickwrap} are simultaneously live in production. Advertising the mechanic
before it exists is Google's Unavailable-Offers violation and the FTC/CA equivalent. This is why T3/T4 and
V3 are HOLD, not CLEAR: the copy can be built and staged now, but must not SEND until 8b lands.

---

## 9. Email-footer legal block (the deliverable)

The existing `sendEmail` shell already carries the physical address and appends an unsubscribe line. For
the marketing lifecycle emails (T1, T3, T4), the footer must contain, at minimum, the block below. It is
CAN-SPAM + CA 17529.5 compliant, states the sending relationship (ad-identification by context), scopes the
opt-out to marketing while preserving transactional mail, and uses team voice with no em dashes.

**Marketing-email legal footer (muted small print, appended below the shell leaf-mark line):**

```
You are receiving this because you joined the Growing Mindfully waitlist and shared your email with us.
Growing Mindfully, 750 N Street, Sacramento, CA 95814.
Prefer not to receive emails like this? Unsubscribe with one click. You will still receive service
messages about your own application, such as payment receipts, tour confirmations, and reservation details.
Privacy policy: https://www.growingmindfully.org/privacy/
```

Notes: keep the one-click `Unsubscribe` wired to the existing `List-Unsubscribe` token; the second sentence
is the physical address (required); the third sentence is the opt-out + the transactional-still-delivers
clarification; the privacy link satisfies CalOPPA. Do NOT sign the legal footer "Jarred" - the body sign-off
stays "With love, The Growing Mindfully team."

**Inline offer-condition lines (in the email BODY, next to the CTA - these are the substantive disclosure,
the footer does not carry the offer terms):**

- **T1 "Reserve Your Space"** (no fee claim): no offer-condition line needed. Keep the subject and body
  truthful; it is a nurture nudge, not a discount claim.

- **T3 "Book a tour and waive your enrollment fee"** (only after 8b ships):
```
Complete an in-person tour and we waive your one-time $45 enrollment fee when you reserve your space.
This applies only to the one-time enrollment fee. Monthly tuition and your rate tier do not change.
Full terms: https://www.growingmindfully.org/terms/
```

- **T4 "Reserve by 5PM today, waive the $45"** (only after 8b ships AND the 5PM cutoff is enforced):
```
Reserve your space by 5:00 PM Pacific today, [Weekday, Month D]. Reservations completed by that time have
the one-time $45 enrollment fee waived. After that time the standard $45 one-time enrollment fee applies.
This waiver applies only to the enrollment fee and does not change your monthly tuition or rate tier.
Full terms: https://www.growingmindfully.org/terms/
```

The T4 date is filled from the family's own tour date at send time (America/Los_Angeles). Every "$45" in
these bodies must match what `enrollmentFeeDue` actually charges - if the code cannot yet waive it, the
email cannot yet claim it.

---

## 10. Single inquiry for Jarred (the decisions only he can make)

Numbered, one line each, per HOOTL single-inquiry rule. Everything else in this doc is a build instruction,
not a question.

1. **$45 automation gate (blocks V3, T3, T4).** Build the `enrollmentFeeDue` choke point + `reserve-
   agreement-v4.ts` BEFORE advertising any $45 waiver, or descope V3 to $65-only and hold T3/T4? (Compliance
   recommends: descope now, ship the $45 stack in a phase-2 flight after the plumbing lands.)
2. **`waitlist-v2.ts` clickwrap** (blocks V1, V5): approve routing the deferred-conditional-fee language
   through the same counsel review v1 took. Tier-2, parent-binding.
3. **`reserve-agreement-v4.ts` clickwrap** (blocks V3/T3/T4): approve the conditional $45-waiver terms
   version. Tier-2, parent-binding.
4. **T4 same-day-deadline enforcement + tone:** confirm the $45 waiver truly expires at 5:00 PM PT (so the
   claim is honest), and confirm the same-day-pressure tone fits the brand, or switch to a softer real
   window ("by Friday").
5. **"$100+" vs "up to $110":** which phrasing for the stacked claim, if V3 runs at all. (Compliance
   recommends the precise "$110".)
6. **Urgency posture:** approve the flighted rotation calendar (section 4) for any "this week only" claim,
   or drop urgency language for continuous running. Cannot have both.
7. **Parent-facing copy sign-off** (Tier-2): all variant ad creative, LP copy, and T1/T3/T4 email bodies.
8. **Local-actions conversion pollution** (carried from live state): demote the 3 GBP Local-actions PRIMARY
   conversions so the lifecycle read is clean - not strictly compliance, flagged because it distorts the
   truthfulness of any performance claim made from the account.

---

## 11. Fixes that ship regardless (not gated on a decision)
- **`/state-employees/` "no application fee" bug (D7): VERIFIED ALREADY FIXED in the live tree
  2026-07-11 - drop it from the launch dependency list.** A-lane cited 4 unconditional "no application
  fee" instances at lines 98/104/335/359. Ground-truth grep of the current worktree (`resale-distance`)
  finds ZERO "no application fee" occurrences in either page: root `state-employees/index.html` (now 464
  lines, was 359 when A-lane read it) and the paid LP `lp/state-employees/index.html` (359 lines). The
  live LP now conditions the fee correctly ("a one-time $65 waitlist fee holds your family's place in
  line", lines 193 + 321). So the D7 companion fix that A-lane and section 0 assumed is NO LONGER a
  blocker; the waiver LPs do not need to wait on it. Two residual copy watch-items (soft, not blockers):
    - Root `state-employees/index.html:282` FAQ answer reads "...We talk schedule, age band, and a tour.
      No fees yet." Truthful in context (no fee at the inquiry stage; the $65 lands at application), but
      confirm it does not read as "no fees ever" given the $65-mandatory policy. One-word safety: "No
      fees to start." Low priority.
    - The LIVE paid LP `lp/state-employees/index.html:192,323` already ships "Book a free tour" - the
      exact "free tour" phrasing section 2/V4 flags. It is not a legal violation there (no adjacent
      fee-waiver "free" claim to create double-free confusion; tours genuinely cost nothing), but IF
      Jarred adopts the "free tour" -> "no obligation" reword for the variants, apply it here too for
      consistency. Not a launch blocker.
- **Per-variant isolation grep:** before each deploy, confirm each `lp/<slug>/` is noindex, absent from
  `sitemap.xml`, and has zero internal links; confirm the `?offer=` code is the only waiver entry path.
- **Editorial scrub:** no all-caps words (except acronyms), no gimmicky/repeated punctuation, in any
  rendered ad asset across all variants.
- **No em dashes, no new licensing text** anywhere in the new copy (LPs keep the existing CDSS badge, add
  nothing).

---

## 12. Sources (current as of 2026-07-11)
- Google Ads Editorial policy (caps/punctuation home): https://support.google.com/adspolicy/answer/6021546?hl=en
- Google Ads Punctuation and symbols: https://support.google.com/adspolicy/answer/14847994?hl=en
- Google Ads Capitalization ("FREE" example): https://support.google.com/adspolicy/answer/14848295?hl=en
- Google Ads Dishonest Pricing Practices (eff Oct 28, 2025): https://support.google.com/adspolicy/answer/15938375?hl=en
- Google Ads Unreliable Claims: https://support.google.com/adspolicy/answer/15936857?hl=en
- Google Ads Unavailable Offers: https://support.google.com/adspolicy/answer/15937063?hl=en
- Google Ads Misrepresentation (overview): https://support.google.com/adspolicy/answer/6020955?hl=en
- FTC, Bringing Dark Patterns to Light (2022 report, false-urgency test): https://www.ftc.gov/reports/bringing-dark-patterns-light
- FTC/ICPEN/GPEN dark-patterns review (Jul 2024, urgency category): https://www.ftc.gov/news-events/news/press-releases/2024/07/ftc-icpen-gpen-announce-results-review-use-dark-patterns-affecting-subscription-services-privacy
- FTC Guide Concerning Use of the Word "Free", 16 CFR 251: https://www.ftc.gov/legal-library/browse/rules/guide-concerning-use-word-free-similar-representations
- CAN-SPAM Act compliance guide (FTC): https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business
- California Bus. & Prof. Code 17529.5 (CA anti-spam): https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=17529.5.&lawCode=BPC
- California Bus. & Prof. Code 17500 (false advertising): https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=17500.&lawCode=BPC

## Files read for this pass
- `2026-07-11-lifecycle-funnel/CONTEXT-PACK2.md`, `ground/waiver-package.md`, `ground/email-infra.md`,
  `ground/enrollfee-noshow.md`, `ground/site-lp-conventions.md`
- `2026-07-10-tour-waiver-test/A-policy-compliance.md`
