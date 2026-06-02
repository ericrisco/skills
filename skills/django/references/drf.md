# Django REST Framework (DRF 3.17.x)

DRF turns models into a JSON API. The layering mirrors core Django: **serializer = form/marshal,
viewset = view, router = URLconf**. Keep business logic on the model; the serializer validates
and shapes, the viewset orchestrates.

## Serializers

Prefer `ModelSerializer` — it derives fields and validators from the model.

```python
from rest_framework import serializers
from catalog.models import Product

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = ["id", "name", "price", "owner"]
        read_only_fields = ["owner"]  # set server-side, never trust the client

    def validate_price(self, value):
        if value < 0:
            raise serializers.ValidationError("price must be non-negative")
        return value
```

- Use an explicit `fields` list. `fields = "__all__"` leaks new columns the moment a model grows.
- Server-owned fields (`owner`, `tenant`, timestamps) are `read_only`; set them in
  `perform_create`, not from request data.
- A plain `serializers.Serializer` is for non-model payloads (search params, RPC-style bodies).

## ViewSets + routers

```python
from rest_framework import viewsets, permissions
from rest_framework.routers import DefaultRouter

class IsOwner(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return obj.owner_id == request.user.id

class ProductViewSet(viewsets.ModelViewSet):
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_queryset(self):
        # scope to the caller AND prefetch — the viewset is where N+1 is born
        return Product.objects.filter(owner=self.request.user).select_related("owner")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

router = DefaultRouter()
router.register("products", ProductViewSet, basename="product")
urlpatterns = router.urls
```

- **Every viewset declares `permission_classes`.** A `ModelViewSet` with none is a fully open
  CRUD endpoint. Set a project default in `DEFAULT_PERMISSION_CLASSES` and override per view.
- `IsAuthenticated` gates the request; object-level checks live in `has_object_permission`.
- `get_queryset` filters by tenant/owner *and* prefetches. A serializer that walks a relation
  with no prefetch is an N+1 per row — assert query counts in tests.

## Pagination, throttling, filtering

```python
# settings: DRF defaults
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.CursorPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"login": "5/min", "default": "1000/day"},
    "DEFAULT_FILTER_BACKENDS": ["rest_framework.filters.SearchFilter",
                                "rest_framework.filters.OrderingFilter"],
}
```

```python
class ProductViewSet(viewsets.ModelViewSet):
    search_fields = ["name"]
    ordering_fields = ["price", "name"]
    throttle_scope = "default"
```

- Pagination is not optional: an unpaginated list endpoint returns the whole table.
- Throttle auth/login and write endpoints. `ScopedRateThrottle` lets you rate-limit per view.
- *Whether* the contract should use cursor vs offset, what status codes to return, and how to
  version is `api-design`; this file is the DRF wiring of whatever contract you chose.

## Nested serializers without N+1

```python
class OrderSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, read_only=True)
    class Meta:
        model = Order
        fields = ["id", "items"]

# viewset queryset MUST prefetch the nested relation
Order.objects.prefetch_related("items")
```

A nested serializer with no matching `prefetch_related` issues one query per parent row. The
fix is always in `get_queryset`, never in the serializer.

## Versioning & schema

- Version via `URLPathVersioning` (`/api/v1/...`) — explicit and cache-friendly.
- Generate an OpenAPI schema with `drf-spectacular`; do not hand-write API docs.
