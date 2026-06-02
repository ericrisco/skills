# Testing Rust services

Behind SKILL.md's testing essentials. Unit, integration, doctests, async, fakes.

## Unit tests

Co-locate in a `#[cfg(test)] mod tests` block; they can reach private items in the same module.

```rust
fn slugify(s: &str) -> String { s.trim().to_lowercase().replace(' ', "-") }

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slugify_lowercases_and_dashes() {
        assert_eq!(slugify("  Hello World "), "hello-world");
    }
}
```

A data-driven shape (Rust's "table test"): iterate over a slice of cases.

```rust
#[test]
fn parse_cases() {
    let cases = [("42", Some(42)), ("x", None)];
    for (input, want) in cases {
        assert_eq!(parse(input), want, "input = {input}");
    }
}
```

## Async tests

```rust
#[tokio::test]
async fn fetch_returns_record() {
    let repo = FakeRepo::with(vec![Record::new(1)]);
    let got = service::fetch(&repo, 1).await.unwrap();
    assert_eq!(got.id, 1);
}
```

## Integration tests against the Router

Files in `tests/` are separate crates that link the **public** API (so logic must live in `lib.rs`, not
`main.rs`). Drive the real `Router` with `tower::ServiceExt::oneshot` — no network, no port:

```rust
// tests/users_api.rs
use axum::{body::Body, http::{Request, StatusCode}};
use tower::ServiceExt;
use my_service::{build_router, test_state};

#[tokio::test]
async fn get_user_404_when_missing() {
    let app = build_router(test_state());
    let res = app
        .oneshot(Request::get("/users/999").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NOT_FOUND);
}
```

## Fakes via traits

Depend on a trait, not a concrete DB type, so unit tests inject a fake without a database:

```rust
#[async_trait::async_trait]      // still needed for `dyn` trait objects in some versions; native async fn covers static dispatch
pub trait UserRepo: Send + Sync {
    async fn find(&self, id: i64) -> Result<Option<User>, ApiError>;
}

struct FakeRepo(Vec<User>);
#[async_trait::async_trait]
impl UserRepo for FakeRepo {
    async fn find(&self, id: i64) -> Result<Option<User>, ApiError> {
        Ok(self.0.iter().find(|u| u.id == id).cloned())
    }
}
```

For sqlx integration tests against a real DB, `#[sqlx::test]` provisions an isolated test database per
test and rolls it back.

## Doctests

Examples in `///` docs are compiled and run by `cargo test --doc` — they cannot rot silently:

```rust
/// Slugifies a title.
///
/// ```
/// assert_eq!(my_service::slugify("Hello World"), "hello-world");
/// ```
pub fn slugify(s: &str) -> String { /* ... */ }
```

## Tooling

- `cargo nextest run` — faster, isolated, clearer parallel test output than `cargo test` (it does not
  run doctests; keep `cargo test --doc` in the gate).
- `insta` — snapshot testing for JSON/response bodies; `cargo insta review` to accept diffs.
- Run the whole gate via `scripts/verify.sh` (fmt + clippy + test + audit).
