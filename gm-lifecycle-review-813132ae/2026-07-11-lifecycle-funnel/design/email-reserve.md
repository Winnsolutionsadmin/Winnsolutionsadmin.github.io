# DESIGN: T1 "Reserve Your Space" lifecycle email (2026-07-11)

Lane: the T1 email in the lifecycle funnel. This is the first automated nurture message after a
family lands on the waitlist without reserving. It reuses the EXISTING gm-waitlist email machinery
end to end (transport, template chrome, hero-photo style, suppression/CAN-SPAM, open+click
tracking, the per-family engagement ledger). Nothing here is a new mailer; it is a new
`CAMPAIGNS` registry template (two cohort variants) plus the copy. All ground facts from
`ground/email-infra.md` (template + tracking) and `ground/waiver-package.md` (OPEN ENROLLMENT cohort).

No em dashes. No licensing language anywhere. "Fee waived" only ever appears with its condition in
the same sentence. Team voice, never signed Jarred.

---

## 0. Trigger + the two cohorts (what fires this)

Directive T1 (CONTEXT-PACK2): **paid waitlist fee + NO tour done -> send "Reserve Your Space"
within 24h** (America/Los_Angeles). The lane also requires a second framing for families who
reached the waitlist through the OPEN ENROLLMENT / tour-waiver door and therefore have NOT paid a
fee. So T1 ships as TWO registry entries sharing one copy scaffold, tracked independently
(directive item 4 = the waiver campaign converts comparatively vs the standard flow):

| Variant | Registry id | Who | Fee state | Framing shift |
|---|---|---|---|---|
| **A - standard fee-paid** | `lifecycle-t1-reserve` | paid the $65 waitlist fee, no tour, not reserved | `fee_paid = 1` | "Thank you for securing your priority" |
| **B - OPEN ENROLLMENT waiver** | `lifecycle-t1-reserve-openenroll` | reached the waitlist via a waiver (toured, fee waived), not reserved | `fee_paid = 0`, `tour_waivers.waiver_state = 'waived'` | "Your space is secured, your waitlist fee was waived when you toured" |

Both variants have ONE job: move the family into the reserve flow (pick a start month up to a year
ahead, sign the enrollment agreement, remit the deposit, space held). Both point the CTA at the
tracked reserve link. Neither offers a tour (variant B already toured; variant A's tour nudge is
T3, not T1).

**Cohort selection is by audience WHERE, not by runtime branching** (cleaner, and gives variant B
its own `campaign_sends` ledger for the independent read). Audience sketches for the build lane
(exact predicates + the per-family "due at fee_paid_at + <window>" timing belong to the
waitlist-flow / lifecycle-cron lane; this lane owns the copy + template shape):

```
-- Variant A (standard):
a.fee_paid = 1
AND a.status = 'waiting'
AND a.deposit_paid = 0                          -- not reserved
AND a.reserve_agreement_accepted_at IS NULL     -- reserve flow not started
AND NOT EXISTS (SELECT 1 FROM tour_bookings tb  -- no tour done/booked
                 WHERE lower(tb.visitor_email) = lower(a.parent1_email)
                   AND tb.status IN ('pending_calendar','confirmed'))
AND a.fee_paid_at <= datetime('now','-1 hour')  -- fired shortly after fee, inside the 24h target
AND a.parent1_email IS NOT NULL AND TRIM(a.parent1_email) != ''
AND a.portal_token IS NOT NULL AND a.portal_token != ''
AND NOT EXISTS (SELECT 1 FROM campaign_sends cs WHERE cs.campaign_id = ? AND cs.application_id = a.id)
AND NOT EXISTS (SELECT 1 FROM email_suppressions s WHERE s.email = LOWER(TRIM(a.parent1_email)))

-- Variant B (OPEN ENROLLMENT): same, but replace the fee/tour lines with
a.fee_paid = 0
AND EXISTS (SELECT 1 FROM tour_waivers tw
             WHERE tw.application_id = a.id AND tw.waiver_state = 'waived')
AND a.status = 'waiting'
AND a.deposit_paid = 0
AND a.reserve_agreement_accepted_at IS NULL
-- (no tour-booking exclusion: variant B toured by definition)
```

The capacity gate already in `runCampaignWave` (`bandReservableInWindow`) applies unchanged, so T1
never invites a family whose room has no reservable slot in the forward window (the broken-calendar
lesson, made structural). "Trying / no DOB" families are included and land on the portal's friendly
"once your little one arrives" state, exactly as the existing campaigns do.

---

## 1. Email kind, suppression, CAN-SPAM (all auto-handled)

- **`kind: 'campaign_lifecycle_t1_reserve'`** (variant A) and
  **`kind: 'campaign_lifecycle_t1_reserve_openenroll'`** (variant B). Both are MARKETING kinds.
- They are NOT in `TRANSACTIONAL_KINDS` and NOT in `INTERNAL_KINDS`, so `sendEmail`'s allowlist
  suppression gate covers them automatically (`ground/email-infra.md` s4): a suppressed address
  writes a `provider='suppression_gate', status='suppressed'` row and nothing delivers. Do NOT add
  these kinds to `TRANSACTIONAL_KINDS`. This is promotional mail to applicants and must stay
  suppression-gated (CONTEXT-PACK2 CAN-SPAM rule).
- Unsubscribe is automatic: `sendEmail` appends the footer "Prefer not to get emails from us?
  Unsubscribe" plus the two `List-Unsubscribe` / `List-Unsubscribe-Post` RFC 8058 headers to every
  non-internal email. The physical address `750 N Street, Sacramento CA 95814` is already in the
  `emailShell` footer default. So CAN-SPAM (unsubscribe + physical address + suppression) is
  satisfied by reusing the machinery; this template adds nothing for it.
- Quiet-window note for the lifecycle-cron lane: keep the existing 72h anti-fatigue discipline the
  winback sweep uses so a family who just got a receipt or verification email is not stacked.

---

## 2. Subject lines + preheader

Team voice, personalized with `childName(child_first)` (falls back to "your child"). Under ~55
chars where possible so mobile does not truncate.

**Variant A - standard fee-paid (pick one; default = option 1):**
1. `Reserve ${child}'s space at Growing Mindfully`   <- default, calm, matches the reserve family
2. `Your waitlist spot is secured. Now reserve ${child}'s start date`
3. `${child}'s spot is ready to reserve`

**Variant B - OPEN ENROLLMENT waiver (default = option 1):**
1. `Reserve ${child}'s space at Growing Mindfully`   <- default (identical goal, keeps the family series consistent)
2. `You're on the waitlist. Now reserve ${child}'s start date`
3. `Welcome to Growing Mindfully. Let's reserve ${child}'s space`

`childName(child, true)` (capitalized) is available for sentence-start use, as the reserve-abandon
builder does.

**Preheader** (hidden preview text; the shell has no preheader slot, so it goes as the FIRST node
of `bodyInner`, a visually-hidden div, before the trust line):
```
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;height:0;width:0">
  {PREHEADER}&#8203;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;
</div>
```
- Variant A preheader: `You've secured your priority on our waitlist. Now pick your start date and lock in ${child}'s space, up to a year ahead.`
- Variant B preheader: `Your space on our waitlist is secured. When you're ready, reserve ${child}'s start date and lock it in.`
(The zero-width padding chars stop Gmail from pulling body copy into the preview after the
preheader. Keep them literal, no em dashes.)

---

## 3. Picture (the hero) - matches the existing "picture style"

The existing reserve templates use the community-photo hero at 524px, `border-radius:6px`, preceded
by the small uppercase trust line (`ground/email-infra.md` s3b). T1 keeps that pattern.

- **Variant A hero:** `https://www.growingmindfully.org/assets/community.jpg`
  (`alt="Children smiling together on the Capitol lawn"`). This is the canonical reserve-invite
  hero; T1 is the automated sibling of `reserve-early-access`, so uniformity is correct here.
- **Variant B hero:** `https://www.growingmindfully.org/assets/joy.jpg`
  (`alt="A child laughing during play at Growing Mindfully"`). A distinct-but-on-brand hero gives
  the OPEN ENROLLMENT cohort a subtly separate visual identity (directive item 4, tracked
  independently) without leaving the brand system. Both are live 524px-quality assets shipped
  2026-07-08. If Jarred prefers strict uniformity, variant B can use `community.jpg` too; default
  above.
- Trust line above the hero:
  - Variant A: `Family founded since 2018` (verbatim existing line).
  - Variant B: `Open enrollment · your space is secured` (renders uppercase via
    `text-transform:uppercase`; ties the email to the "OPEN ENROLLMENT!" ad the family came from =
    message match, no new claim).

T4 is the variant that must use a DIFFERENT picture from the shared community hero; T1 sits at the
front of the series so the community hero is the right anchor here.

---

## 4. Full HTML structure + verbatim copy

Both variants render through `emailShell(heading, bodyInner, ctaText, urls.clickUrl, undefined, afterCta)`
(the default footer already carries `750 N Street, Sacramento CA 95814`). The engine appends the
open pixel and wraps the CTA URL; the builder just supplies `urls.clickUrl` as the `href`.

Shared scaffolding pieces (identical to campaigns.ts):
```
const heroImg = `<img src="{HERO_URL}" alt="{HERO_ALT}" width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">`;
const kicker  = `<p style="text-align:center;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#6F7F84;margin:0 0 14px">{TRUST_LINE}</p>`;
const preheader = `<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;height:0;width:0">{PREHEADER}&#8203;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;&#847;</div>`;
```

### Variant A - standard fee-paid

- **heading (shell `<h2>`):** `Reserve your space, whenever you're ready`
- **bodyInner:**
```
${preheader}${kicker}${heroImg}
<p>Hi ${parent}!</p>
<p>Thank you for securing ${child}'s place on our waitlist. Your priority date is locked in, and we're so glad your family is with us. :)</p>
<p>There's a next step that gives families real peace of mind: you can now reserve ${child}'s space for a specific start month, up to a year in advance. Pick the month you'd like to begin, sign your enrollment agreement, and remit your deposit, and the space is <strong>held for you</strong>. No more wondering whether a spot will be open when you need it.</p>
<p>One honest heads up: with the return-to-office push downtown, demand has jumped and start months are filling quickly. Reserving now is the surest way to hold the month that works for you.</p>
<p>Your private family link is below. No account or password needed, it takes you straight to your page and it only takes a couple of minutes.</p>
<p>If anything is unclear or you'd just like to talk it through, reply here anytime. We're happy to help.</p>
<p>With love,<br>The Growing Mindfully team</p>
```
- **ctaText:** `Reserve ${child}'s space` (when child == "your child" -> `Reserve your child's space`)
- **afterCta:**
```
<p style="text-align:center;font-size:12px;color:#9a9590;margin:14px 0 0">This link is unique to your family. If now is not the right time, no action is needed and your place on the waitlist is unchanged.</p>
```

### Variant B - OPEN ENROLLMENT waiver cohort (no fee paid)

Only the gratitude/fee frame changes. The reserve invite, heads-up, link language, sign-off,
and afterCta are identical to variant A. The fee reference is conditioned in-sentence.

- **heading:** `Reserve your space, whenever you're ready`
- **bodyInner:**
```
${preheader}${kicker}${heroImg}
<p>Hi ${parent}!</p>
<p>Thank you for touring Growing Mindfully and joining our waitlist. Your space is secured, and because you completed a tour during open enrollment, your waitlist fee was waived. :)</p>
<p>There's a next step that gives families real peace of mind: you can now reserve ${child}'s space for a specific start month, up to a year in advance. Pick the month you'd like to begin, sign your enrollment agreement, and remit your deposit, and the space is <strong>held for you</strong>. No more wondering whether a spot will be open when you need it.</p>
<p>One honest heads up: with the return-to-office push downtown, demand has jumped and start months are filling quickly. Reserving now is the surest way to hold the month that works for you.</p>
<p>Your private family link is below. No account or password needed, it takes you straight to your page and it only takes a couple of minutes.</p>
<p>If anything is unclear or you'd just like to talk it through, reply here anytime. We're happy to help.</p>
<p>With love,<br>The Growing Mindfully team</p>
```
- **ctaText:** `Reserve ${child}'s space`
- **afterCta:** identical to variant A.

Copy notes:
- The one fee sentence in B is fully conditioned ("because you completed a tour during open
  enrollment, your waitlist fee was waived"), satisfying the disclosure rule. It never says "free".
- Neither variant states a dollar figure in the email body; the fee amount lives in the clickwrap /
  LP, not this nurture email. (The 7/11 "dollars allowed" supersession is scoped to AD copy; it does
  not require putting dollars in T1, and leaving them out keeps the email calm.)
- The reserve flow's own $45 enrollment fee is NOT mentioned in T1 (that waiver is a T3/T4 hook and
  is still un-automated; do not surface it here). T1 stays about reserving the space.

---

## 5. CTA -> reserve flow, with the wrapped tracking link

- Template fields: `portalIntent: 'reserve'`, `tourCta: false`, `leadAudience: false`.
- At send time `runCampaignWave` mints a `campaign_sends.token`, sets
  `urls.clickUrl = ${base}/c/${token}`, and the builder uses it as the CTA `href`. The engine then
  appends the open pixel `pixelImg(${base}/c/${token}/o.gif)` to the HTML.
- `GET /c/:token` stamps `clicked_at` / `click_count` and 302s to
  `/portal/<portal_token>?utm_source=email&utm_medium=email&utm_campaign=<id>&gm_intent=reserve`.
  Because `portalIntent='reserve'`, the portal auto-opens "Secure Your Space" on arrival (Jarred
  2026-07-05: clickers should land on the reserve step immediately). This IS "CTA to the reserve
  flow with a wrapped tracking link."
- No raw `waitlist.growingmindfully.org` or `/portal/` URL appears in the template. Only
  `urls.clickUrl`. That guarantees every click is measured and feeds the Kindred grid.

---

## 6. Tracking / grid integration (directive item 3)

Registering T1 as a `CAMPAIGNS` template (not a bespoke email.ts builder) is deliberate: it inherits
the whole tracking substrate for free.
- `campaign_sends` per family: `sent_at`, `delivered_at` (Postmark webhook), `opened_at`/`open_count`
  (pixel), `clicked_at`/`click_count` (wrapped link). `UNIQUE(campaign_id, application_id)` = T1 can
  never double-send a family.
- `campaignFunnel(db, 'lifecycle-t1-reserve')` gives the 10-stage report
  (sent -> delivered -> opened -> clicked -> ... -> reserved) with per-family drill-down and
  reserved-value USD, served at `/api/crm/campaigns/:id/report` = the exact feed the Kindred campaign
  grid reads. Variant B has its own campaign id, so its numbers are isolated for the head-to-head
  comparative read (directive item 4).
- Cell states map directly: no `clicked_at` = "received"; `clicked_at` but no reserve = "engaged, not
  converted"; `deposit_paid` after click = "converted." The verified-click heuristic (>60s after
  send, non-scanner UA) already filters employer link-detonation.
- GA4: the reserve conversions that matter (`gmwl_reserve_confirmed`, deposit) already fire from the
  portal via server Measurement Protocol; T1's job is the email-side send/open/click ledger. No new
  GA4 event is required from the email itself, though the lifecycle lane may add a
  `gmwl_lifecycle_t1_click` funnel_event if per-stage GA4 attribution is wanted later.

---

## 7. Automation seam (flag for the lifecycle-cron lane, not this lane's build)

The existing `CAMPAIGNS` engine is MANUAL (YubiKey-tapped waves). CONTEXT-PACK2 wants T1 to fire
automatically within 24h of the family landing on the waitlist. Reconcile by: keep the T1 template
in the `CAMPAIGNS` registry (for tracking + grid + suppression), and have the NEW per-family
lifecycle leg on the existing `*/10` cron dispatcher call the same send path per due family
(America/Los_Angeles conversion for the 24h window), writing the same `campaign_sends` rows. That
keeps one ledger and one funnel report whether a send was cron-fired or hand-fired. Do NOT register a
new cron trigger (account at the 5-trigger limit); piggyback `*/10` exactly like
`runReservationReminders`. The idempotency key is the existing `UNIQUE(campaign_id, application_id)`.
The DB/cron lane owns the leg; this lane hands them the template + audience + kind above.

---

## 8. Hard-rule checklist (verify before build ships)

- [x] No em dashes anywhere in copy or markup (hyphens/colons/periods only).
- [x] No licensing language (no "Lic. #", no CDSS citation, nothing licensing-related).
- [x] Every "fee waived" reference (variant B only) carries its condition in the same sentence.
- [x] No dollar figures in the email body (not required by the 7/11 ad-copy supersession).
- [x] Team voice, "With love, The Growing Mindfully team" - never signed Jarred.
- [x] Marketing kind -> stays suppression-gated (not added to TRANSACTIONAL_KINDS).
- [x] Unsubscribe footer + List-Unsubscribe headers + physical address = auto via sendEmail/emailShell.
- [x] CTA is the wrapped `/c/:token` link only; no raw portal URL; `gm_intent=reserve`.
- [x] Parent-facing copy = Tier 2 Jarred gate before any live send.

---

## 9. Files this design touches at build time
- `~/Projects/gm-waitlist/src/server/campaigns.ts` - add two `CAMPAIGNS` registry entries
  (`lifecycle-t1-reserve`, `lifecycle-t1-reserve-openenroll`) using the scaffold + copy above.
- `~/Projects/gm-waitlist/src/server/index.ts` - the lifecycle-cron leg on `*/10` (separate lane).
- No `email.ts` change needed (reuses `emailShell`, `childName`, suppression, footer).
- No new migration for T1 itself (uses existing `campaign_sends`); the waiver cohort depends on the
  `tour_waivers` table from migration 050 (waiver-package lane).

---

## 10. HOOTL governance (required per CONTEXT-PACK2 mandate)

Mapping T1 to the four HOOTL axes the SYNTHESIZER's MASTER-PLAN section expects for every component.

- **Autonomy class: AUTONOMOUS by default.** The send fires on the agent-owned 24h deadline via the
  `*/10` sweep leg (TZ America/Los_Angeles), no human in the loop. An email that needed a person to
  press send would be a design defect. The one human touch is the ONE-TIME Tier 2 copy sign-off
  before go-live (section 8), not a per-send approval.
- **Evidence trail, written at act time (closed loop, auditable without asking anyone):** each send
  writes one `emails` row (kind, provider, status), one `campaign_sends` row
  (token, `sent_at`, `delivered_at` via Postmark webhook, `opened_at`/`open_count`,
  `clicked_at`/`click_count`), and a `lifecycle_sends(application_id, stage='t1_reserve')`
  idempotency row (the `d1-schema.md` side-table pattern). The Kindred campaign grid + the
  `campaignFunnel()` report ARE the verifier/spotcheck surface; the per-family drill-down is the loop.
- **Escalation target: never Jarred's inbox.** Delivery self-heals Postmark -> Resend -> capture (a
  live family's send is never lost); bounces/complaints auto-suppress via the delivery webhooks;
  persistent send errors land in `error_log` and triage to `#biz-gm-ads`
  (feedback_no_automated_performance_emails_to_jarred). Jarred receives only the batched weekly
  scorecard, not per-send noise.
- **Kill switch (intervention possible without being required):** gate the sweep leg behind an env
  flag, default DARK, e.g. `LIFECYCLE_T1_ENABLED='0'` (mirrors `WINBACK_ENABLED` / `RESERVE_ENABLED`
  discipline). Flipping it to `'0'` halts all T1 sends instantly with no code change. The shared
  daily cap + 72h quiet window (section 1) are secondary brakes.

---

## 11. Launch-ordering dependencies (surface in the single inquiry)

Hard gates the plan must sequence BEFORE T1 goes live. These are launch-ordering facts, not copy
issues, flagged so a clicker never hits a dead end.

1. **`RESERVE_ENABLED` is prod-DARK ('0') today** (`ground/tours-fees-code.md` section 4). T1's entire
   CTA lands the family in Secure Your Space via `gm_intent=reserve`; with reserve dark, the deposit
   gate returns `403 reserve_disabled` and the family hits a wall. **T1 MUST NOT enable before
   `RESERVE_ENABLED='1'`.** This is the single most important ordering gate for this email.
2. **Two campaign rows seeded** (`lifecycle-t1-reserve`, `lifecycle-t1-reserve-openenroll`) so the
   grid renders two columns and the two `campaignFunnel()` reports stay isolated for the head-to-head
   read (directive item 4).
3. **Parent-facing copy Tier 2 sign-off** (both bodies, all six subjects, both preheaders) before any
   live send. This is the ONLY per-launch human gate; it belongs in the plan's single batched inquiry,
   not as a drip question.
4. **Clickwrap is NOT a T1 blocker.** T1 only invites; the deposit ceremony uses the existing
   `reserve-agreement-v3.ts`. The `waitlist-v2.ts` counsel item that blocks fee-DEFERRING waiver
   variants gates the waiver cohort's UPSTREAM join, not T1's send.
