#!/usr/bin/env bash
set -euo pipefail

# verify.sh — vector-db skill gate. A HEURISTIC config linter, not a live DB check.
#
# Usage:  scripts/verify.sh [FILE ...]
#   FILE = a produced artifact (index DDL, collection schema, query). With no args it scans
#   the current directory for *.sql / *.py / *.json / *.md artifacts that mention a vector
#   store. Read-only; never connects to anything; never writes.
#
# Exit code: non-zero ONLY on a hard violation (metric mismatch, selective filter with no
# index/iterative-scan, ef_construction < 2*m). Missing recall mention is advisory. An empty or
# clean target exits 0 — no false failure.
#
# Portable to stock macOS bash 3.2: no mapfile, no associative arrays, arrays pre-initialised.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

# ---- collect target files -------------------------------------------------
FILES=()
if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    [ -f "$f" ] && FILES+=("$f") || note "not a file, skipping: $f"
  done
else
  ROOT="$(pwd)"
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(
    find "$ROOT" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
      -type f \( -name '*.sql' -o -name '*.py' -o -name '*.json' -o -name '*.md' \) -print0 2>/dev/null
  )
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  ok "no artifacts to check — clean"
  exit 0
fi

# Keep only files that actually look like a vector-store artifact, so a generic repo scan does
# not produce noise. A clean (non-matching) set still exits 0.
TARGETS=()
for f in "${FILES[@]}"; do
  if grep -Eiq 'vector\(|halfvec|hnsw|ivfflat|<=>|<->|<#>|create_collection|VectorParams|create_index\(|ServerlessSpec|pinecone|qdrant|weaviate|vector_cosine_ops|vector_l2_ops|vector_ip_ops' "$f" 2>/dev/null; then
    TARGETS+=("$f")
  fi
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  ok "no vector-store artifacts detected — nothing to lint"
  exit 0
fi

# ---- per-file heuristics --------------------------------------------------
for f in "${TARGETS[@]}"; do
  printf -- '--- %s\n' "$f"

  has_cosine_ops=$(grep -Eic 'vector_cosine_ops|halfvec_cosine_ops|<=>|metric *= *.?cosine|Distance\.COSINE' "$f" 2>/dev/null || true)
  has_l2_ops=$(grep -Eic 'vector_l2_ops|halfvec_l2_ops|<->|metric *= *.?(l2|euclidean)|Distance\.EUCLID' "$f" 2>/dev/null || true)
  mentions_cosine_model=$(grep -Eic 'text-embedding-3|cohere|sentence-transformers|all-MiniLM|bge-|e5-|gte-|normaliz' "$f" 2>/dev/null || true)

  # 1) Metric mismatch: a cosine-implying model but only L2 ops, no cosine ops anywhere.
  if [ "$mentions_cosine_model" -gt 0 ] && [ "$has_l2_ops" -gt 0 ] && [ "$has_cosine_ops" -eq 0 ]; then
    err "metric mismatch: artifact names a cosine-style model but indexes/queries with L2 (<->). Use cosine (<=> / vector_cosine_ops)."
  fi

  # 2) Selective filter with no index on the field and no iterative scan.
  has_filter=$(grep -Eic 'WHERE |filter=|Filter\(|filters=|MatchValue|"\$eq"' "$f" 2>/dev/null || true)
  has_field_index=$(grep -Eic 'create_payload_index|CREATE INDEX|payload_index|btree|gin' "$f" 2>/dev/null || true)
  has_iter_scan=$(grep -Eic 'iterative_scan|relaxed_order|strict_order' "$f" 2>/dev/null || true)
  is_pgvector=$(grep -Eic 'vector\(|halfvec|hnsw|ivfflat|<=>|<->|<#>' "$f" 2>/dev/null || true)
  if [ "$has_filter" -gt 0 ] && [ "$has_field_index" -eq 0 ]; then
    if [ "$is_pgvector" -gt 0 ] && [ "$has_iter_scan" -eq 0 ]; then
      err "selective filter present but no index on the filter field AND no iterative_scan — pgvector will drop rows / scan."
    else
      note "filter present but no obvious index on the filter field — confirm the field is indexed."
    fi
  fi

  # 3) IVFFlat + selective filter without iterative scan = deprecated foot-gun.
  has_ivfflat=$(grep -Eic 'ivfflat' "$f" 2>/dev/null || true)
  if [ "$has_ivfflat" -gt 0 ] && [ "$has_filter" -gt 0 ] && [ "$has_iter_scan" -eq 0 ]; then
    err "IVFFlat used with a selective filter and no iterative_scan — drops rows; prefer HNSW + hnsw.iterative_scan='relaxed_order'."
  fi

  # 4) HNSW ef_construction >= 2*m invariant (only when both are literally present).
  m_val=$(grep -Eio 'm *= *[0-9]+' "$f" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)
  efc_val=$(grep -Eio 'ef_construction *= *[0-9]+' "$f" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)
  if [ -n "$m_val" ] && [ -n "$efc_val" ]; then
    if [ "$efc_val" -lt $(( 2 * m_val )) ]; then
      err "ef_construction ($efc_val) < 2*m ($((2*m_val))) — weak HNSW graph; recall needs a full rebuild to fix."
    fi
  fi

  # 5) Recall / search-time knob mentioned somewhere (advisory).
  has_recall=$(grep -Eic 'ef_search|hnsw_ef|recall|brute.?force|baseline|probes|[^a-z]ef *=' "$f" 2>/dev/null || true)
  if [ "$has_recall" -eq 0 ]; then
    note "no recall / ef_search (or engine equivalent) mention — confirm recall was measured before shipping."
  fi
done

if [ "$EXIT" -eq 0 ]; then
  ok "no hard violations"
fi
exit "$EXIT"
