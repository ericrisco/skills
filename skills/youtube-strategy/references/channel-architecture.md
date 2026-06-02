# Channel architecture — chains that extend the session

The algorithm scores **session watch time**: whether a viewer who lands on your video stays on the platform longer because of it. A 12-minute video with great per-video retention that dumps the viewer back to the home feed is worth less than a good-enough video that hands them to the next one. Design chains, not isolated assets. (SolveigMM, "How the YouTube algorithm works in 2025"; Boss Wallah playlist strategy, 2026; Gyre end-screen guide, 2026.)

## Playlists as binge paths

A playlist is a promise of a journey, not a storage bin.

- **Title the promise, not the contents.** "Build a SaaS from zero to first customer" beats "SaaS videos." The title sells the binge.
- **Order for momentum.** First video is the strongest hook; each subsequent one pays off the prior. Front-load the win.
- **One playlist = one outcome.** If a viewer cannot say what they will be able to do after finishing it, the playlist is a folder.

## Series Playlists

Series Playlists explicitly mark intended watch order. YouTube then signals "next in series," which raises autoplay continuation. Use them when sequence genuinely matters (a build-along, a course, a multi-part teardown). Do not mark an unordered topic collection as a series — the broken sequence promise hurts more than it helps.

## End-screen routing

End screens are routing, not decoration. The default mistake is routing every video to your single most popular upload.

- **Route to the next logical video**, the one this viewer most likely wants next given what they just watched. Relevance sustains the session; a popular-but-unrelated link breaks it.
- **Two elements max** in the last ~20 seconds: the next video + (optionally) the playlist that contains it. More choices lower the click.
- **Match the end screen to the chain position.** Part 1 ends to Part 2, not to the channel trailer.

Strategic playlists plus relevant end screens can lift session time roughly **10–30%** (Boss Wallah; Gyre, 2026). That lift is a channel-health signal, not a per-video one — it compounds across the catalog.

## The reliable binge sequence

```text
Part 1            Part 2          Case Study        Q&A
hook + promise →  the payoff   →  proof it works →  depth / objections
   │ end-screen      │ end-screen     │ end-screen       │ end-screen
   ▼                 ▼                ▼                  ▼
 Part 2           Case Study        Q&A             related playlist
```

Each node end-screens to the next; a Series Playlist holds all four in order. The sequence works because it mirrors how interest deepens: curiosity → resolution → evidence → mastery.

## Concrete examples

| Niche | Binge sequence | Why it chains |
|---|---|---|
| Budget keyboards for programmers | "5 sub-$20 boards tested" → "The one I kept after 3 months" → "Building my programmer setup around it" → "Your keyboard questions answered" | Comparison hooks, then long-term proof, then application, then objections |
| SaaS build-along | "Idea to landing page" → "First paid feature" → "How I got 10 customers" → "What I'd do differently" | Each step is the next thing the same viewer needs |

When picking which chain to invest in, read `what-worked.md`: build the sequence around the format that already earns the channel's best AVD, not around what you wish performed.
