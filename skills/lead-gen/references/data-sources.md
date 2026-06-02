# Reference — data sources, the Apollo API flow, and the provenance spec

How to pick providers, run the waterfall, call Apollo's search→enrichment flow, and what every row must carry to stay legal.

## Provider comparison

No single database wins — coverage and accuracy vary by region and segment, which is why waterfall enrichment is the 2025 norm. *(starnus.com / cleanlist.ai / fundraiseinsider.com comparisons, accessed 2026-06-02.)*

| Provider | Coverage | Email accuracy | Best for |
|---|---|---|---|
| Apollo | ~200M contacts | ~78% | Free/credit-free search; broad SMB + mid-market |
| ZoomInfo | 321M+ contacts / 104M+ companies | ~84% | Strongest firmographics; enterprise |
| People Data Labs | Broad person/company graph | Varies | Programmatic fill layer in a waterfall |
| Clay | Orchestrates 100+ sources | Inherits the layer that hit | The waterfall engine itself |

Both Apollo (~78%) and ZoomInfo (~84%) sit at the edge of the high-volume-sender red-flag line, so a verification pass is mandatory regardless of provider.

## Waterfall ordering heuristic

1. Order providers by **accuracy-per-dollar** for your segment (often ZoomInfo for firmographics, Apollo for free volume, PDL/others as fill).
2. Query the cheapest broad layer first (Apollo free search) to get the candidate set.
3. For each row still missing a verified email, query the next layer — **only for the misses**.
4. **Stop at the first verified hit.** You pay once per contact, not once per provider.
5. Drop rows no layer can verify rather than ship them unverified.

Clay can run steps 2–4 for you across 100+ sources; the heuristic is the same whether you orchestrate it by hand or let Clay do it.

## Apollo People Search → Enrichment flow

Search and enrichment are two separate endpoints. Search **does not consume credits** and is capped at **50,000 records per query** (100/page × 500 pages), but returns **no emails or phones**. Contact data comes only from the (credit-consuming) enrichment endpoints. *(docs.apollo.io/reference/people-api-search, accessed 2026-06-02.)*

```http
# Step 1 — search (free, no credits): find people, get IDs + firmographics
POST https://api.apollo.io/api/v1/mixed_people/api_search
Content-Type: application/json
X-Api-Key: <key>

{
  "person_titles": ["VP Engineering", "Head of Data"],
  "person_seniorities": ["vp", "head"],
  "organization_locations": ["United States", "European Union"],
  "organization_num_employees_ranges": ["51,200", "201,500"],
  "currently_using_any_of_technology_uids": ["snowflake", "bigquery"],
  "q_organization_job_titles": ["Data Analyst"],
  "page": 1,
  "per_page": 100
}
# → up to 50,000 records across 500 pages; NO email/phone in the response.
```

```http
# Step 2 — enrich (consumes credits): get email + phone for the chosen IDs
POST https://api.apollo.io/api/v1/people/bulk_match
Content-Type: application/json
X-Api-Key: <key>

{ "details": [ { "id": "<person_id_from_search>" }, ... ],
  "reveal_personal_emails": false }
# → enriches only the rows you pass — dedupe + ICP-filter BEFORE this call so you
#   never spend credits on rows you would have dropped.
```

Available search filters include title, seniority, location, headcount, revenue, 1,500+ technologies, and active job postings — make your ICP technographic/intent criteria map onto these so they are machine-checkable.

## Dedupe against the CRM (before enriching)

Match candidate rows against existing CRM records on **company domain + person email/LinkedIn URL**. Drop:

- Accounts that are already open opportunities (do not cold-touch a live deal).
- Contacts already owned by a rep.
- Current customers, partners, and competitors.

Deduping before enrichment saves credits and prevents the cardinal sin of a rep cold-emailing an active account.

## Provenance / compliance field spec (every row carries this)

A list with no provenance has no defensible lawful basis under GDPR, and purchased/scraped data confers none. *(derrick-app.com / instantly.ai GDPR-B2B guides, accessed 2026-06-02.)* Each row must carry:

| Field | Why it must exist |
|---|---|
| `source` | Provider + acquisition date — the data-source disclosure GDPR requires you surface to the contact |
| `acquired_at` | Date the row was sourced — feeds score decay and freshness checks |
| `verified` | Did the verification pass confirm the email? Unverified rows do not ship |
| `opt_out` | Compliance flag proving the email will carry a one-click opt-out + source disclosure |
| `lawful_basis` | The Art. 6(1)(f) legitimate-interest reference (the LIA exists) for EU contacts |

These collapse into the scored-list CSV's `source` and `opt_out` columns that `scripts/verify.sh` checks; keep the fuller fields in your working file and project the required columns into the handoff CSV.
