# CONTEXT PACK 2 - GM Lifecycle Funnel + Ad Variant Matrix (2026-07-11)

## Jarred's directive (verbatim intent, this supersedes conflicting prior rulings where noted)
1. Tour bookings must update ALL databases (D1, GA4, dashboards) - full tracking.
2. LIFECYCLE EMAILS (automated journey):
   T1: paid waitlist fee + NO tour done -> send "Reserve Your Space" campaign email within 24h.
   T2: clicked T1 but did not reserve, tries to EXIT the reserve page -> "book a tour" winback
       popup -> routes to /tour/, tracks the booking.
   T3: still no tour booked -> +24h email: "Book a tour and waive your enrollment fee!"
   T4: tour FINISHES (send 1h after scheduled tour END time) UNLESS Ashley marked no-show in
       GM admin (Kindred) -> promo email: reserve your space by 5PM TODAY and we waive the $45
       enrollment fee. Must follow the EXISTING email template formatting + picture style,
       with a DIFFERENT picture.
3. CAMPAIGN GRID (Kindred portal): per-waitlist-family rows x campaigns columns; cell states:
   received / engaged-not-converted / converted. Click a cell -> drill-level data (sends,
   opens, clicks, timestamps). Email campaigns need open+click tracking (pixel + wrapped links).
4. The no-waitlist-fee (tour-waiver) campaign is tracked INDEPENDENTLY, converts comparatively
   vs the standard flow. Its public brand name: "OPEN ENROLLMENT!".
5. AD VARIANT MATRIX - build multiple creative sets:
   V1 "OPEN ENROLLMENT!" (the no-waitlist-fee campaign)
   V2 "Back to School"
   V3 "$100+ in fees waived this week only! Tour our location for FREE!"
   V4 "Free no obligation tour"
   V5 "$65 waitlist fee waived!"
   plus more sets if warranted. SUPERSESSION (Jarred 2026-07-11 verbatim "One should be 65
   waitlist fee waived!"): dollar figures ARE now allowed in ad copy for these variants -
   the 7/2 "no $65 in copy" deck ruling is superseded FOR THESE TESTS. "$100+" = $65+$45
   stacked waivers, must be truthful + conditions clear. "this week only" urgency claims must
   actually expire/rotate (policy risk if evergreen) - design accordingly.
6. Wire GA4 + gtag as needed. 7. Landing pages UNIFORM with existing: hero text, booking
   availability, brand system. 8. Also: brainstorm further improvements on the whole concept.

## Build on the EXISTING tour-waiver package (do NOT duplicate it)
~/Projects/gm-master/marketing/paid-ads/drafts/2026-07-10-tour-waiver-test/ contains:
SYNTHESIS.md (decision brief D1-D9), A-policy-compliance.md, B-campaign-architecture.md
(campaign "Search - Tour Offer | Fee Waiver Test", 22kws, negative wall), C-landing-page.md +
lp-tour-offer-mockup.html (brand-matched LP mockup), D-waitlist-flow.md (tour_waivers side
table design, pending_tour state machine - applications table is at 99/100 D1 columns, CLOSED
to new columns), E-measurement.md (decision rules, ~100-session directional reads, volume
honesty: 43-58 paid clicks/WEEK account-wide). The ISOLATION MANDATE (2026-07-11): test LPs
noindex + zero internal links + ad-click-only entry; waiver flag only via ?offer= param.

## Live state (2026-07-11 AM)
- Ads login WORKING (backup-code path). Account 945-427-9476, freeze ends 7/16, Stage 0 capped
  Max Clicks, $103/day split under $115 ceiling. First paid fee-paid conversion in-account
  (Core, click 7/7, Flynn - a state employee). Tier-1 email import proven. Local-actions
  conversion pollution pending a Jarred demote approval.
- Tour booking LIVE: www.growingmindfully.org/tour/ (calendar, noindex, 0 internal links),
  waitlist.growingmindfully.org/api/tours/slots + /book (rate-limited 4/hr), bridge dual-push
  to ashley@growingmindfully.org calendar every 5 min.
- Repos: gm-ads (~/Projects/gm-ads), growingmindfully (site), gm-waitlist (worker+D1),
  kindred-portal (admin), gm-master (context hub). Solace mirror db on mini (ssh mini).
- D1 ground truth: 12 waiting fee-paid families; GA4 funnel overlay 117 -> app 16 -> fee 6;
  fee-exit winback module EXISTS (gmwl_fee_exit_winback_* events, offers tour on fee abandon).
- Capacity: Infant emptiest (10-11 open), Toddler full til Aug, Preschool 6-9 open + Feb 2027
  wave. Empty seats cost $6.4k-9.4k/WEEK. Rate card FT: $1,436-$2,074/mo by band/tier.

## HARD RULES (non-negotiable, verify against these)
- NEVER anything licensing-related in ads/site/emails. NO EM DASHES anywhere.
- Never-drop in Ads (pause/edit only). Additive-only schema (side tables; applications closed).
- Public flow writes ONLY waitlist_pipeline + waitlist_holds + gm-waitlist-owned tables;
  NEVER children table; NEVER Solace enroll gate. Stripe via httpx. Reservation = paid hold +
  queued admin task; Enrolled stays manual (Ashley, Jarred-gated).
- Brightwheel money ops ONLY via Bw* skills/bwlib (dry-run -> confirm -> execute -> verify).
- Promotional emails to applicants: CAN-SPAM (unsubscribe + physical address), suppression
  rules required. Clickwrap terms changes = counsel-reviewed version bump (Tier 2).
- Tier 2 Jarred gates: parent-facing copy, waitlist mutations, clickwrap, budget, prod deploys.
- Timezone: America/Los_Angeles for all scheduling (5pm rule, 24h windows).

## Output contract
Ground agents -> ~/Projects/gm-master/marketing/paid-ads/drafts/2026-07-11-lifecycle-funnel/ground/<name>.md
Design agents -> .../design/<name>.md   Verify agents -> .../verify/<name>.md
Concrete: file paths, DDL, endpoint signatures, full copy text, event names, numbers.

## HOOTL GOVERNANCE MANDATE (Jarred 2026-07-11: "Ensure this is fully governed by HOOTL rules")
HOOTL = Human Out Of The Loop (canon: Jarred 7/04 verbatim "these messages shouldn't come to me
considering you were able to fix them fine without my intervention. i just need one update of all
changes that took place, and one inquiry as to things that only I could answer"; 7/11: "Don't ask
me shit unless you are certain you can't handle it"; alerts rule: single-messenger escalation,
agent-owned deadlines). The MASTER PLAN must bake these in as architecture, not aspiration:
1. AUTONOMOUS BY DEFAULT: every lifecycle component (T1-T4 sends, winback, grid updates, waiver
   state transitions, expiry sweeps, variant rotation) runs unattended. An email that needs a
   human to send it is a design defect. Ashley's no-show mark is an OPERATING input, not an
   escalation. Agent-owned deadlines: the system acts at T+24h/T+1h/5pm itself.
2. CLOSED-LOOP EVIDENCE: every autonomous action writes verifiable evidence at act time
   (email_sends rows, campaign_touches, GA4 events, change-log entries) - auditable in the
   Kindred grid + weekly scorecard without asking anyone. A verifier/spotcheck path must exist
   (the grid IS the audit surface; drill-down = the closed loop).
3. SINGLE-UPDATE / SINGLE-INQUIRY: Jarred receives ONE batched update of all changes (the weekly
   scorecard digest + launch reports) and ONE batched inquiry containing ONLY decisions that are
   genuinely his (money, parent-facing copy approval, clickwrap, deploys, bind/pay/sign class).
   No drip questions. The plan's decision list is that single inquiry - number it, one line each.
4. HARD GATES ONLY WHERE THEY BELONG: Tier 2 gates (copy, clickwrap, budget, prod deploy,
   Brightwheel money) stay human. Everything else self-heals: send failures retry, stuck states
   sweep, anomalies triage to the owning agent (#biz-gm-ads), NEVER to Jarred's inbox
   (feedback_no_automated_performance_emails_to_jarred).
5. KILL SWITCHES, NOT PERMISSION SLIPS: every automated loop ships with a one-flag disable
   (env var / D1 config row) so intervention is possible without being required.
The SYNTHESIZER must include a "HOOTL Governance" section in MASTER-PLAN.md mapping every
component to: autonomy class, evidence trail, escalation target, kill switch. The COUNSEL
dossier must list HOOTL-compliance as a scored proposal.
