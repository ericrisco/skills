# Hook library, templates & long-video extraction

## Hook library by content type

Pick the pattern that fits the *intent*; vary patterns when generating A/B
variants instead of rewording one. Hook text stays 4–7 words, high contrast,
inside the safe zone, readable muted in under a second.

### Tip / hack
- Promise: "Do this and your edit time halves."
- Contrarian: "Stop using transitions. Here's why."
- Stakes: "This one setting tanks your reach."

### Tutorial / how-to
- Promise + number: "3 cuts that fix any boring clip."
- Question: "Why do your tutorials lose people at step 2?"
- In medias res: "…and that's the move that finished it. From the top:"

### Story / before-after
- Stakes: "My first Reel got 11 views."
- In medias res: "…so I deleted the whole thing and started over."
- Contrarian: "Going viral made it worse. Here's what happened."

### Faceless / voiceover
- Question over B-roll: "Ever wonder why some Shorts never stop replaying?"
- Pattern interrupt: "Everyone gets this backwards."
- Open loop: "There are 4 reasons. The last one is the real one."

## Six patterns, defined

| Pattern | Definition | One-line test |
|---|---|---|
| Promise / result | Names a concrete outcome the viewer wants | "Would they screenshot this payoff?" |
| Question | Asks something the viewer has felt | "Do they already have this pain?" |
| Pattern interrupt | Breaks the expected scroll rhythm | "Is it the opposite of what they expect?" |
| Contrarian claim | Defensible take against consensus | "Can you back it in the body?" |
| In medias res | Opens mid-action / mid-result | "Does it start at the climax?" |
| Stakes / tension | A cost to not knowing | "What do they lose by scrolling on?" |

## Beat-sheet template

```markdown
## Script — "<title>" (<runtime>s, 9:16)

| Time | VO / spoken | On-screen text | Visual / B-roll |
|------|-------------|----------------|-----------------|
| 0:00–0:03 | <hook line> | <4–7 word hook> | <hook frame + micro-cuts> |
| 0:03–0:?? | <body beat 1> | <4–7 words> | <visual change> |
| 0:??–0:?? | <body beat 2 (escalate)> | <4–7 words> | <visual change> |
| 0:??–0:?? | <payoff> | <4–7 words> | <visual> |
| 0:??–<end> | <loop line = hook> | <hook text> | <match-cut to frame 1> |
```

## EDS template

```markdown
## EDS — "<title>"
- Hook frame: <exact opening still + timecode>
- Cuts: micro-cuts <range> (count), then 1 cut / ~3s
- Dead air: trim every gap > 250ms
- B-roll: <marker @ timecode>, <marker @ timecode>
- Captions: burned-in, full runtime, <style>, safe-zone respected
- Loop seam: <last timecode> match-cut to <0:00 frame>; <bridge>
- CTA: <single action / one benefit / 3–5 words> OR implicit (the loop)
```

## Worked example: long video → short

**Source:** a 40-minute podcast on creator burnout.

1. **Find the spike.** Skim the transcript/waveform for the one self-contained
   claim that lands without context — here, the guest's line "I posted every day
   for a year and it nearly broke me." That's your payoff seed.
2. **Build the hook from the spike, not the start.** Don't open with the
   episode's intro. Open with the tension: "I posted every day for a year." (hook,
   stakes pattern).
3. **Cut to a 28s beat sheet:**

```markdown
## Script — "Posting daily nearly broke me" (28s, 9:16)

| Time | VO / spoken | On-screen text | Visual / B-roll |
|------|-------------|----------------|-----------------|
| 0:00–0:03 | "I posted every day for a year." | EVERY DAY FOR A YEAR | Guest mid-sentence, fast zoom |
| 0:03–0:10 | "365 videos. My engagement went up. I went down." | 365 videos. I broke. | Calendar flipping, B-roll |
| 0:10–0:18 | "The mistake wasn't the schedule — it was no system." | The schedule wasn't the problem | Cut to other speaker reacting |
| 0:18–0:24 | "Batch a week in a day. Protect the other six." | Batch 7. Rest 6. | Text card, then back to face |
| 0:24–0:28 | "I posted every day for a year — so you don't have to." | …so you don't have to | Match-cut to 0:00 frame (loop) |
```

4. **EDS:** captions burned-in full runtime; micro-cuts 0:00–0:03; B-roll on the
   "365 videos" beat; loop seam 0:24 → 0:00 on the repeated line.
5. **One source → multiple shorts:** the same episode yields a second short from a
   different spike (e.g. the "batch 7, rest 6" tactic as a standalone tip). Each
   short gets its own hook and its own loop — never one clip chopped in two.
