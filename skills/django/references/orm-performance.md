# ORM performance recipes

The ORM is fast when you tell it what to fetch. Almost every slow Django page is an N+1 or a
fetch of columns/rows you never use.

## select_related vs prefetch_related vs Prefetch

```python
# Forward FK / OneToOne -> SQL JOIN, one query
Article.objects.select_related("author", "author__profile")

# Reverse FK / ManyToMany -> a second query, joined in Python
Author.objects.prefetch_related("articles", "tags")

# Prefetch that needs its own filter/order/select_related
from django.db.models import Prefetch
Author.objects.prefetch_related(
    Prefetch("articles",
             queryset=Article.objects.published().select_related("category"))
)
```

- `select_related` only follows single-valued relations (FK, O2O). Use it for the JOIN.
- `prefetch_related` handles multi-valued relations and runs a separate `IN (...)` query.
- `Prefetch` is the escape hatch when the related set needs filtering, ordering, or its own
  `select_related` — otherwise you re-introduce an N+1 inside the prefetch.

## Proving query counts

```python
from django.test import TestCase

class FeedQueryCount(TestCase):
    def test_feed(self):
        with self.assertNumQueries(2):
            [a.author.name for a in Article.objects.select_related("author")]
```

In a shell, eyeball SQL with `django.db.connection.queries` (needs `DEBUG=True`) or wrap a block
in `CaptureQueriesContext`.

## Fetch less

```python
Article.objects.only("id", "slug", "title")     # SELECT just these columns
Article.objects.defer("body")                    # everything except the heavy one
Article.objects.values("id", "slug")             # dicts, no model instances
Article.objects.values_list("id", flat=True)     # a flat list of ids
```

- `.exists()` for existence; `.count()` only when you truly need the integer.
- Never `list(Model.objects.all())` then filter/slice in Python — push it into the QuerySet.

## Aggregate in the DB, not in Python

```python
from django.db.models import Count, Sum, Q

Author.objects.annotate(
    published=Count("articles", filter=Q(articles__status="published"))
)
Order.objects.aggregate(total=Sum("amount"))
```

A Python loop summing `.amount` over a queryset is one row fetched per iteration plus the math;
`annotate`/`aggregate` does it in a single SQL pass.

## Bulk writes

```python
Article.objects.bulk_create(objs, batch_size=500)            # one round-trip
Article.objects.bulk_update(objs, ["status"], batch_size=500)
Article.objects.filter(status="draft").update(status="published")  # set-based, no Python loop
```

`.update()` is a single UPDATE and skips `save()`/signals — use it for set-based changes, and a
loop of `.save()` only when you need per-row signals/`save()` logic.

## Indexing through the ORM

```python
class Meta:
    indexes = [
        models.Index(fields=["tenant", "status"]),
        models.Index(fields=["-published_at"], name="article_recent"),
    ]
```

Add the index where your hot `filter`/`order_by` actually hits. *Which* index, and reading
`EXPLAIN ANALYZE`, is `postgresdb`; here you just express it. Inspect a query plan from the ORM
with `qs.explain()`.
