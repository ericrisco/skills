# Diátaxis modes — templates, a worked split, and the banlist

The four modes (diataxis.fr/start-here, accessed 2026-06-02) each answer a
different reader question. Use this file when SKILL.md's classify table is not
enough — you have a real mixed page to break apart, or you need a full template.

## Per-mode templates

### Tutorial template

```md
# Build your first <thing>

By the end you will have <concrete outcome>.

## Before you start
- <tool> <exact version>
- <account/key> from <url>

## 1. <first action>
<command>
You should see: <visible result>

## 2. <next action>
...

## What you built
<one paragraph recap>. Next: <link to a how-to or explanation>.
```

Rules: linear, runnable on a clean machine, no branching, no rationale. If you
catch yourself writing "you could also", stop — that belongs in a how-to.

### How-to template

```md
# How to <achieve a specific goal>

Assumes you already <competence assumption>.

1. <step>
2. <step>
3. <step>

Done when: <observable success condition>.
```

Rules: goal in the title, competent reader, no concept teaching. Link out for
"what is X" rather than explaining inline.

### Reference template

```md
# <component / endpoint / command>

<one-line factual description>

## Parameters
| Name | Type | Required | Default | Description |
|---|---|---|---|---|

## Returns
| Field | Type | Description |
|---|---|---|

## Errors
| Code | Meaning |
|---|---|
```

Rules: dry, complete, consistent across entries, structured like the product,
zero opinions.

### Explanation template

```md
# About <concept> / Why <decision>

<context: what problem this addresses>
<the approach and the trade-off>
<alternatives considered and why this one>
```

Rules: prose, never numbered steps, opinion allowed *with* reasoning.

## Worked split: one mixed page into four

A page titled "Logging" tries to do everything:

> Logging helps you debug. Logging is asynchronous in Acme because blocking
> the request path would hurt latency. To set it up, run `acme init logging`,
> then set `LOG_LEVEL`. The logger accepts levels DEBUG, INFO, WARN, ERROR
> and a `sink` of `stdout|file|datadog`. We recommend `datadog` in production.

That single page mixes all four modes. Split it:

| Original sentence | Belongs in |
|---|---|
| "Logging helps you debug." | Cut — filler. |
| "Logging is asynchronous because blocking the request path would hurt latency." | **Explanation**: *Why Acme logs asynchronously* |
| "Run `acme init logging`, then set `LOG_LEVEL`." | **Tutorial** step *or* a **how-to** "How to enable logging" |
| "Levels: DEBUG…ERROR; `sink`: stdout/file/datadog." | **Reference**: the `logging` config table |
| "We recommend `datadog` in production." | **How-to** "How to ship logs to Datadog" (the opinion lives in the recipe's intro, not in reference) |

Result: four short pages, each scannable, each answering one question — instead
of one page answering none well.

## Weasel-word & AI-tell banlist

These words lie about difficulty, inflate, or signal machine-generated filler.
Delete or replace. This list is the source of truth for `scripts/verify.sh`.

| Banned | Why | Replace with |
|---|---|---|
| simply | Mocks the reader who is stuck | (delete) |
| just | Same — minimizes real effort | (delete) |
| easy / easily | Difficulty is the reader's to judge | (delete) |
| effortless / effortlessly | Marketing claim, unverifiable | (delete) |
| seamless / seamlessly | Means nothing concrete | name the actual behavior |
| robust | Vague reassurance | state the guarantee (e.g. "retries 3×") |
| powerful | Empty superlative | show what it does |
| blazing-fast / lightning-fast | Hype | give a number ("p50 12 ms") |
| supercharge | Marketing | describe the actual benefit |
| leverage | Jargon for "use" | use |
| utilize | Jargon for "use" | use |
| in order to | Always longer than needed | to |
| please (in steps) | Steps are imperatives | (delete) |
| log in / login (verb) | Style-guide preference | sign in |

When a step feels like it needs "simply", that is a signal the step is either
obvious (delete the word) or genuinely hard (add the missing detail instead).
