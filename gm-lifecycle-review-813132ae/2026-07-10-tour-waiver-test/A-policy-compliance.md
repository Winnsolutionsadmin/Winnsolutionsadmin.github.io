# A. Policy and Compliance - Tour Waiver Test (2026-07-10)

Lane: POLICY-COMPLIANCE. Read CONTEXT-PACK.md in full before this file. Nothing here executes
anything; these are drafts and a gate list for Jarred and the other four lanes.

## 1. Verdicts

### Test A: waitlist application fee waived, conditional on completing a booked tour
**Verdict: COMPLIANT WITH CONDITIONS.** Runnable on Google Ads once the five conditions in
section 4a below are met. The core mechanic (conditional free offer, condition disclosed
clearly and at the outset) is a well-understood, lawful ad pattern under both Google Ads policy
and FTC/CA free-offer law. The risk is not the offer type, it is sequencing: the ad claim must
not go live before the backend mechanic, the LP disclosure, and the updated clickwrap terms are
all actually live and matching what the ad says.

### Test B: $45 enrollment fee waived for same-day enrollment
**Verdict: COMPLIANT WITH CONDITIONS, NOT READY TO ADVERTISE YET.** The offer concept is lawful
on the same reasoning as Test A. It is currently a design-stage idea sitting on a manual,
external process (Brightwheel, human-triggered). Advertising it before the waiver is either
system-automated or backed by an airtight manual SOP creates real "unavailable offer" /
misrepresentation exposure: if even one family who saw the ad does not get the fee waived
same-day because a human missed a step, that is a live complaint and a Google policy violation
on the account that is currently carrying the primary Test A campaign. Recommend: do not put
Test B into paid media. Keep it internal-only (referral/tour-day script, no ad spend) until the
automation or a verified SOP exists.

## 2. Required disclosure language (draft)

### 2a. Minimum condition that must live IN THE AD ITSELF (not just the landing page)
FTC's "clearly and conspicuously... at the outset of the offer" standard (16 CFR 251.1(c)) and
Google's "unclear relevance" / "unreliable claims" policies both push toward the same rule: the
condition cannot be disclosed only on the landing page if the ad makes the "free/waived" claim
on its own. So every ad asset that says "waived" or "fee" must carry the condition in the SAME
asset, not a separate disconnected headline. Minimum compliant construction:

> "...fee waived when you complete a tour"
> "...fee waived, tour required"
> "...waived with a completed tour visit"

Never run an isolated headline that just says "Fee Waived" or "No Application Fee" without the
tour condition in the same string. That isolated-claim pattern is exactly what created the
existing `/state-employees/` "No application fee" bug (see section 4, item 5) and is also the
textbook Google "unreliable claims" / FTC free-offer violation shape.

### 2b. Full landing page disclosure block (draft, to sit above the fold, near the offer)

> **Tour Waiver Offer.** Book and complete an in-person tour at Growing Mindfully and we waive
> your one-time waitlist application fee. The waiver applies only when the tour is completed.
> If you submit a waitlist application but do not complete a scheduled tour within [N] days of
> applying, the standard application fee applies and is charged before your application moves
> onto the priority waitlist. This offer does not change your waitlist priority tier, your
> tuition rate, or any other enrollment term. Standard one-time waitlist application fee: $65,
> non-refundable once charged. Full terms: [link to Waitlist Terms].

Notes on this draft:
- The $65 figure belongs HERE, on the landing page, not in ad copy. The internal
  no-dollar-amount rule (CONTEXT-PACK line 19) is scoped to ad copy. Google's Dishonest Pricing
  Practices update (effective Oct 28, 2025) requires "all pricing information [be] available to
  users before using your service" and the "full expense a user will bear" be disclosed on the
  destination. Omitting the actual number from the LP entirely, on top of omitting it from the
  ad, would itself be a policy violation, not extra caution. Keep it off the ad, put it on the LP.
- [N] days must be a real, decided number before this ships. Do not leave it vague ("soon," "in
  time") - vague deadlines are the kind of ambiguity 251.1(c) is written against.
- The sentence "does not change your waitlist priority tier, your tuition rate, or any other
  enrollment term" exists specifically to head off a new instance of the state-employees
  contradiction bug: this test must not read as if the fee waiver is a backdoor discount or
  changes tier eligibility.

### 2c. Draft disclosure block for Test B (kept ready, not for use until unblocked)

> **Same-Day Enrollment Fee Waiver.** Families who complete enrollment paperwork the same
> calendar day as their scheduled tour have their one-time $45 enrollment fee waived. Enrollment
> completed on a later date is charged the standard $45 one-time enrollment fee on the first
> Brightwheel invoice. This applies only to the one-time enrollment fee. It does not affect
> monthly tuition, rate tier, or the sibling discount policy.

## 3. Recommended ad copy phrasings (no dollar amount, policy-clean)

Directional only, final character-count polish belongs to the copy-writer lane. Google RSA
limits: headlines ~30 chars, descriptions ~90 chars. Every line below keeps the condition in the
same string as the claim.

Headlines:
- "Book a Tour, Fee Waived" (24)
- "Tour Us, Waive Your Fee" (23)
- "Complete a Tour, Save Today" (28)
- "See Our Rooms, Skip a Fee" (25)
- "Application Fee Waived w/ Tour" (30, tight - confirm exact count in the ad editor)

Descriptions:
- "Book a tour of our Sacramento campus. Complete it and we waive your waitlist application fee." (~95, trim to fit)
- "Infant through preschool, downtown Sacramento. Tour with us and your application fee is waived."
- "Real availability, real tour times. Complete your visit and skip the application fee."

One precision note for the copy lane: avoid the phrase "free tour." Tours have never carried a
price, so calling the tour itself "free" implies a price existed and manufactures a second,
unnecessary "free" claim sitting next to the real one (the fee waiver). It muddies which thing is
actually being waived and adds a claim surface with no upside. Say "book a tour" / "complete a
tour," not "free tour."

### On Promotion assets / Price assets (research item 2)
Recommend NOT using a Google Ads Promotion asset for Test A. Promotion assets are built around a
monetary or percentage discount number that Google renders directly in the ad surface ("$10 off,"
"20% off"), which would force a dollar figure into ad-level creative and break the internal
no-$65-in-ad-copy rule at the platform-rendering level, not just in our own copy. The redemption
mechanic here (must complete a booked tour, not a code or spend threshold) also does not map
cleanly to the asset's "special code or spending limit" redemption field. Keep the waiver as
message-only copy in headlines/descriptions/sitelinks pointing to the dedicated LP, where the
full, precise disclosure lives under our control. This also sidesteps the occasion-asset
6-month eligibility window and the "occasion assets are preferred over non-occasion assets"
serving quirk, neither of which fits an ongoing (non-seasonal) offer.

## 4. Internal rules alignment matrix

| Internal rule | Status under Test A | Notes |
|---|---|---|
| No $65 in ad copy (CONTEXT-PACK line 19) | HOLDS, compliant | $65 stays off every ad asset. It is required to appear on the LP per Google's Dishonest Pricing Practices policy (section 2b). Scope the rule explicitly to ad copy in any brief handed to the copy lane so nobody over-applies it to the LP and creates a policy gap. |
| Never anything licensing-related in ads or site (permanent hard rule) | Not implicated, must stay clean | No licensing language belongs in the waiver LP copy or ad copy. Flag as a check item for whoever drafts the actual LP: confirm no "Lic. #" / CDSS citation creeps into the new page. |
| Waitlist-first CTAs / "tours only fallback" standing posture | SUPERSEDED, Jarred-directed | CONTEXT-PACK explicitly logs this as a decision Jarred is overriding today (line 16). Test A makes tour-booking the primary CTA on its dedicated LP. Recommend confining this to the one dedicated, noindexed LP and this one campaign; do not let the tour-first framing bleed into the existing waitlist-first LPs, which should keep their current CTA hierarchy. |
| Clickwrap terms versioning (Tier 2 gate, waitlist-v1.ts) | CONFLICT FOUND, blocking until resolved | `waitlist-v1.ts` (`~/Projects/gm-waitlist/src/server/terms/waitlist-v1.ts`) states unconditionally: "The $65 waitlist fee is non-refundable... regardless of whether a space becomes available or whether you later choose to withdraw," and frames the whole terms block as something shown "upon payment of the waitlist fee." Test A's mechanic (fee only takes effect if the tour is finalized) changes what happens BEFORE payment and potentially removes the payment event entirely for families who complete a tour. The current v1 text does not describe a deferred, conditional fee at all. Reusing v1's hash for a materially different mechanic breaks the file's own documented invariant ("byte-for-byte identical to what is rendered... any divergence... breaks clickwrap enforceability") and risks the parent's acceptance not matching what actually happens to their fee. This needs a genuine new version: `waitlist-v2.ts`, adding a paragraph describing the tour-waiver condition, the deadline, and the fallback if the tour is not completed, following the same versioning pattern already documented in the v1 file's own header comment. v1 was "COUNSEL-READY" as of 2026-06-15; a material change to the fee mechanic is not a copyedit and should go back through the same review, not just a Jarred rubber stamp. |
| `/state-employees/` "no application fee" contradiction class (CONTEXT-PACK line 48) | ACTIVE BUG, separate but adjacent | Confirmed live: `growingmindfully/state-employees/index.html` lines 98, 104, 335, 359 all state "no application fee" unconditionally (FAQPage schema + visible copy), which directly contradicts the resolved $65-mandatory-for-everyone policy (2026-07-06) even before this test exists. The tour-waiver LP must not recreate this pattern: every mention of the waiver must carry the tour condition in the same sentence (section 2a). Recommend fixing the existing `/state-employees/` bug in the same push that ships this test, since a state employee could plausibly land on both pages and see one page promise an unconditional "no fee" and the other describe a conditional waiver, an internal contradiction bad enough to be a preview of exactly what Google's Misrepresentation reviewers look for. |
| Public waitlist flow writes ONLY `waitlist_pipeline` + `waitlist_holds`, never `children`, never Solace enroll gate | Not implicated | Test A's fee-deferral state (e.g., a "pending tour completion" fee status) is a `waitlist_pipeline`/`waitlist_holds`-level concern, not an enrollment-gate concern. No policy conflict. Flag for the engineering lane: whatever column/status models "fee deferred pending tour" must land in these two tables only. |
| `solace-mirror.db` additive-only | Not implicated | This test does not touch Solace's mirror schema. |
| Stripe via httpx, not SDK | Not implicated by policy; implicated by mechanic | Test A likely changes WHEN Stripe is invoked (on tour completion vs on application submission) rather than how. Build-lane concern, not a policy concern; noting so the build lane sees it. |
| Never-drop (pause/edit only) in Ads account | Operational, not a policy conflict | Once a Test A campaign exists, it gets paused, not deleted, per standing account policy. No tension with anything above. |
| No em dashes anywhere in copy or code | HOLDS | This document and all drafted copy above use none. Flag to the copy-writer lane explicitly since ad copy is exactly where this rule gets missed under character-count pressure. |

## 5. Every Jarred gate flagged

1. **Tier 2, parent-facing copy.** Both the ad copy (section 3) and the new tour-waiver LP
   disclosure block (section 2b) are parent-facing and need Jarred's sign-off before publish.
2. **Tier 2, clickwrap edit.** A new `waitlist-v2.ts` terms version is required (section 4,
   clickwrap row). This is the single highest-friction gate in this test: it is not a copyedit,
   it changes what a parent is agreeing to at the fee step, and v1 was explicitly counsel-reviewed.
   Recommend routing the v2 draft through the same review path v1 took, not treating it as a
   routine Tier 2 approval.
3. **Tier 2, waitlist data mutation.** Any new fee-status value or column added to
   `waitlist_pipeline` / `waitlist_holds` to model "fee deferred pending tour completion" is a
   data-model change to the live public waitlist flow's own tables and needs the standard gate.
4. **Tier 2, production deploy.** The new dedicated LP, the `/state-employees/` fix (recommended
   companion fix, section 4), and any waitlist worker changes all route through `/safe-site-push`
   or the equivalent gm-waitlist deploy path. Nothing in this document authorizes any of that.
5. **Sequencing gate (new, this test specifically).** Ads must not go live before all three of:
   the dedicated LP with full disclosure (2b), the backend mechanic that actually defers/waives
   the fee on tour completion, and the updated clickwrap version are simultaneously live in
   production. Advertising the mechanic before it exists is precisely Google's "unavailable
   offers" violation (promising something "unavailable or not easily found from the destination")
   and the FTC/CA equivalent (the hairdresser "free haircut" example in section 6 sources is the
   same fact pattern: promise honored only if the underlying capacity to honor it exists).
6. **Test B: go/no-go on advertising at all.** Recommend Jarred explicitly decide to keep Test B
   out of paid media until the automated waiver (or a verified SOP) exists. This is a business
   decision this document is flagging, not something the compliance lane can resolve on its own.

## 6. Sources

- Google Ads Misrepresentation policy (overview): https://support.google.com/adspolicy/answer/6020955?hl=en
- Google Ads Dishonest Pricing Practices policy (effective Oct 28, 2025): https://support.google.com/adspolicy/answer/15938375?hl=en
- Google Ads Unreliable Claims policy: https://support.google.com/adspolicy/answer/15936857?hl=en
- Google Ads Unclear Relevance policy detail: https://support.google.com/adspolicy/answer/15936964?hl=en
- Google Ads Unavailable Offers policy detail: https://support.google.com/adspolicy/answer/15937063?hl=en
- Google Ads: About promotion assets: https://support.google.com/google-ads/answer/7367521?hl=en
- Google Ads: Promotion asset requirements (policy): https://support.google.com/adspolicy/answer/7374309?hl=en-GB
- Google Ads: Limited ad serving policy update (June 2026): https://support.google.com/adspolicy/answer/17122370?hl=en
- FTC, Guide Concerning Use of the Word "Free" and Similar Representations, 16 CFR Part 251: https://www.ftc.gov/legal-library/browse/rules/guide-concerning-use-word-free-similar-representations
- 16 CFR 251.1 full text (eCFR): https://www.ecfr.gov/current/title-16/chapter-I/subchapter-B/part-251/section-251.1
- 16 CFR 251.1 (Cornell LII, annotated): https://www.law.cornell.edu/cfr/text/16/251.1
- California Business and Professions Code 17500 (official text): https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=17500.&lawCode=BPC
- CA BPC 17500 explainer, including the conditional "free haircut" example used in section 5 item 5: https://www.shouselaw.com/ca/defense/business-professions-code/17500/
- CA BPC 17500.5 bait-and-switch context: https://law.justia.com/codes/california/2010/bpc/17500-17509.html

## Files read/checked in this repo during research
- `/Users/jarredwinn/Projects/gm-master/marketing/paid-ads/drafts/2026-07-10-tour-waiver-test/CONTEXT-PACK.md`
- `/Users/jarredwinn/.omnara/worktrees/growingmindfully/resale-distance/state-employees/index.html` (confirmed live "no application fee" bug at lines 98, 104, 335, 359)
- `/Users/jarredwinn/Projects/gm-waitlist/src/server/terms/waitlist-v1.ts` (confirmed unconditional non-refundable fee language, the source of the clickwrap conflict in section 4)
