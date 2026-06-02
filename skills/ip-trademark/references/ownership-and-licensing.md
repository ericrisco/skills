# Ownership & licensing

Not legal advice. This walks the operator through *who owns what* and *how to
license it*, so they know what to ask a licensed IP attorney to make binding.
Facts accessed 2026-06-02.

## Contractor IP audit — walkthrough

The default surprises most founders: **the creator owns the copyright, and
paying for the work does not transfer it.** Run this in order.

1. **Classify the maker.** Employee creating within the scope of employment →
   employer owns by default. Independent contractor → contractor owns by
   default, full stop, regardless of the invoice.
2. **Find the signed transfer.** For contractor work, ownership moves to you
   only by a **signed written copyright assignment** or a valid
   **work-made-for-hire** agreement. A paid invoice, an email "it's yours", or a
   verbal promise is not a transfer.
3. **Check the work-made-for-hire fit.** WMFH for a contractor is valid *only*
   if the work is one of the **9 statutory categories** in 17 U.S.C. §101
   (contribution to a collective work; part of a motion picture/AV work;
   translation; supplementary work; compilation; instructional text; test;
   answer material for a test; atlas) **and** there is a signed writing saying
   it is WMFH. A standalone logo, app codebase, or marketing site usually does
   **not** fit — so do not rely on WMFH for those; use an outright assignment.
4. **Check scope.** Does the assignment cover *all* deliverables, source files,
   and later revisions — or only the one final export? Gaps leave the
   contractor owning the rest.
5. **Check the AI layer.** A contractor cannot assign rights they never owned.
   AI-generated portions may not be copyrightable at all (below), so an
   assignment of "all rights" silently transfers nothing for those pieces.
6. **Conclusion.** If any link is missing, the honest answer is "ownership is
   unclear / probably still the contractor's." Recommend getting the signed
   assignment now and route the *clause wording* to the contracts skill.

## Assignment vs. work-made-for-hire

| | Assignment | Work-made-for-hire |
|---|---|---|
| Mechanism | Transfers an existing copyright from owner to you | Treats you as the author from the start |
| Needs a signed writing | Yes | Yes |
| Category limits | None — works for any work | Contractor work must be 1 of the 9 §101 categories |
| Reliable for logos/code/web | **Yes** | Usually no (doesn't fit a category) |
| US termination risk | Author may have later termination rights | Not applicable (you are deemed author) |

Default recommendation for typical startup deliverables: **assignment**, because
it works regardless of category.

## AI authorship — case by case

Per the U.S. Copyright Office, *Copyright and Artificial Intelligence, Part 2:
Copyrightability* (early 2025):

- **Fully AI-generated output is not copyrightable.** No human author, no
  copyright.
- **Prompts alone do not confer authorship**, no matter how detailed —
  prompting is treated more like instructing than authoring.
- **Human contribution can earn protection**: creative selection, arrangement,
  or substantial modification of AI output is analyzed case by case, and the
  protectable part is the human contribution, not the raw AI generation.

Operator translation: if a logo or hero image came straight out of a generator
with no meaningful human authorship, treat it as potentially unprotectable and
do not build enforcement plans on it.

## Copyright notice format

`© <year> <legal name>` — e.g. `© 2026 Acme S.L.`. Optional in most modern
regimes but worth using: it dates the claim, identifies the owner, and rebuts
"innocent infringement" arguments. For software, a short `LICENSE` file plus a
header notice is the norm.

## License-at-a-glance

A **license** keeps ownership and grants use; an **assignment** transfers
ownership. Choose deliberately.

| License | What it allows | Watch out for |
|---|---|---|
| All rights reserved | Nothing without your permission | Default; nobody may reuse |
| CC BY | Reuse with attribution | Commercial use allowed |
| CC BY-SA | Reuse with attribution, derivatives share-alike | Viral: derivatives inherit the license |
| CC BY-NC | Reuse with attribution, non-commercial only | "Non-commercial" is fuzzy and disputed |
| CC0 / public domain dedication | Anything, no attribution | You give up essentially all rights |
| MIT / BSD (code) | Reuse with notice retained | Permissive; minimal obligations |
| Apache-2.0 (code) | Permissive + patent grant | Notice + state-changes requirements |
| GPL / AGPL (code) | Reuse, but derivatives must open-source | Copyleft; AGPL reaches network use |

Picking the wrong license is hard to undo once others rely on it — decide before
publishing, and get a licensed attorney to confirm anything load-bearing.
