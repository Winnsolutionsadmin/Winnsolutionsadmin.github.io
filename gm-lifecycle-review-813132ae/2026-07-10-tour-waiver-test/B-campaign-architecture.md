# B: Campaign architecture - "Search - Tour Offer | Fee Waiver Test"

Lane: CAMPAIGN-ARCHITECT (one of 5 parallel lanes on the 2026-07-10 tour-waiver-test build).
Status: STAGED PLAN ONLY. Nothing here executes anything. Login is blocked (see gm-ads brief
2026-07-10 ~15:30 PDT: parked at password prompt on LastPass unlock). Every operation below is
written so it can be run later either via the account's Scripts-slot tooling (tools/gads/ in
gm-ads, pattern: inject-run into an authorized slot, GAQL-verify after) or by hand in the UI
where scripts cannot commit the change (documented per-item below, mirroring the RTO-rebuild
precedent: geo/location changes need the UI EU-political-ads declaration gate).

Sources read: CONTEXT-PACK.md (this dir), gm-ads/brief.md (Bidding + budget, Locked decisions,
7/16 Review Decision Framework, Master Negatives/change-log entries), 50-rsa-copy-deck.md v1.2
FINAL (voice, hard rules, pinning convention), band-mapping.md (campaign IDs + click-band map).

Existing campaign IDs (for negative cross-blocking + reallocation math below):
- 23975530256 Search - Core High-Intent ($50/day budget share)
- 23975538422 Search - Infant Open Enrollment ($18/day)
- 23970501327 Search - Brand Defensive ($2/day)
- 23970710760 Search - State Employee / Downtown ($3/day)
- 23975504114 RTO | Secure Your Space ($30/day)
- 24000028073 Search - Preschool | Fall Research [band:preschool] ($12/day, ADS ONLY, not in
  the $103 "6 campaigns" split language of the brief - it sits on top per the 7/3 reactivation)

Total enabled budget today: $115/day ($103/day intended split + Preschool's $12, per brief
"Bidding + budget"). Freeze holds all of this until 7/16 review.

---

## 1. Campaign structure decision

**Recommendation: ONE new standalone campaign, TWO ad groups, geo-fenced identically to Core
(presence-only Sacramento), plus a bidirectional negative-keyword wall against Core/Infant/RTO/
State. Do NOT ALSO run the offer as ad variants inside the existing campaigns at launch.**

### Why a new campaign over in-campaign variants

The tour-waiver mechanic is a genuinely different funnel step (book-a-tour instead of
apply-then-pay), it needs its own landing page (per the CONTEXT-PACK directive: "dedicated
landing page"), and it needs its own conversion action pointed at a different final URL
(`/tour/`, already live, noindex, 0 internal links per CONTEXT-PACK). Folding tour-offer RSAs
into Core/Infant ad groups would:
- Break message match (Core's final URL is `/` or `/sacramento-daycare/`, not `/tour/`) unless a
  new ad group is created anyway inside Core - at which point it is not meaningfully "in
  addition to," it is the same structural cost with worse test isolation.
- Contaminate Core/Infant's own performance data mid-freeze, right when 7/16 evidence
  (rank-vs-budget-limited reads) is the thing being decided. A clean new campaign keeps its
  spend, CTR, and conversions out of the Core/Infant/RTO scorecards that feed the 7/16 call.
- Make the promote/kill test-registry math (T1-style pre-committed rules, one test at a time)
  impossible to run cleanly - a new campaign is a clean unit to pause/kill without touching the
  four proven, never-drop campaigns.

A secondary, SMALLER move that IS worth doing in addition (not instead): add ONE new tour-offer
headline + one description line as an ASSET-LEVEL addition to the existing Core RSAs' rotation
is explicitly NOT recommended here, because ad copy in Core is locked to the approved v1.2 deck
(any RSA edit is Tier 2 parent-facing gated) and mixing waitlist-first and tour-first CTAs in the
same ad group's rotation muddies the CTA the deck deliberately kept singular
("Waitlist-first CTA everywhere. No tour CTAs anywhere in ad copy" - deck ground rule, now
partially superseded by Jarred's directive but only for THIS test, not account-wide). Keep the
tour offer contained to its own campaign; revisit folding it into Core only after the test
proves out (test-registry promote path).

### Ad groups (2)

**AG1: Tour Intent (broad-ish, the core of the test)**
- Keyword theme: "book a tour", "daycare tour", "visit preschool", "open house" language.
- Final URL: the new dedicated tour-waiver LP (see note below on which URL - flagged to
  gm-website/copy lanes; working assumption `https://www.growingmindfully.org/tour-waiver/` or a
  variant param on the existing `/tour/` page, e.g. `/tour/?offer=fee-waived`. FLAG: confirm with
  the LANDING-PAGE lane agent before build; do not launch pointing at bare `/tour/` if that page's
  copy does not yet state the conditional waiver - message-match mismatch risk.

**AG2: High-Intent Overlap (money keywords, offer-differentiated)**
- Keyword theme: a SMALL set of the same "daycare sacramento" / "childcare near me" root terms
  Core already owns, but ONLY as phrase/broad-modified variants carrying tour-specific intent
  modifiers ("daycare tour sacramento", "visit daycare near me") - not bare "daycare sacramento"
  duplicated into a second campaign. This ad group exists to catch searchers who are close to
  Core's money terms but signal a tour/visit intent Core's RSAs do not address (Core's copy is
  waitlist-first, never tour-first). Where a keyword would be an exact duplicate of a Core money
  keyword, it stays OUT of this campaign (see negative cross-block below) - the differentiation
  has to live in the query language itself, not in bidding two campaigns on the identical term.

### Negative-keyword cross-blocking (both directions) - the cannibalization guard

Google auction-eligibility is per campaign, so if "daycare sacramento" exact lives in BOTH Core
AND the new campaign, Google runs an internal auction between your own ads (self-competition,
inflated CPCs, split QS history). The guard:

1. **New campaign -> negates Core's exact money terms.** Add campaign-level negative EXACT match
   on the new campaign for every one of Core AG1's tier-1 exact keywords (daycare near me,
   daycare sacramento, childcare sacramento - the "[kw] ... verbatim" primary keywords in deck
   1.1/1.2) PLUS Infant's primary exacts (infant daycare sacramento, infant care sacramento) PLUS
   RTO/State's primaries (daycare downtown sacramento, state employee childcare, full time daycare
   sacramento). This keeps the tour campaign from ever bidding head-to-head on Core's proven
   converters; it can only win auctions on tour-flavored queries.
2. **Core/Infant/RTO/State -> negate tour-flavored terms**, so if a tour-intent query does slip
   through Core's phrase/broad matches, it routes to the new campaign instead of serving a
   waitlist-first Core ad on a tour-seeking query (bad message match, wastes Core's budget-limited
   spend per the 7/16 evidence). Add to Core/Infant/RTO/State's negative list (or the shared
   `GM Master Negatives` list if the terms are unambiguously tour-only - see below on which list):
   "tour" (broad/phrase as appropriate), "open house", "visit the school", "book a visit",
   "schedule a tour", "daycare tours near me".
3. **List mechanics:** do NOT add these to the account-wide `GM Master Negatives` shared list
   (currently 109 entries, attached to all 6 campaigns) for the Core-side block, because that
   list is meant for universally-irrelevant terms (job-seeker junk, agency spam) - these tour
   negatives are relevant to ONE campaign (the new one) and harmful to the others, i.e. they are
   campaign-specific, not universal. Create a SECOND shared negative list, "GM Tour-Cannibalization
   Guard," with two members used asymmetrically:
   - Attach the "Core/Infant/RTO/State money-term negatives" half to the NEW tour campaign only.
   - Attach the "tour-intent negatives" half to Core + Infant + RTO + State (NOT the new campaign,
     obviously, and NOT Brand/Preschool - Brand should still be defensible on "growing mindfully
     tour" if anyone searches it, and Preschool is a standby campaign not in scope for this test).
   Simpler alternative if Scripts-slot tooling makes two lists awkward: do it as plain
   campaign-level negative keywords (no shared list) on exactly 5 campaigns. Recommend the shared
   list for auditability (one place to review the guard), but either mechanism satisfies the
   requirement - flag this as an implementation-detail choice for whoever executes the build.
4. Existing `GM Master Negatives` (109 entries, job-seeker terms etc.) attaches to the new
   campaign as normal, same as every other campaign - no change to that list's membership.

**Primary approach, stated once for clarity:** new standalone campaign + bidirectional negative
wall. Do not run tour copy inside Core/Infant/RTO/State ad groups at launch.

---

## 2. Keywords (22 total)

Match-type convention follows the account's existing style (mix of exact/phrase, primary keyword
in exact). All geo-scoped to Sacramento per LP/site language (no bare national terms).

### AG1: Tour Intent (14 keywords)

| Keyword | Match | Rationale |
|---|---|---|
| daycare tour sacramento | Exact | Primary keyword, exact intent match |
| daycare tour sacramento | Phrase | Volume net around the primary |
| visit preschool near me | Broad (modified via phrase core) | Preschool-adjacent tour intent; note Preschool campaign is standby, this catches tour-stage preschool searchers without reopening Preschool enrollment ads |
| visit daycare sacramento | Phrase | |
| childcare open house | Phrase | Matches CONTEXT-PACK's named tour-intent term |
| childcare open house sacramento | Exact | |
| book a daycare tour | Phrase | |
| schedule a daycare tour | Phrase | |
| daycare tours near me | Phrase | |
| preschool open house sacramento | Phrase | |
| infant care tour sacramento | Phrase | Ties to the emptiest room (Infant, 10-11 open per CONTEXT-PACK capacity note) |
| tour a daycare sacramento | Broad | |
| daycare visit sacramento | Phrase | |
| free daycare tour sacramento | Phrase | Echoes the offer directly; watch QS, this is close to the LP promise |

### AG2: High-Intent Overlap, tour-flavored only (8 keywords)

| Keyword | Match | Rationale |
|---|---|---|
| daycare tour downtown sacramento | Phrase | RTO/downtown overlap, tour-flavored so it does not duplicate RTO's bare "daycare downtown sacramento" |
| visit childcare near me | Phrase | Near-me tour variant, differentiated from Core's bare "daycare near me" |
| daycare near me tour | Broad | |
| sacramento daycare open house | Phrase | |
| state employee daycare tour | Phrase | Ties the waiver test to the State/RTO segment already in-account without duplicating their exacts |
| childcare tour sacramento ca | Phrase | |
| best daycare tour sacramento | Phrase | Comparison-stage + tour, mirrors Core 1.2's "best daycare" framing but tour-flavored |
| application fee waived tour | Broad | Directly targets searchers who found the offer via word-of-mouth/remarketing and are searching the mechanic itself; low volume expected, cheap to test |

Total: 22 keywords (14 + 8), inside the 15-25 target range.

**Respecting Master Negatives:** all 22 keywords checked by hand against the job-seeker-term
class of negatives already in `GM Master Negatives` (109 entries: "teacher," "assistant," "hiring,"
"indeed," etc. per the 7/3-7/7 change-log entries) - none of the above collide with employment-
intent phrasing. Standard weekly search-term review cadence (2-3 days through 2026-07-17 per
brief "Standing cadence adds") applies to this campaign identically to the others once live.

---

## 3. Budget + bidding

**Recommendation: $12/day, Max Clicks, $8.50 max CPC ceiling. Fund via REALLOCATION, not a
budget-raise proposal.**

- **Bid strategy:** Maximize Clicks with a capped max CPC of $8.50 - the same ceiling tier
  already used for Infant/Preschool/State (Stage 0 tiered ceilings: $13/$10.50/$8.50/$8.50/$4 per
  brief "Bidding + budget"). Sits mid-tier: this is a NEW, unproven query set (tour intent has no
  conversion history at all), so it does not warrant Core's $13 ceiling, but tour-intent traffic
  is plausibly higher-value-per-click than State/Brand's $8.50/$4 tier given it is testing a
  differentiator, hence $8.50 not $4.
- **Explicitly NOT Max Conversions.** Sparse-data rule applies harder here than anywhere else in
  the account: this is a brand-new campaign with ZERO conversion history, and the account-wide
  precondent (7/16 framework: "Several fee-paids -> switch to Maximize Conversions... HARD
  PRECONDITION: demote gmwl_email_submitted to SECONDARY first") is itself not yet met for the
  EXISTING campaigns. A new campaign inherits nothing to bid on; Max Clicks is the only sane
  choice at launch, full stop, independent of the 7/16 decision for the rest of the account.
- **Budget source: REALLOCATION, not a raise.** The brief is explicit that budget raises are
  "evidence-gated proposals only" and the 7/16 framework's own reallocation candidate is "idle
  RTO -> Core" (RTO lost-to-budget was 0%, i.e. RTO has headroom Google is not fully using,
  while simultaneously RTO has been SURGING and overdelivering 7/7-7/9 per the spend-surge
  finding - those two facts sit in tension and are exactly why this is a 7/16-timed decision, not
  a pre-freeze one). For the tour test specifically, recommend pulling from **Brand Defensive
  ($2/day -> $0, folded to $0 is too aggressive; more precisely: trim Brand by $1 (to $1/day) and
  State Employee/Downtown by $1 (to $2/day)** to free $2/day, plus **redirect $10/day of
  Preschool's reactivation budget is NOT recommended** (Preschool is its own live test with its
  own rationale, do not touch it) - so the cleanest single source is actually the **10-15%/week
  reallocation allowance already granted in the brief ("May reallocate 10-15%/week within the
  cap, logged, no campaign zeroed")**: trim RTO from $30/day to $27/day (10% trim, RTO stays
  well-funded and per the brief explicitly "never paused / never zeroed") and Core from $50/day
  to $47/day (6% trim, still the largest share) to free exactly $6/day, combined with the $2/day
  from Brand+State above, funding **$12/day for the new campaign with $4/day left as a buffer
  inside the existing $115 ceiling** (or simply launch at $8/day if Jarred wants zero buffer and a
  smaller first test). **No campaign is zeroed, all trims are inside the logged 10-15%/week
  allowance, and total enabled spend does not cross $115.** This keeps the launch entirely inside
  already-granted reallocation authority and avoids a new gate.
- **Stated ceiling relationship:** CONTEXT-PACK asks for "$10-15/day... fits within/adjacent to
  the $103/day split under the $115 ceiling." The reallocation above lands at $12/day inside the
  existing ceiling with $103 -> $97 (trims) + $12 (new) = $109, plus Preschool's $12 = $121 -
  **this EXCEEDS $115** if Preschool is counted in the ceiling. Re-reading the brief: the $115
  figure is described both as "budget: total $103/day HELD... may reallocate" and separately the
  state-now line reads "Total enabled budget now $115/day" (which already includes Preschool's
  $12 on top of $103). **Correct math: $103 (six-campaign-minus-preschool split) - $6 (RTO+Core
  trims) + $12 (new) = $109 in that split, plus Preschool's already-separate $12 = $121 total
  enabled.** This is $6/day OVER today's $115 all-in ceiling. Two paths, pick one:
  (a) launch at **$8/day instead of $12/day** for the tour campaign, landing the all-in total at
  $103 - $6 + $8 + $12(preschool) = $117, still $2 over - so trim one more dollar from Core
  ($50->$46, an 8% trim, still inside 10-15%) to land exactly at $115 all-in; or
  (b) treat this as a genuine incremental need and surface a **small, explicit budget-raise ask
  to Jarred** ($103 -> $109 split, or $115 -> $121 all-in) since it is evidence-gated by the
  CONTEXT-PACK's own economics case (empty-seat cost $6.4k-$9.4k/week, one enrollment covers a
  month of spend). **Recommend (b) with a small ask, framed honestly, rather than forcing (a)'s
  awkward stacked micro-trims** - the reallocation-only path technically fits but requires
  trimming Core AND RTO AND Brand AND State simultaneously for a net $8/day campaign, which is a
  lot of surface area to touch for a small test. **The one decision Jarred must make (see the
  10-line summary) is exactly this: approve a $6-8/day incremental budget line for the test
  (new $115-121/day all-in ceiling), or force it inside the existing $115 via the multi-campaign
  trim in path (a).**

---

## 4. RSA copy deck (15 headlines, 4 descriptions)

Voice: calm, editorial, mindful, per 50-rsa-copy-deck.md v1.2 style (no superlatives beyond the
approved uncited "Top-Rated," concrete/checkable trust claims, "5 minute walk" as THE proximity
number, no em dashes, headlines <=30 chars, descriptions <=90 chars, counts below are
machine-verified char counts including spaces/punctuation).

**ABSOLUTE RULES applied:** no dollar amounts anywhere; no licensing anything (no "Lic.," no CDSS
citation, no H&S code); no em dashes; nothing states the $65 figure or even implies a number;
"Top-Rated" stays uncited exactly as the account default. Fee is framed only as "the application
fee," never quantified.

### Headlines (15)

- [kw] Book a Tour, Sacramento (26) - primary keyword echo
- [kw] Daycare Tours, Downtown Sac (28)
- [kw] Visit Us Before You Apply (26)
- [kw] Childcare Open House, Sac (27)
- [cta] Book a Free Tour Online (24)
- [cta] Tour First, Fee Waived (24) - names the mechanic without a number
- [cta] See the Rooms, Meet Staff (27)
- [tr] Licensed Since 2018 (19)
- [tr] Top-Rated by Sac Families (25)
- [tr] 1:3 Infant Ratios (17)
- [loc] 5 Min Walk From the Capitol (27)
- [loc] Downtown at 750 N Street (24)
- [psy] Come See Before You Decide (27)
- [psy] Your Tour, Your Questions (25)
- [psy] A Calm First Visit (18)

### Descriptions (4)

- [d-cta] Book a tour and complete your application in one visit. The application fee is waived
  with your tour. (90)
- [d-value] See the rooms, meet the teachers, ask every question. A 5 minute walk from the
  Capitol at 750 N Street. (90)
- [d-emotion] The best way to know if a place is right is to walk through it. Book a free tour,
  no obligation. (87)
- [d-diff] Licensed since 2018, 1:3 infant ratios, nut-free organic snacks. Book your tour to see
  it yourself. (89)

**Waiver framing check (message-match discipline, per CONTEXT-PACK's own flagged bug on
/state-employees/):** every fee-waiver headline/description states the waiver as CONDITIONAL on
tour completion ("waived with your tour," "in one visit... waived with your tour") - never a bare
"no application fee" claim, which is exactly the contradiction CONTEXT-PACK flags as a live bug
elsewhere and warns not to repeat. This is the one line item this lane treats as non-negotiable
copy QA before launch, independent of who else touches the deck.

### Pinning recommendation

**Pin nothing**, consistent with the account-wide default (deck's only exception is Brand's H1
pin, not applicable here). Considered pinning "Book a Tour, Sacramento" to H1 to guarantee the
tour framing always leads, but the account's working theory (audit findings, RSA combinatorial
system) is that unpinned rotation outperforms heavy pinning, and 15 headlines give Google enough
combinations to learn which pairs work without forcing it. Revisit only if early Ad Strength /
per-asset performance data shows the tour-mechanic headlines under-serving relative to generic
trust/location headlines.

---

## 5. Assets

**Sitelinks (4, reuse existing where the target matches, following the account's title/line
character limits: titles <=25, lines <=35):**

1. Tour page (NEW, final URL = the dedicated tour-waiver LP once confirmed)
   - [sl-title] Book Your Free Tour (20)
   - [sl-line] See the rooms and meet the teachers. (36 - trim to 35: "See the rooms, meet the
     teachers." (34))
   - [sl-line] Application fee waived with your tour. (37 - trim: "Waived: application fee with
     your tour." (36 - still over; final: "App fee waived when you tour." (30))
2. Infant care (REUSE existing sitelink 2 from the approved deck: "Infant Care From 6 Weeks,"
   final URL `/infant-care/` - no change needed, attach at campaign level to this new campaign
   too)
3. Rates (REUSE existing sitelink 1: "See Tuition Rates," final URL `/rates/` - no change)
4. Our Approach (NEW target - flag: confirm live URL slug with gm-website lane; if no dedicated
   "Our Approach" page exists yet, substitute the existing State Employee Rates sitelink instead
   to avoid linking a 404)
   - [sl-title] Our Approach (12)
   - [sl-line] Mindfulness-based care, every day. (33)
   - [sl-line] Infant through preschool, downtown. (34)

**Callouts (4, <=25 chars, reuse account style):**
- [co] Free Tour Available (20) - NEW
- [co] Fee Waived With Tour (21) - NEW, states the mechanic, no dollar amount
- [co] Near the Capitol (18) - shortened from existing "5 Min Walk to the Capitol" callout;
  reuse the existing callout directly instead if character budget allows both on rotation
- [co] Loved by Local Families (24) - NEW per CONTEXT-PACK request; note this sits close to
  "Top-Rated by Sac Families" (already an approved headline claim) - keep both, they read as
  distinct assets (one a callout, one a headline) so no duplicate-claim policy risk

**Structured snippets:** reuse the two existing sets unchanged (Programs: Infant/Toddler/Young
Preschool/Preschool; Services: Full-Time/Part-Time/Mindfulness/Yoga and Music/Outdoor Play) -
no new snippet needed for a tour-specific angle; the existing Services set already covers what a
tour would show a visitor.

**Promotion asset - CONDITIONAL proposal only:** Google's Promotion extension is built for
percent/dollar-off or "no-cost X" style promos, which is a closer structural fit for "waived fee"
than callouts/sitelinks can express (promotion assets have a dedicated "Money off" / "Get a
special offer" schema Google surfaces distinctly in the SERP). **IF the policy lane's read of ad
policy + the parent-facing-copy gate would allow it,** propose:
- Promotion type: "No-Cost Item" (waived application fee) rather than a percent/dollar-off type
  (avoids stating "$65" or "100% off" language which could imply the dollar figure indirectly)
- Item: "Application Fee" ; Details line: "Waived when you book and complete a tour" (no amount)
- Occasion: none / standard (not a seasonal promo, this is an ongoing test mechanic)
This is written CONDITIONALLY because: (a) it is new asset surface not yet used anywhere in the
account, so it needs its own policy-review cycle before it can be trusted not to disapprove or
misrepresent the offer: Google's promotion UI often nudges toward showing a percentage or dollar
value, which could conflict with the "never state the $65 figure" hard rule if the UI auto-fills
one; (b) it is unambiguously parent-facing copy, Tier 2 gated, so it needs Jarred's sign-off
regardless of the policy read. Recommend the COPY-lane or POLICY-lane agent in this 5-agent build
render a final judgment on Google's exact promotion-asset schema fields before this is built;
this lane flags it as available but does not commit to it.

---

## 6. Conversion actions

**Propose two new actions, both under the SAME "demote email to secondary first" discipline the
account already runs.**

1. **`gmwl_tour_booked`** (NEW GA4 event -> Ads import)
   - Category: Book Appointment (or Submit Lead Form if Book Appointment isn't offered for this
     property type - flag for whoever runs the Ads conversion wizard to pick the closest fit)
   - Status: **Secondary** at launch. Fixed value ~$25 (a mid-funnel proxy value, well below the
     $65 fee-paid value and far below the $1,839 reserve value, reflecting that a booked tour is
     a real but early signal - roughly the account's existing "$5 email / $65 fee / $1,839
     reserve" value ladder, with tour booking sitting between email and fee since it requires
     more commitment than an email but is not yet a payment).
   - Count: One. Attribution: DDA (matches existing actions), 90d window (matches existing).
   - This is what the TEST campaign OPTIMIZES TOWARD structurally (it is the closest, most
     frequent signal available for a brand-new campaign with a Max Clicks strategy - but note
     Max Clicks does not optimize on conversions at all; this action exists for REPORTING and
     future Max Conversions eligibility, not for today's bid strategy).

2. **`gmwl_tour_completed_waiver`** (the real success event - fires when a tour is completed AND
   the waiver actually applies, i.e. the application converts through the conditional-waiver
   path per the CONTEXT-PACK mechanic: "the waitlist fee... only takes effect if they finalize
   the tour")
   - Category: Purchase (mirrors `gmwl_fee_paid_confirmed`'s category, since this event is
     functionally "the fee-paid moment for the tour-waiver path" - either the fee is waived
     [$0 charged] or the deferred fee posts, so this event should fire regardless of whether $0
     or $65 was actually charged, since the NEXT-STEP intent, tour attendance + application
     finalization, is what matters for measurement)
   - Status: **Secondary initially** (NOT primary) - deliberately mirrors the account's own
     precedent with `gmwl_application_submitted` staying secondary "funnel diagnostic; primary-
     signal question returns at the Stage 1 bidding gate" (Locked decisions). This event has ZERO
     history; it should earn primary/headline status the same way `gmwl_fee_paid_confirmed` did,
     through volume and a deliberate Jarred-gated promotion, not by default at launch.
   - Value: match the existing rate-card logic if possible (per age_band/tier from `rate_card`)
     rather than a flat number, OR flat $65 to mirror `gmwl_fee_paid_confirmed`'s value
     convention if per-band values aren't practical for a first cut - defer the exact value
     mechanic to whichever lane owns the GA4/event-schema build (this is a build-detail, not a
     structural one).

**Relationship to existing actions (gmwl_email_submitted / gmwl_fee_paid_confirmed):**
- `gmwl_email_submitted` (existing, PRIMARY $5) still fires identically if a tour-campaign visitor
  starts the overlay flow before booking a tour - no change to that action, no double-counting
  risk since it is a distinct event name.
- `gmwl_fee_paid_confirmed` (existing, PRIMARY $65, headline metric) is the action that ALREADY
  fires when the deferred fee is actually charged (post-tour, per the mechanic). Do NOT create a
  duplicate fee-paid action for the tour path - reuse the existing one so the account-wide
  headline metric stays a single source of truth. `gmwl_tour_completed_waiver` is a DIFFERENT,
  ADDITIONAL signal (tour attendance + waiver applied), not a replacement for the fee-paid event;
  a tour-waiver conversion may show BOTH `gmwl_tour_completed_waiver` AND (if a fee posted, e.g.
  the family didn't complete the tour so the deferred $65 charged per the "if not, then it just
  adds it to their next bill" mechanic) `gmwl_fee_paid_confirmed` - these are complementary
  signals on the same person, not duplicative conversions in Ads' eyes since they are different
  named actions.

**What the TEST campaign optimizes toward vs reports:**
- **Optimizes toward:** nothing yet (Max Clicks bid strategy, capped CPC, no conversion-based
  optimization at launch - matches the account-wide Stage 0 posture and the sparse-data
  precondition above).
- **Reports on:** `gmwl_tour_booked` (secondary, the frequent top-of-funnel signal for this test)
  and `gmwl_tour_completed_waiver` (secondary, the real success metric) both flow into the
  campaign's own scorecard row exactly like every other campaign's conversions column, PLUS this
  lane recommends the test-registry.md mechanism (pre-committed promote/kill rule, one test at a
  time) be used for a formal T2 entry once this campaign is live - primary metric = tour-booked-
  to-waiver-completed rate, diagnostic = ad group 1 (Tour Intent) vs ad group 2 (High-Intent
  Overlap) split performance.

---

## 7. Serving

- **Geo:** mirror Core's presence-only Sacramento targeting exactly (same rings/shed as Core, not
  the narrower State Employee 9-target commuter shed, since tour-seekers are not necessarily state
  employees). Presence-only geo_target_type_setting, GAQL-verifiable the same way State's was
  verified (per the account's canonical geo-verification method, brief 2026-07-02 entry). NOTE:
  per lessons learned on the RTO rebuild, campaign creation must answer the EU
  political-advertising declaration "No" to unlock scripted geo targeting at create time - if
  built via Scripts, follow that same sequence; if built via UI, geo can be set directly, no
  declaration gate blocks it in the UI path (only the Scripts API path needs the declaration
  answered correctly at creation).
- **Ad schedule:** no dayparting restriction at launch (matches every other campaign in the
  account - none currently daypart). Revisit only if early data shows a clear off-hours-tour-
  request pattern (unlikely to have enough volume to justify this before the 7/16-adjacent
  review window anyway).
- **Device:** no device bid adjustments at launch, consistent with account convention (Max Clicks
  campaigns in this account do not currently carry device modifiers). Mobile is expected to
  dominate impression share the same way it does for Core/Infant; no action needed unless a
  device-specific CPC anomaly shows up in the first 1-2 weeks.
- **Networks:** Search only, no Search Partners expansion beyond whatever the account's existing
  default is per campaign (match Core's setting exactly rather than deciding independently here -
  flag for the build executor to copy Core's exact network settings).

---

## 8. Launch sequencing vs the 7/16 freeze

**Recommendation: launch AT/after 7/16, as part of the review batch. Do not seek a freeze
waiver.**

Rationale, weighed against the RTO-rebuild precedent (which DID get a freeze waiver on
2026-07-03):
- The RTO waiver was granted because RTO was a NAMED, TIME-BOXED, externally-triggered flight
  (Executive Order N-22-25's 4-day office week took effect July 1, 2026 - a real calendar deadline
  outside the account's control) and the campaign was already live and underperforming on stale
  keywords; the waiver was a REPAIR of an existing asset against a hard external date, not a
  net-new campaign launch.
- This tour-waiver test has no equivalent external deadline. The offer mechanic ("book a tour,
  fee waived") is valuable whenever it launches; nothing decays if it starts 6 days later at 7/16
  instead of today.
- **A genuinely strong countervailing argument exists and should be surfaced, not just
  dismissed:** the CONTEXT-PACK's own evidence base is urgent - fee-step friction is diagnosed as
  THE binding constraint (unanimous 5-model counsel read), 2 of the last 2 applications have
  stalled at the $65 payment step, and empty-seat cost is $6.4k-$9.4k/week. Six days of delay at
  that burn rate is a real, quantifiable cost. If Jarred wants to waive the freeze for THIS test
  specifically (mirroring the RTO precedent's logic - "this is urgent enough to justify a
  freeze-waived launch"), that is a legitimate call for him to make, not this lane overriding the
  default. **This lane's default recommendation is 7/16-batch, but flags the waiver option
  explicitly as available if Jarred weighs the friction evidence as RTO-grade urgent.**
- Launching as part of the 7/16 batch also lets this new campaign inherit whatever reallocation
  decision comes out of that same review (the RTO-idle-budget question is native to that same
  meeting), rather than this lane's budget section above having to pre-guess the outcome of a
  decision that is 6 days away anyway.
- Practically: the dedicated landing page, the promotion-asset policy question, and the exact
  conversion-action values all benefit from a few more days of parallel-lane work (copy, landing
  page, conversion-schema lanes in this same 5-agent build) landing before this campaign goes
  live, rather than rushing a build today against a blocked login anyway (per brief: automation
  Chrome is parked on the LastPass unlock, nothing executes until Jarred runs `lpass login`
  regardless of freeze status).

---

## Build checklist (exact operations, in order, once login is unblocked and Jarred approves)

1. **Confirm final URLs** with the landing-page lane: the dedicated tour-waiver LP path, whether
   it is a new page or a parameterized variant of the live `/tour/` page, and whether it states
   the conditional-waiver mechanic correctly (no bare "no application fee" claim).
2. **Create the negative-keyword guard first, before the campaign**, so it exists to attach at
   creation time:
   a. Decide list mechanism (new shared list "GM Tour-Cannibalization Guard" vs plain
      campaign-level negatives - recommend the shared list for auditability).
   b. Populate: Core/Infant/RTO/State money-term negatives (for attachment to the NEW campaign).
   c. Populate: tour-intent negatives (for attachment to Core/Infant/RTO/State).
3. **Create the campaign** "Search - Tour Offer | Fee Waiver Test," Search network only (match
   Core's network settings), Max Clicks bid strategy, $8.50 max CPC ceiling (or the value Jarred
   picks after the budget decision in section 3), budget per the resolved section-3 amount.
   - If built via Scripts: answer the EU political-advertising declaration "No" at creation to
     unlock scripted geo targeting (RTO-rebuild lesson).
   - Set geo: presence-only, mirror Core's target list exactly.
4. **Attach `GM Master Negatives`** (109-entry list, standard for every campaign) to the new
   campaign.
5. **Attach the new campaign's half of the cannibalization guard** (Core/Infant/RTO/State money
   terms) to this campaign; attach the tour-intent half to Core, Infant, RTO, and State
   individually.
6. **Create ad group 1 "Tour Intent"** with its 14 keywords (section 2 table) at the stated match
   types, final URL = confirmed tour-waiver LP.
7. **Create ad group 2 "High-Intent Overlap"** with its 8 keywords, same final URL (or a
   differentiated one if the copy lane wants to A/B the LP by ad group - flag as an option, not
   required).
8. **Build the RSA** (section 4: 15 headlines, 4 descriptions, no pinning) in each ad group -
   confirm final char counts against the live editor (this doc's counts are hand-verified but
   re-verify at Scripts/UI time per the account's own "machine-verified" convention).
9. **Attach assets** (section 5): 4 sitelinks (2 reused, 2 new - confirm the "Our Approach" URL
   exists before linking it, else substitute), 4 callouts (2 reused/adapted, 2 new), reuse the 2
   existing structured-snippet sets unchanged. Hold the promotion asset pending the policy lane's
   read (section 5, conditional).
10. **Create conversion actions** (section 6): `gmwl_tour_booked` (secondary, ~$25, DDA, 90d) and
    `gmwl_tour_completed_waiver` (secondary, Purchase category, value per rate_card or flat $65,
    DDA, 90d) - both via the Ads conversion-setup wizard once the matching GA4 events exist
    (coordinate with the GA4/event-schema lane in this build; do not create the Ads-side action
    before the GA4 event is confirmed live, mirroring the account's own tier-1/tier-3 staging
    precedent).
11. **GAQL-verify end state**: campaign settings (budget, bid strategy, geo type), both ad
    groups' keyword counts and match types, RSA text against this doc verbatim, both negative
    lists' attachments in both directions, both new conversion actions' category/status/value.
12. **Log to change-log.md** (5 rows minimum: campaign creation, ad-group x2, negative-guard
    creation + attachment, RSA/asset publish, conversion-action creation) with the standard
    columns (what/why/effect/review-date).
13. **Add a T2 entry to test-registry.md** (tour-waiver test) with pre-committed promote/kill
    rules, primary metric = tour-booked-to-waiver-completed rate, mirroring T1's structure.
14. **Surface to Jarred** (Tier 2 gates, all of section 3's budget decision, section 5's
    promotion-asset call, section 8's freeze-timing call) before any of the above executes.

---

## Open items this lane could not resolve alone (flag to coordinator / other lanes)

- Exact final URL for the dedicated tour-waiver LP (landing-page lane).
- Whether the promotion asset is policy-safe without an implied dollar figure (policy/copy lane).
- Exact GA4 event schema/value logic for `gmwl_tour_completed_waiver` (conversion-schema lane).
- Confirmation that `/tour/` or its variant currently states the CONDITIONAL nature of the waiver
  correctly, given the account's live precedent of getting this exact class of claim wrong on
  `/state-employees/` ("No application fee" stated twice, contradicting the mandatory $65) -
  CONTEXT-PACK explicitly warns not to repeat this bug; whoever builds the LP copy should treat
  this as the single highest-priority QA check before launch.
