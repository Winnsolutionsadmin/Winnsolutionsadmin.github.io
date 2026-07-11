# Design: T4 post-tour promo email ("reserve by 5PM, $45 enrollment fee waived")

Lane: the T4 lifecycle email. Fires 1h after a booked tour's scheduled END time, no-show gated.
Everything here is COPY + HTML + the send/tracking shape. Backend triggers (runTourFollowups, the
no-show flag, the enrollmentFeeDue choke point) are owned by the tours-fees-code / waitlist-flow
lanes and are referenced, not rebuilt. No em dashes. Nothing licensing-related. Team voice.

Source ground: `ground/enrollfee-noshow.md` (fee call sites, tour END time, no-show marking),
`ground/email-infra.md` (transport, emailShell chrome, picture style, suppression, cron),
`ground/waiver-package.md` (condition-in-same-asset rule, "free tour" ban, clickwrap v-bump).

---

## 0. BLOCKERS and gates (read first, before any live send)

1. **The $45 waiver plumbing does NOT exist yet.** `ENROLLMENT_FEE_USD = 45` is bundled into the
   deposit PaymentIntent at 7 call sites (`ground/enrollfee-noshow.md` Part A). Today the reserve
   flow bills the full $45 for everyone. This email PROMISES the fee is waived. Do NOT send T4 live
   until the `enrollmentFeeDue(row, waiverFlag)` choke point ships AND the reserve flow reads a
   time-boxed waiver flag for this family. Sending "$45 waived" while site 2 (`index.ts:2192`)
   still charges it = an unavailable-offer / false-promise exposure. Copy can be Jarred-approved now;
   the SEND is gated on the plumbing.
2. **Clickwrap / agreement mismatch.** The reserve clickwrap + DocuSign agreement state the $45 is
   "non-refundable regardless" (`overlay.js:2716/2722/3593/3594`, `agreement-template.ts`,
   `terms/reserve-agreement-v3.ts`, `docusign.ts:117` hardcodes `45`). A waived family signing that
   text signs a fee they were not charged. Requires a counsel-reviewed `reserve-agreement-v4.ts`
   (SHA-256 version bump) + folding `docusign.ts:117` into the choke point. Tier-2, Jarred + counsel.
3. **CAN-SPAM: this is MARKETING mail.** Keep `kind:'lifecycle_t4_post_tour'` OUT of
   `TRANSACTIONAL_KINDS`. The allowlist suppression gate in `sendEmail` (email.ts 182-195) then
   auto-checks `email_suppressions` and auto-appends the unsubscribe footer + RFC 8058 headers. The
   physical address (`750 N Street, Sacramento CA 95814`) is already in the shell footer. Do nothing
   extra; just do not reclassify it as transactional.
4. **No-show gate is the trigger.** T4 sends only when the tour is marked attended (or unmarked, per
   the null-default policy in `ground/enrollfee-noshow.md` C1.4) and NOT `no_show`. That marking
   surface must be built first (migration 050 `attendance` column + Kindred toggle). T4 has no
   backing signal until it exists.
5. **Parent-facing copy = Tier 2.** This whole email is Jarred-gated before any send.

---

## 1. Trigger and send shape (context, not this lane's build)

- Fire when a `tour_bookings` row has `status='confirmed'`, `attendance != 'no_show'`, and
  `datetime(slot_end) + 1 hour <= now` (America/Los_Angeles). `slot_end` is stored per booking
  (`043_tour_booking.sql:34`), so this is a pure WHERE clause, no duration math.
- Piggyback the existing `*/10 * * * *` cron leg via a new `runTourFollowups(db, env, baseUrl)`
  mirroring `runReservationReminders`. Account is at the 5-cron limit; do NOT add a trigger.
- Idempotent per booking: a new `tour_followups(booking_id, stage, sent_at)` side table (same idiom
  as `reservation_reminders`), one T4 send per booking ever.
- **Send through the campaign tracking substrate** so it lands in the Kindred grid + `campaignFunnel`:
  write a `campaign_sends` row (`campaign_id='lifecycle-t4-post-tour'`, `application_id=<app id>`,
  minted `token`), route the CTA through the tracked `/c/:token` click redirect, append the open
  pixel `/c/:token/o.gif`. This reuses the exact open+click ledger the grid lane consumes.
- Family match: T4 only makes sense for a family who can RESERVE, i.e. has an `applications` row.
  Token-linked bookings carry `subject_key` -> use that application. Email-only bookings match
  `lower(visitor_email)` against `applications.parent1_email`; NO match = no application = no deposit
  to waive = do not send T4 (they get the acquisition/tour-waiver path instead). See
  `ground/enrollfee-noshow.md` gap #1.

---

## 2. The DIFFERENT picture (Jarred's explicit T4 requirement)

Every other campaign email uses `community.jpg` (kids on the Capitol lawn). T4 is the emotional peak:
the family just stood in the classrooms an hour ago. Use a warm in-the-moment image they can now
attach to a real memory.

- **Recommended:** `https://www.growingmindfully.org/assets/joy.jpg` (live, shipped 2026-07-08).
- **Alternates (all live, ~220-350KB):** `play.jpg`, `walk.jpg`, `seated.jpg`, `breathe.jpg`,
  `hero.jpg`. Pick whichever reads warmest at 524px.
- Same markup as the community-photo hero pattern, just a different `src`:
  ```html
  <img src="https://www.growingmindfully.org/assets/joy.jpg"
       alt="A child playing and laughing at Growing Mindfully"
       width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">
  ```
- **Verify the alt matches the actual asset before ship** (I have not opened the image). Keep alt
  warm, literal, and free of any claim.

---

## 3. Subject lines (x3) + preheader

Condition-in-same-asset rule (`waiver-package.md` 1f) applies to subjects too: the "$45 waived"
promise NEVER appears without the "reserve by 5PM today" condition in the same line.

**Today-deadline subjects:**
1. `Reserve {Child}'s space by 5PM today and we'll waive the $45 enrollment fee`
2. `It was so good to meet you: reserve by 5PM today, $45 enrollment fee waived`
3. `{Child}'s space is open: reserve by 5PM today and the $45 enrollment fee is on us`

`{Child}` = `childName(child_first)`; when null it resolves to "your child", so subject 1 reads
"Reserve your child's space by 5PM today and we'll waive the $45 enrollment fee".

**Preheader (hidden preview line, one per send):**
> Thank you for touring with us today. Reserve {child}'s space before 5:00 PM Pacific and the
> one-time $45 enrollment fee is waived. After 5 it simply applies, no penalty.

Rendered as a hidden span at the very top of `bodyInner` (standard preheader technique):
```html
<span style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">Thank you for touring with us today. Reserve by 5:00 PM Pacific and the one-time $45 enrollment fee is waived. After 5 it simply applies, no penalty.</span>
```

---

## 4. Body copy (rendered reading, today-deadline version)

Heading (shell `<h2>`): **Reserve by 5PM today, enrollment fee waived**

> Hi {parent}!
>
> Thank you so much for touring Growing Mindfully today. It was a joy to show you the classrooms and
> to meet you in person :)
>
> We would love to save {child}'s space. As a thank you for coming to see us, here is something just
> for today: if you reserve by **5:00 PM Pacific this evening**, we will waive the one-time **$45
> enrollment fee**. Reserving takes about two minutes: pick {child}'s start month, sign the
> enrollment agreement, and place your deposit to lock it in.
>
> There is no pressure and no penalty either way. If 5:00 PM comes and goes, nothing is lost: the
> $45 enrollment fee simply applies as usual, your tour still counts, and your place is exactly where
> it is. We just wanted to send a small welcome for taking the time to visit.
>
> Your private link is below. No account or password needed, it takes you straight to your page.
>
> If you have any questions, or would like to talk through rates or start dates, just reply to this
> email... we are happy to help.
>
> With love,
> The Growing Mindfully team

CTA button: **Reserve {child}'s space** -> tracked `/c/:token` (gm_intent=reserve).

afterCta (muted line below the button, carries the real dated deadline for honesty):
> This $45 enrollment-fee waiver is good through 5:00 PM Pacific today, {weekday}, {Month} {D}. After
> that the fee applies normally and nothing about your spot changes. This link is unique to your
> family.

`{weekday}, {Month} {D}` is computed at send time in America/Los_Angeles (e.g. "Friday, July 11").
Printing the actual date is deliberate: an honest, checkable deadline is the opposite of a fake
countdown.

---

## 5. Countdown framing WITHOUT dark patterns (the discipline)

Jarred asked for countdown urgency without dark patterns. The design achieves urgency through ONE
real, checkable fact and full disclosure of the downside, nothing manufactured:

- **DO:** name a real deadline with the actual date + timezone (5:00 PM PT, {dated}). It is a true
  same-day offer tied to the tour they just took.
- **DO:** state plainly what happens after 5PM (the fee applies, tour still counts, place unchanged,
  no penalty). Removing the fear is what keeps it honest.
- **DO NOT:** animated countdown-timer GIF, "only 2 spots left", "hurry", "act now", "final chance",
  red banners, or any scarcity claim about seats (capacity is a live forecast, never asserted in
  copy). None appear here.
- **DO NOT:** re-send a "deadline extended" chaser (that trains families the deadline is fake). T4 is
  one send per booking. If Jarred later wants a T4b nudge, it must be a genuinely new, dated window.
- The waiver flag itself must be **time-boxed server-side** to the same 5PM PT deadline, so the
  offer the email states is exactly the offer the reserve flow honors. If a family clicks at 5:05 PM,
  the reserve deposit computes the normal $45 and the copy already told them that would happen.

---

## 6. Deadline-edge variant (mandatory anti-coercion guard)

Problem: T4 sends 1h after tour END. A 10:00 AM tour ends 10:30, sends ~11:30 AM, and "5PM today"
gives ~5.5 hours of honest runway. A 3:00 PM tour ends 3:30, sends ~4:30 PM, and "5PM today" leaves
~30 minutes. A 30-minute same-day deadline IS a dark pattern (impossible runway dressed as a favor).

**Rule (compute at send time, America/Los_Angeles):**
- Let `sendAt` = the moment T4 is dispatched (~slot_end + 1h, plus up-to-10-min cron lag).
- If `sendAt` is at or before **1:00 PM PT** -> deadline = **5:00 PM PT today** (>= ~4h runway). Use
  the section 4 "today" copy.
- If `sendAt` is after **1:00 PM PT** -> deadline = **5:00 PM PT the next calendar day**. Use the
  "tomorrow" copy below. (Optional refinement: skip to the next weekday if the office is closed the
  next day; default is next calendar day, Jarred's call.)

**Tomorrow-deadline swaps** (only the deadline words change; everything else identical):

- Heading: **Reserve by 5PM tomorrow, enrollment fee waived**
- Subject 1: `Reserve {Child}'s space by 5PM tomorrow and we'll waive the $45 enrollment fee`
- Subject 2: `It was so good to meet you: reserve by 5PM tomorrow, $45 enrollment fee waived`
- Subject 3: `{Child}'s space is open: reserve by 5PM tomorrow and the $45 enrollment fee is on us`
- Preheader: "...Reserve by 5:00 PM Pacific tomorrow and the one-time $45 enrollment fee is waived..."
- Body sentence 2: "...here is something to say thank you for visiting: if you reserve by **5:00 PM
  Pacific tomorrow**, we will waive the one-time **$45 enrollment fee**..."
- Body sentence 3: "...If 5:00 PM tomorrow comes and goes, nothing is lost..."
- afterCta: "This $45 enrollment-fee waiver is good through 5:00 PM Pacific tomorrow, {weekday},
  {Month} {D}. After that the fee applies normally..."

Implementation note: keep ONE builder that takes a `deadline: { when: 'today'|'tomorrow', label:
string }` arg and substitutes the two words + the dated afterCta line, so the two variants can never
drift apart. Do NOT hand-maintain two templates.

---

## 7. CTA + tracking (updates all databases)

- **Click:** CTA href = the minted `/c/:token` redirect (campaigns.ts pattern). It stamps
  `campaign_sends.clicked_at`/`click_count`, then 302s to `/portal/<portal_token>?utm_source=email&
  utm_medium=email&utm_campaign=lifecycle-t4-post-tour&gm_intent=reserve`. `gm_intent=reserve` opens
  Secure Your Space immediately on arrival (existing behavior, Jarred 2026-07-05).
- **Open:** append the `/c/:token/o.gif` pixel (via `pixelImg()`); stamps `opened_at`/`open_count`.
- **Waiver eligibility is derived SERVER-SIDE, never from a URL param.** When the portal reserve flow
  loads for this application, the deposit computation checks the family's time-boxed waiver flag
  (set by the T4 send, expiring at the stated 5PM PT deadline) through `enrollmentFeeDue`. Do not put
  a forgeable `?waive=1` in the link. The email states the offer; the server enforces it.
- **Delivery:** the Postmark `gm_send_token` Metadata passthrough stamps `campaign_sends.delivered_at`
  via the existing webhook. Bounces/complaints auto-suppress. No new webhook work.
- **Grid + funnel:** because it writes a `campaign_sends` row, T4 appears automatically in
  `campaignFunnel('lifecycle-t4-post-tour')` and the Kindred campaign grid (received / engaged /
  converted). Conversion = the family's subsequent `gmwl_reserve_confirmed`, already tracked.
- **GA4 (optional, "all databases"):** a server MP `gmwl_t4_sent` event on send keeps GA4 aligned
  with D1; email open/click stay D1-only (that is the system's existing contract). Not required for
  the promo to work; flag for the ga4-ads lane if Jarred wants T4 volume in GA4.

---

## 8. Builder (TypeScript, matches the campaigns.ts template idiom)

Drop-in as a `CAMPAIGNS` registry entry OR as the render half of `runTourFollowups`. Mirrors the
existing `build(row, urls)` signature; adds a `deadline` arg for the today/tomorrow variant.

```ts
// lifecycle-t4-post-tour: fired by runTourFollowups, 1h after tour END, no-show gated.
// kind is MARKETING -> stays suppression-gated + gets the unsubscribe footer automatically.
// DO NOT send live until enrollmentFeeDue() waives the $45 in the reserve deposit (see BLOCKERS).
function buildPostTourPromoEmail(
  row: { child_first: string | null; parent1_first: string | null },
  urls: { clickUrl: string },                       // the /c/:token tracked link
  deadline: { when: 'today' | 'tomorrow'; label: string }, // label e.g. "Friday, July 11"
): { subject: string; html: string } {
  const child = escapeHtml(childName(row.child_first));          // null -> "your child"
  const childPoss = child === 'your child' ? "your child's" : `${child}'s`;
  const parent = escapeHtml((row.parent1_first || '').trim() || 'there');
  const when = deadline.when; // 'today' | 'tomorrow'

  const subject = `Reserve ${childPoss} space by 5PM ${when} and we'll waive the $45 enrollment fee`;

  const preheader = `<span style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">Thank you for touring with us today. Reserve by 5:00 PM Pacific ${when} and the one-time $45 enrollment fee is waived. After 5 it simply applies, no penalty.</span>`;

  // THE DIFFERENT PICTURE (verify alt vs asset before ship):
  const heroImg = `<img src="https://www.growingmindfully.org/assets/joy.jpg" alt="A child playing and laughing at Growing Mindfully" width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">`;
  const foundedLine = `<p style="text-align:center;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#6F7F84;margin:0 0 14px">Family founded since 2018</p>`;

  const body = `${preheader}${foundedLine}${heroImg}
<p>Hi ${parent}!</p>
<p>Thank you so much for touring Growing Mindfully today. It was a joy to show you the classrooms and to meet you in person :)</p>
<p>We would love to save ${childPoss} space. As a thank you for coming to see us, here is something just for ${when}: if you reserve by <strong>5:00 PM Pacific ${when === 'today' ? 'this evening' : 'tomorrow'}</strong>, we will waive the one-time <strong>$45 enrollment fee</strong>. Reserving takes about two minutes: pick ${childPoss} start month, sign the enrollment agreement, and place your deposit to lock it in.</p>
<p>There is no pressure and no penalty either way. If 5:00 PM ${when === 'today' ? '' : 'tomorrow '}comes and goes, nothing is lost: the $45 enrollment fee simply applies as usual, your tour still counts, and your place is exactly where it is. We just wanted to send a small welcome for taking the time to visit.</p>
<p>Your private link is below. No account or password needed, it takes you straight to your page.</p>
<p>If you have any questions, or would like to talk through rates or start dates, just reply to this email... we are happy to help.</p>
<p>With love,<br>The Growing Mindfully team</p>`;

  const cta = child === 'your child' ? "Reserve your child's space" : `Reserve ${childName(row.child_first)}'s space`;

  const afterCta = `<p style="text-align:center;font-size:12px;color:#9a9590;margin:14px 0 0">This $45 enrollment-fee waiver is good through 5:00 PM Pacific ${when}, ${escapeHtml(deadline.label)}. After that the fee applies normally and nothing about your spot changes. This link is unique to your family.</p>`;

  const heading = `Reserve by 5PM ${when}, enrollment fee waived`;
  const html = emailShell(heading, body, cta, urls.clickUrl, undefined, afterCta);
  return { subject, html };
}
```

Notes on the builder:
- No em dashes anywhere; the ":)" and "..." match the house voice; signed team, never Jarred.
- "$45 enrollment-fee waiver" and every "$45" hit carries its condition in the same sentence.
- Uses `emailShell` verbatim (same chrome as all system mail); the ONLY divergence from the existing
  campaign templates is the hero `src` (joy.jpg vs community.jpg) plus the preheader span.
- The `deadline` arg is the single source of the today/tomorrow difference (section 6).

---

## 9. Full rendered HTML (today variant, {parent}=Alex, {child}=Mia, deadline=Friday, July 11)

For Jarred's preview. This is `emailShell('Reserve by 5PM today, enrollment fee waived', body,
'Reserve Mia's space', '<clickUrl>', undefined, afterCta)` with the body from section 8. The
unsubscribe footer + List-Unsubscribe headers are appended by `sendEmail` after this (not shown).

```html
<div style="background:#eef1ea;padding:26px 12px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif">
  <div style="max-width:524px;margin:0 auto;background:#fffdf7;border-radius:16px;overflow:hidden;box-shadow:0 6px 26px rgba(40,35,25,.09);border:1px solid rgba(42,66,49,.06)">
    <div style="height:6px;background:linear-gradient(90deg,#9BB99E 0%,#6FB8B8 38%,#5FAEB6 64%,#7AA8C4 100%)"></div>
    <div style="padding:34px 38px;color:#2a2a28;line-height:1.62">
      <div style="text-align:center;margin-bottom:24px">
        <img src="https://www.growingmindfully.org/assets/wordmark.png" alt="Growing Mindfully" height="40" style="height:40px;width:auto;display:inline-block">
      </div>
      <h2 style="color:#2a4231;font-family:'Cormorant Garamond',Georgia,serif;margin:0 0 14px;font-size:25px;font-weight:600;line-height:1.18">Reserve by 5PM today, enrollment fee waived</h2>
      <span style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">Thank you for touring with us today. Reserve by 5:00 PM Pacific today and the one-time $45 enrollment fee is waived. After 5 it simply applies, no penalty.</span>
      <p style="text-align:center;font-size:12px;letter-spacing:0.14em;text-transform:uppercase;color:#6F7F84;margin:0 0 14px">Family founded since 2018</p>
      <img src="https://www.growingmindfully.org/assets/joy.jpg" alt="A child playing and laughing at Growing Mindfully" width="524" style="width:100%;height:auto;border-radius:6px;display:block;margin:0 0 18px">
      <p>Hi Alex!</p>
      <p>Thank you so much for touring Growing Mindfully today. It was a joy to show you the classrooms and to meet you in person :)</p>
      <p>We would love to save Mia's space. As a thank you for coming to see us, here is something just for today: if you reserve by <strong>5:00 PM Pacific this evening</strong>, we will waive the one-time <strong>$45 enrollment fee</strong>. Reserving takes about two minutes: pick Mia's start month, sign the enrollment agreement, and place your deposit to lock it in.</p>
      <p>There is no pressure and no penalty either way. If 5:00 PM comes and goes, nothing is lost: the $45 enrollment fee simply applies as usual, your tour still counts, and your place is exactly where it is. We just wanted to send a small welcome for taking the time to visit.</p>
      <p>Your private link is below. No account or password needed, it takes you straight to your page.</p>
      <p>If you have any questions, or would like to talk through rates or start dates, just reply to this email... we are happy to help.</p>
      <p>With love,<br>The Growing Mindfully team</p>
      <p style="margin:28px 0 0;text-align:center"><a href="https://waitlist.growingmindfully.org/c/EXAMPLE_TOKEN" style="background:#3E8E9C;color:#fff;padding:14px 30px;border-radius:999px;text-decoration:none;font-weight:600;font-size:15px;display:inline-block;box-shadow:0 6px 16px rgba(42,66,49,.22)">Reserve Mia's space</a></p>
      <p style="text-align:center;font-size:12px;color:#9a9590;margin:14px 0 0">This $45 enrollment-fee waiver is good through 5:00 PM Pacific today, Friday, July 11. After that the fee applies normally and nothing about your spot changes. This link is unique to your family.</p>
      <div style="margin-top:30px;border-top:1px solid #e8e2d8;padding-top:16px;text-align:center">
        <img src="https://www.growingmindfully.org/assets/mark.png" alt="" width="26" height="26" style="width:26px;height:26px;display:block;margin:0 auto 8px">
        <p style="color:#9a9590;font-size:12px;margin:0">Growing Mindfully &middot; enrollment@growingmindfully.org &middot; 750 N Street, Sacramento CA 95814</p>
      </div>
    </div>
  </div>
</div>
```

---

## 10. Compliance checklist (run before ship)

- [ ] `grep -i '\$45\|enrollment fee\|waiv'` the final copy: EVERY hit carries its condition
      ("reserve by 5PM {today|tomorrow}") in the same or immediately adjacent sentence. (subjects,
      preheader, heading, body sentence 2, afterCta all pass by construction.)
- [ ] No em dashes anywhere (subjects, body, afterCta). Verified: none.
- [ ] No licensing language, no license numbers, no "Lic. #", no H&S citations. Verified: none.
- [ ] No "free tour" phrasing (the tour was never priced). Verified: none; copy says "touring" /
      "coming to see us".
- [ ] No fake scarcity / no seat-count claim / no animated countdown. Verified: only a real dated
      deadline + full downside disclosure.
- [ ] Team voice, signed "With love, The Growing Mindfully team", never Jarred. Verified.
- [ ] `kind:'lifecycle_t4_post_tour'` NOT in `TRANSACTIONAL_KINDS` -> suppression-gated + unsub
      footer auto-appended (CAN-SPAM). Physical address present in shell footer.
- [ ] Deadline computed in America/Los_Angeles; today/tomorrow variant selected by the section-6
      rule (>= ~4h runway or roll to next day).
- [ ] Waiver flag time-boxed server-side to the SAME 5PM PT deadline the email states.
- [ ] GATED on the $45 plumbing (enrollmentFeeDue + reserve-agreement-v4). Do not send while the
      reserve flow still bills the full $45. (Section 0, blockers 1-2.)

---

## 11. Open questions for Jarred (surface, do not decide)

1. **No-show default direction** (`enrollfee-noshow.md` C1.4): an UNMARKED tour = send T4 (treat as
   attended) or HOLD until Ashley confirms attended? Recommendation: send-on-unmarked with a same-day
   Kindred nudge to mark no-shows before ~11:20 AM (for a 10 AM tour), because a held email is a
   missed same-day window. Jarred's call; it changes the WHERE predicate by one line.
2. **Edge cutoff time** (section 6): 1:00 PM PT is the proposed today/tomorrow boundary (guarantees
   ~4h runway). Confirm, and confirm next-day = next calendar day vs next open weekday.
3. **GA4 `gmwl_t4_sent`** server event: wanted, or keep T4 telemetry D1-only like the rest of email?
4. **Does a family who took the FREE tour-waiver ("OPEN ENROLLMENT!" / V1) path get T4?** They may
   have $0 fees already; the $45 line still applies at reserve. Copy works unchanged, but confirm the
   audience overlap is intended (they are a strong T4 audience: toured, no reserve yet).
