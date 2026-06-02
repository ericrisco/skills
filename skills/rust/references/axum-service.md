# axum 0.8 service skeleton

The full HTTP surface behind SKILL.md's essentials. axum 0.8, tokio 1.x, tower middleware.

## Shared state

`AppState` holds the dependencies (DB pool, config, clients). Wrap in `Arc`, inject via `State`:

```rust
use std::sync::Arc;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,            // PgPool is itself an Arc internally; clone is cheap
}

pub type Shared = Arc<AppState>;
```

## Error enum -> IntoResponse

One enum, one mapping. Pattern-match the variant; log only the unexpected; never leak internals.

```rust
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ApiError {
    #[error("not found")]
    NotFound,
    #[error("invalid input: {0}")]
    BadRequest(String),
    #[error(transparent)]
    Db(#[from] sqlx::Error),     // `?` on a query lifts sqlx::Error into ApiError
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, msg) = match &self {
            ApiError::NotFound => (StatusCode::NOT_FOUND, "not found".to_string()),
            ApiError::BadRequest(m) => (StatusCode::BAD_REQUEST, m.clone()),
            ApiError::Db(e) => {
                tracing::error!(error = %e, "db error"); // log server-side only
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".to_string())
            }
        };
        (status, Json(json!({ "error": msg }))).into_response()
    }
}
```

## Handlers and router

```rust
use axum::{extract::{Path, State}, routing::get, Json, Router};

async fn get_user(
    State(state): State<Shared>,
    Path(id): Path<i64>,                          // {id} parsed to i64; bad input -> 400 automatically
) -> Result<Json<User>, ApiError> {
    let user = sqlx::query_as!(User, "SELECT id, name FROM users WHERE id = $1", id)
        .fetch_optional(&state.pool)
        .await?                                   // sqlx::Error -> ApiError::Db
        .ok_or(ApiError::NotFound)?;              // None -> 404
    Ok(Json(user))
}

async fn healthz() -> StatusCode { StatusCode::OK }

async fn readyz(State(state): State<Shared>) -> StatusCode {
    match sqlx::query("SELECT 1").execute(&state.pool).await {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::SERVICE_UNAVAILABLE, // 503 when the DB is unreachable
    }
}

pub fn build_router(state: Shared) -> Router {
    Router::new()
        .route("/users/{id}", get(get_user))      // axum 0.8: {id}, not :id
        .route("/healthz", get(healthz))
        .route("/readyz", get(readyz))
        .with_state(state)
}
```

## Tower middleware

Compose cross-cutting concerns as layers (outermost runs first on the request):

```rust
use std::time::Duration;
use tower_http::{trace::TraceLayer, timeout::TimeoutLayer, request_id::PropagateRequestIdLayer};

let app = build_router(state)
    .layer(TraceLayer::new_for_http())            // span + structured access logs via tracing
    .layer(TimeoutLayer::new(Duration::from_secs(10)))
    .layer(PropagateRequestIdLayer::x_request_id());
```

## main + graceful shutdown

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().json().init();

    let pool = PgPool::connect(&std::env::var("DATABASE_URL")?).await?;
    let state = Arc::new(AppState { pool });
    let app = build_router(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())  // drain in-flight requests on SIGTERM/Ctrl-C
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async { tokio::signal::ctrl_c().await.expect("install Ctrl-C handler"); };
    #[cfg(unix)]
    let term = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("install SIGTERM handler").recv().await;
    };
    #[cfg(not(unix))]
    let term = std::future::pending::<()>();
    tokio::select! { _ = ctrl_c => {}, _ = term => {} }
}
```
