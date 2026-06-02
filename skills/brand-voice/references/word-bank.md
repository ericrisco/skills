# Word Bank — Ban List & Power-Word Method

Two jobs: a universal ban list you can adopt as-is, and a method to derive *brand-specific* power words from the traits. The ban list is the drift killer; the power words are what make copy sound like *this* brand and not a competitor. (Oxford College of Marketing, "AI Brand Voice Guidelines," 2025-08-04.)

## Universal ban list (corporate filler + AI tells)

Adopt all of these by default, then add brand-specific bans. These words signal either generic marketing-speak or machine-generated copy:

```text
leverage              # say "use"
seamless / seamlessly # say "with no setup" or describe what actually happens
elevate               # say "improve" or name the concrete gain
delve                 # say "look at" / "dig into"
robust                # say what it does (handles X, survives Y)
unlock                # say "get" / "start"
game-changer          # show the change, don't label it
revolutionize         # over-claim; state the measurable difference
synergy / synergize   # name the actual benefit
best-in-class         # prove it with a number or drop it
cutting-edge          # show the capability, not the cliche
world-class           # same — prove or cut
in today's fast-paced world   # opening filler; start with the point
at the end of the day         # filler
it's important to note         # AI tell; just note it
embark on a journey            # AI tell
```

### Why these specifically

Two failure modes converge here. **Corporate filler** ("leverage", "synergy", "best-in-class") says nothing and could describe any company. **AI tells** ("delve", "in today's fast-paced world", "embark on a journey", "it's important to note") are the statistically over-produced phrases of generic LLM output — readers now register them as "a bot wrote this." Banning both is what keeps generated copy on-brand.

## Brand-specific bans

Add words to ban that are correct English but wrong for *this* brand. Examples:

```text
"users"        -> if the brand says "teams" or "people", ban "users"
"solution"     -> if the brand names the actual product category, ban "solution"
"!"            -> if the voice is calm/serious, ban exclamation marks outright
"thrilled"     -> ban manufactured excitement words for a serious brand
```

Rule of thumb: if a banned word appears in the brand's own guide prose, the guide contradicts itself. `scripts/verify.sh` catches exactly this.

## Deriving power words from traits

Power words are not a thesaurus dump. Derive 15–20 directly from the traits so the bank is defensible:

1. **List each trait.** e.g. plain-spoken, confident, technical-but-human.
2. **For each trait, write the verbs and nouns a person living that trait would reach for.**
   - plain-spoken → ship, fix, build, clear, plain, real, works, done
   - confident → know, prove, sourced, accurate, on time
   - technical-but-human → connect, set up, run, simple, fast
3. **Cut synonyms and abstractions.** Keep words a reader would recognize as concrete. Drop "facilitate", "enable", "optimize" — they are filler in disguise.
4. **Cap at ~20.** A bank longer than 20 is unmemorable; writers won't internalize it.

The test: read the power-word list cold. If it could belong to any company in the category, it is too generic — push it back toward the traits until it could only be *this* brand.

## How verify.sh uses this

`scripts/verify.sh` confirms a produced guide actually contains a non-empty ban-list block (hard fail if missing) and then greps the guide's own prose for any term it bans (self-consistency warning). It does not enforce *which* words you ban — that is a brand choice — only that a ban list exists and the guide practices what it preaches.
