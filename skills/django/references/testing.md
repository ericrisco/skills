# Testing Django with pytest-django

Use `pytest-django`. It gives you DB fixtures, the `@pytest.mark.django_db` gate, and
`--reuse-db`. The stdlib `TestCase` still works; the patterns below apply to both.

## Setup

```toml
# pyproject.toml
[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "config.settings.test"
addopts = "--reuse-db --strict-markers"
```

- `--reuse-db` skips schema rebuild between runs locally; CI drops it (or runs `--create-db`).
- A dedicated `settings/test.py` uses a fast hasher and an in-memory or disposable DB.

## DB access & transactions

```python
import pytest

@pytest.mark.django_db                 # this test may touch the DB
def test_publish(article):
    article.publish()
    article.refresh_from_db()
    assert article.status == "published"
```

- `TestCase` (and `django_db`) wraps each test in a transaction that rolls back — fast, isolated.
- Use `TransactionTestCase` / `@pytest.mark.django_db(transaction=True)` **only** when you assert
  `transaction.on_commit` callbacks or genuine multi-connection commit behavior; it truncates
  tables and is slower.

## Factories over hand-built rows

```python
import factory
from catalog.models import Product

class ProductFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Product
    name = factory.Sequence(lambda n: f"product-{n}")
    price = 9.99
    owner = factory.SubFactory("tests.factories.UserFactory")
```

`ProductFactory.create_batch(20)` beats 20 hand-written `objects.create(...)` calls and stays
correct as the model grows.

## Locking in N+1 fixes

```python
from django.test import TestCase

class ListQueryTests(TestCase):
    def test_list_is_constant_queries(self):
        ProductFactory.create_batch(10)
        with self.assertNumQueries(2):          # list + one prefetch, regardless of N
            list(Product.objects.select_related("owner"))
```

`assertNumQueries` turns a silent N+1 regression into a red build. Add one to every list/detail
endpoint that walks a relation.

## API tests

```python
from rest_framework.test import APIClient

@pytest.mark.django_db
def test_owner_only(product, owner):
    client = APIClient()
    assert client.get(f"/api/products/{product.pk}/").status_code == 403   # anon
    client.force_authenticate(owner)
    assert client.get(f"/api/products/{product.pk}/").status_code == 200
```

- `force_authenticate(user)` bypasses the login round-trip; test the permission, not the auth UI.
- Test the boundary cases: anonymous, wrong owner, correct owner, and invalid payload (400).

## Coverage

Run `pytest --cov` and set `--cov-fail-under` in `pyproject.toml`. Cover model methods,
managers, permissions and serializers validators — the logic, not the framework.
