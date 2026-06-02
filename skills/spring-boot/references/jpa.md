# JPA persistence depth

The SKILL.md covers entities, `JpaRepository`, derived/`@Query`, paging, and the N+1 /
`LazyInitializationException` headline. This is the depth: relationships, fetch strategy,
projections, Specifications, optimistic locking, and migrations. Engine-level SQL (index
design, `EXPLAIN`, partitioning) is `../postgresdb/SKILL.md`'s job — this file stays on the
JPA/Hibernate layer above it.

## Relationships, cascade, fetch type

- Default `@ManyToOne` is **EAGER**, `@OneToMany`/`@ManyToMany` are **LAZY**. Make
  `@ManyToOne` lazy explicitly when you don't always need the parent:
  `@ManyToOne(fetch = FetchType.LAZY)`.
- Never put `CascadeType.ALL` on a `@ManyToOne` — you'll cascade-delete shared parents. Cascade
  belongs on the owning side of a true parent/child aggregate (`@OneToMany`).
- Map the relationship on **one** side and mark the other `mappedBy`. Two owning sides write
  the join column twice.

```java
@Entity
class Order {
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id")
    private User user;
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderLine> lines = new ArrayList<>();
}
```

## N+1 detection and fixes

**Detect.** Turn on SQL logging in a test profile and watch for a query repeated once per
parent:

```yaml
logging.level.org.hibernate.SQL: DEBUG
spring.jpa.properties.hibernate.generate_statistics: true   # logs query counts per session
```

**Fix, in order of preference:**

1. **`join fetch`** in a `@Query` — best when you always need the association for that path.
2. **`@EntityGraph`** on the repository method — declarative, reusable, no JPQL.
   ```java
   @EntityGraph(attributePaths = {"orders"})
   Optional<User> findById(Long id);
   ```
3. **`@BatchSize(size = 50)`** on the collection/entity — turns N+1 into N/50 IN-queries when
   you can't fetch-join (e.g. multiple bags).

Do **not** "fix" N+1 by making everything EAGER — that just moves the cost to every query and
risks cartesian-product blowups when fetch-joining two collections at once.

## Projections — don't fetch what you won't return

- **Interface projection:** declare an interface of getters; Spring builds a proxy selecting
  only those columns.
  ```java
  interface UserSummary { Long getId(); String getName(); }
  List<UserSummary> findByActiveTrue();
  ```
- **DTO/record projection** via constructor expression:
  `@Query("select new com.acme.UserSummary(u.id, u.name) from User u")`.

Projections sidestep `LazyInitializationException` entirely — there is no lazy proxy to touch.

## Specifications (dynamic queries)

For optional filters, prefer `JpaSpecificationExecutor` over building JPQL strings:

```java
interface OrderRepository extends JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {}

Specification<Order> byStatus(Status s) {
    return (root, q, cb) -> s == null ? null : cb.equal(root.get("status"), s);
}
// repo.findAll(byStatus(status).and(byUser(userId)), pageable);
```

## Optimistic locking

Add a `@Version` field to detect concurrent updates; Hibernate increments it and throws
`OptimisticLockingFailureException` on a stale write. Cheaper than pessimistic locks for
low-contention web apps.

```java
@Version private long version;
```

## Migrations

Let **Flyway** (`V1__init.sql`, `V2__add_index.sql`) or **Liquibase** own the schema; set
`spring.jpa.hibernate.ddl-auto=validate` so Hibernate verifies but never mutates the schema.
Never ship `ddl-auto=update` to production — it makes uncontrolled, unordered changes. The
actual DDL/index design for those migration files is `../postgresdb/SKILL.md`.
