# Base images & multi-stage templates

Per-language skeletons beyond the three in SKILL.md, plus tag maps and multi-arch notes.

## Tag map (2026)

| Goal | Tag |
|---|---|
| Pragmatic glibc default | `debian:bookworm-slim`, `python:3.13-slim-bookworm`, `node:24-bookworm-slim` |
| Distroless runtime | `gcr.io/distroless/static-debian12:nonroot`, `gcr.io/distroless/nodejs24-debian13:nonroot`, `gcr.io/distroless/python3-debian12:nonroot` |
| Chainguard / Wolfi | `cgr.dev/chainguard/node:latest`, `cgr.dev/chainguard/python:latest`, `cgr.dev/chainguard/static:latest` (pin the digest in prod) |
| Fully static binary | `scratch` |

Node tags follow the active LTS (`24` as of mid-2026); `22` is Maintenance LTS — pick it only as
the conservative choice. Go tags follow the two supported minors (`1.26`/`1.25`); never ship a
build image off the supported window since it stops getting security patches.

Chainguard images carry SLSA L3 build attestations and track the lowest live CVE counts; real
scans have found high-severity CVEs in a distroless image where the Chainguard equivalent had zero.
Distroless is convenient but patches more slowly. Pin by digest for reproducibility.

## Rust → scratch / distroless-static

Pin the build image to your project's MSRV (the minimum Rust your `Cargo.toml` declares), or to a
current stable minor if you have none — `1.96` is the latest stable as of mid-2026. *Why: a stale
build image (e.g. `1.83`, ~13 minors back) compiles fine but stops getting toolchain security
fixes, the same supported-window rule as the Node/Go skeletons.*

```dockerfile
# syntax=docker/dockerfile:1
FROM rust:1.96-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN --mount=type=cache,target=/usr/local/cargo/registry cargo build --release
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    touch src/main.rs && cargo build --release

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=build /src/target/release/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

Use `distroless/cc` (not `static`) when you link against glibc/`libgcc`. For musl-static, build the
`x86_64-unknown-linux-musl` target and ship on `scratch`.

## JVM → jlink custom runtime

A full JRE is ~200 MB; a `jlink`-trimmed runtime with only the modules you use is ~50–80 MB.

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./mvnw -q package -DskipTests
RUN jlink --add-modules java.base,java.logging,java.sql,java.naming \
      --strip-debug --no-man-pages --no-header-files --compress=2 \
      --output /javaruntime

FROM debian:bookworm-slim
RUN useradd --uid 10001 app
COPY --from=build /javaruntime /opt/java
COPY --from=build --chown=app:app /src/target/app.jar /app/app.jar
ENV PATH="/opt/java/bin:$PATH"
USER app
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Run `jdeps --print-module-deps target/app.jar` to discover the real module list.

## Static SPA → nginx (non-root)

```dockerfile
# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-bookworm
COPY --from=build /app/dist /usr/share/nginx/html
# nginx-unprivileged already runs as UID 101 and listens on 8080
EXPOSE 8080
```

Use `nginxinc/nginx-unprivileged` so you are not running the webserver as root. Caddy
(`caddy:2-alpine`) is a smaller alternative with automatic compression.

## Multi-arch with buildx

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myimage:1.4.0 --push .
```

Cross-compile rather than emulate where the toolchain allows it: Go uses `GOOS`/`GOARCH`, Rust uses
`--target`. Emulated arm64 builds via QEMU are correct but slow; native cross-compile in the build
stage then `COPY` per-arch is far faster.
