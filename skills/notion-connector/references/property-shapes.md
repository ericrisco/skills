# Property shapes — write JSON + read-parse for every Notion property type

The Notion API rejects (HTTP 400) any property whose JSON envelope is wrong.
Each property type is keyed by its **own** type name inside the page
`properties` map. Below: the write shape (what you send on create/update) and a
read-parse note (how to pull the value back out of a query result). All keyed
by the property's display name as it appears in the data-source schema.

## Text & scalar

```ts
// title — every data source has exactly one title property
Name: { title: [{ text: { content: "Ship invoice export" } }] }
// read: page.properties.Name.title.map(t => t.plain_text).join("")

// rich_text
Notes: { rich_text: [{ text: { content: "first pass" } }] }
// read: page.properties.Notes.rich_text.map(t => t.plain_text).join("")

// number
Amount: { number: 1299.5 }            // read: page.properties.Amount.number

// checkbox
Done: { checkbox: true }              // read: page.properties.Done.checkbox

// url / email / phone_number
Site: { url: "https://example.com" }
Contact: { email: "a@b.com" }
Phone: { phone_number: "+34 600 000 000" }
// read: page.properties.Site.url   (etc.)
```

## Choice types

```ts
// select — single option, created on the fly if the name is new
Priority: { select: { name: "High" } }
// read: page.properties.Priority.select?.name ?? null

// multi_select
Tags: { multi_select: [{ name: "ops" }, { name: "billing" }] }
// read: page.properties.Tags.multi_select.map(o => o.name)

// status — like select but tied to the schema's status groups;
// the option name MUST already exist in the schema
Status: { status: { name: "In progress" } }
// read: page.properties.Status.status?.name ?? null
```

## Date & time

```ts
// date — start required, end optional, ISO 8601; include offset for time
Due: { date: { start: "2026-06-30" } }
Window: { date: { start: "2026-06-30T09:00:00+02:00", end: "2026-06-30T17:00:00+02:00" } }
// read: page.properties.Due.date?.start
```

## Relations & people

```ts
// relation — array of related PAGE ids (the related rows)
Project: { relation: [{ id: "<related_page_id>" }] }
// read: page.properties.Project.relation.map(r => r.id)

// people — array of Notion user ids the integration can see
Owner: { people: [{ id: "<user_id>" }] }
// read: page.properties.Owner.people.map(u => u.id)
```

## Files

```ts
// files — external URLs (uploading binary content is a separate flow)
Attachments: { files: [{ name: "spec.pdf", external: { url: "https://…/spec.pdf" } }] }
// read: page.properties.Attachments.files.map(f => f.external?.url ?? f.file?.url)
```

## Read-only / computed (never send on write)

`formula`, `rollup`, `created_time`, `created_by`, `last_edited_time`,
`last_edited_by`, and `unique_id` are computed by Notion. Including them in a
create/update body is rejected. Read them:

```ts
page.properties.Created.created_time;           // ISO string
page.properties.Total.formula.number;           // depends on formula result type
page.properties.Ref.unique_id.number;           // auto-incrementing id
```

## Filter operand shapes (for queries)

Filters mirror the property type. A few common ones:

```ts
// equals on a select
{ property: "Status", status: { equals: "In progress" } }
// contains on rich_text — the upsert-by-external-key workhorse
{ property: "ExternalId", rich_text: { equals: "ext-42" } }
// number comparison
{ property: "Amount", number: { greater_than: 1000 } }
// date relative
{ property: "Due", date: { on_or_before: "2026-06-30" } }
// compound
{ and: [ { property: "Done", checkbox: { equals: false } },
         { property: "Due", date: { before: "2026-07-01" } } ] }
```

Use a `rich_text` "ExternalId" property as your idempotency key and
`rich_text.equals` to look a row up before deciding create vs update.
