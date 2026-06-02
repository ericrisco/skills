# Platform playbooks

Per-platform setup depth. Pick the platform with the decision table in `../SKILL.md`; this file is the build manual for each. Every load-bearing fact carries its source + access date.

## Discord — the real-time default

### AutoMod (native layer)
- **Keyword filters**: one **Commonly-Flagged-Words preset rule** (`KEYWORD_PRESET`: Insults & Slurs, Sexual Content, Severe Profanity), **1 per guild**, **plus up to 6 custom keyword rules** (`KEYWORD` trigger), each filter holding **up to 1,000 terms** (60 chars each). Use a custom rule for your scam-phrase blocklist and link patterns. Note: the "1,000" is the per-rule *filter* size; do not confuse it with the 100-entry cap on a `KEYWORD` rule's per-rule *allow_list* (exception terms).
- **Mention-spam cap** (`MENTION_SPAM`, 1 per guild): configurable up to **50 unique role/user mentions per message** before AutoMod acts. Set this low (e.g. 5) for raid resistance.
- Actions per rule: block message, alert a mod channel, timeout the author. Always route a copy to a private `#mod-log`.
- Source: Discord — *Auto Moderation* developer docs (docs.discord.com/developers/resources/auto-moderation) + *AutoMod FAQ* (support.discord.com), accessed 2026-06-02.

### Verification levels
- Set **Medium** as the baseline: verified email + member for >5 minutes before talking. **High** adds a 10-minute server-tenure requirement; **Highest** requires a verified phone. Raise the level temporarily during a raid (the "lockdown" lever).

### Rules Screening / Membership Screening
- Gates **talking and DMs** until a new member explicitly acknowledges the rules. This both stops drive-by spam and forces the first deliberate click of the onboarding funnel.
- Pair with **Onboarding** (role/interest selection on join) so the rules-ack flows straight into role-on-join → personalized channels.
- Source: Discord — *Rules Screening FAQ* + community-building playbooks, accessed 2026-06-02.

### Layered defense by size (Discord's own guidance)
| Size | Recommended stack |
|---|---|
| Small (< 1,000) | Native AutoMod + Medium verification |
| > 1,000 | Add a specialized moderation bot + custom keyword rules |
| > 10,000 | Robust multi-tool bots + Commonly-Flagged filters on |
| > 100,000 | Multiple specialized bots + tiered human mod org |
- Canonical 3-layer stack everywhere: **native tools → bot automod → human mods**.
- Source: Discord safety guidance summarized in friendify.net *Discord Moderation & AutoMod Complete Guide (2025)*, accessed 2026-06-02.

## Telegram — mobile-first, broadcast-heavy

### The hybrid pattern (2026 standard)
- **Groups = two-way conversation; channels = one-way broadcast.** A bare group has no clean announce lane; a bare channel has no conversation. Run a **channel for announcements + a linked discussion group** so each post can spawn a thread.
- Source: Metricgram — *Telegram Group vs Channel*, accessed 2026-06-02.

### Native anti-spam + slow-mode
- **Native ML anti-spam activates for groups > 200 members**, with an **"Aggressive" mode** that auto-deletes suspected spam. Below that threshold it is unavailable.
- For low-traffic groups (**≤ 30 messages/hour**), **slow-mode alone** is the recommended zero-setup control — no bot needed.
- Source: Metricgram — *Best Telegram Anti-Spam Bots* / *Supergroups Explained*, accessed 2026-06-02.

### Raid gate
- **CAPTCHA-on-join** is the standard raid wall: button / math / question challenge (e.g. **Shieldy**). New accounts must pass before they can post.
- Source: Metricgram — *Anti-Spam Bots*, accessed 2026-06-02.

## Circle — the paid / monetized end

### Spaces and structure
- Content is organized into **Spaces**, which structure **tiered membership** and bundle **courses and events**. This is the monetization primitive — gate Spaces by paid tier.

### 2026 plan ladder + fees
Circle **discontinued the old "Basic" tier** — **Professional is now the entry plan**.

| Plan | Approx monthly | Circle transaction fee |
|---|---|---|
| Professional (entry) | ~$89 annual / ~$129 monthly | 2% |
| Business | ~$199 annual / ~$219 monthly | 1% |
| Circle Plus (Enterprise, custom) | ~$419+ | 0.5% |
- The transaction fee is **tiered 0.5%–2%** (2% Professional, 1% Business, 0.5% Circle Plus) and is charged by Circle **on top of Stripe's standard 2.9% + $0.30** per transaction — budget both layers when modeling take rate.
- **Real-time chat is weaker than Discord** — choose Circle for monetized membership + content bundling, not for fast live conversation.
- Source: Circle.so *Pricing* (circle.so/pricing) summarized in SchoolMaker *Circle.so Pricing 2026*, accessed 2026-06-02.

### Monetization gating
- Do **not** monetize before activation works. Charging for a dead room produces instant churn. Prove rhythm + cohort retention on the free or trial tier first, then gate the high-value Spaces.
