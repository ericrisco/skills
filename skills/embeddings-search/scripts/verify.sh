#!/usr/bin/env bash
set -euo pipefail

# verify.sh — embeddings-search skill gate. A HEURISTIC config/eval linter, not a live check.
#
# Usage:  scripts/verify.sh [FILE ...]
#   FILE = a produced artifact (embedding/ingest config, query code, eval harness). With no
#   args it scans the current directory for *.py / *.json / *.yaml / *.yml / *.md artifacts
#   that mention an embedding model, chunking, input_type, RRF/rerank, or a retrieval metric.
#   Read-only; never connects to anything; never writes.
#
# Exit code: non-zero ONLY on a hard, unambiguous violation:
#   - a cosine-style embedding model named alongside an L2-only metric, no cosine metric anywhere;
#   - an asymmetric provider named but query and document embedded with the SAME input_type.
# Advisory notes (exit 0): hybrid/rerank with no recall/nDCG/MRR/golden-set mention; chunk size
# declared with no overlap and no token-accurate counting. An empty or clean target exits 0.
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
      -type f \( -name '*.py' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.md' \) -print0 2>/dev/null
  )
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  ok "no artifacts to check — clean"
  exit 0
fi

# Keep only files that look like an embeddings/retrieval artifact, so a generic repo scan stays
# quiet. A clean (non-matching) set still exits 0.
TARGETS=()
for f in "${FILES[@]}"; do
  if grep -Eiq 'text-embedding-3|embed-v4|voyage-|bge-|e5-|gemini.?embedding|input_type|chunk_size|chunk_overlap|rerank|rrf|reciprocal.?rank|recall@|ndcg|mrr|embeddings\.create|\.embed\(' "$f" 2>/dev/null; then
    TARGETS+=("$f")
  fi
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  ok "no embeddings/retrieval artifacts detected — nothing to lint"
  exit 0
fi

# ---- per-file heuristics --------------------------------------------------
for f in "${TARGETS[@]}"; do
  printf -- '--- %s\n' "$f"

  # 1) Metric mismatch: a cosine-style model but only L2 ops named, no cosine anywhere.
  mentions_cosine_model=$(grep -Eic 'text-embedding-3|cohere|embed-v4|voyage-|bge-|e5-|gemini.?embedding|sentence-transformers|all-minilm|normaliz' "$f" 2>/dev/null || true)
  has_cosine=$(grep -Eic '<=>|cosine|vector_cosine_ops|distance\.cosine' "$f" 2>/dev/null || true)
  has_l2=$(grep -Eic '<->|vector_l2_ops|euclidean|distance\.euclid|metric *= *.?l2' "$f" 2>/dev/null || true)
  if [ "$mentions_cosine_model" -gt 0 ] && [ "$has_l2" -gt 0 ] && [ "$has_cosine" -eq 0 ]; then
    err "metric mismatch: names a cosine-style embedding model but only L2 distance — ranking is silently wrong. Use cosine (<=> / vector_cosine_ops)."
  fi

  # 2) Asymmetric provider named but query+document use the SAME input_type. Conservative:
  #    only flag when an asymmetric provider is named.
  names_asym=$(grep -Eic 'cohere|embed-v4|voyage-|bge-|e5-|gemini.?embedding' "$f" 2>/dev/null || true)
  sq=$(grep -Eic 'input_type *= *.?(search_query|query)|"query: ' "$f" 2>/dev/null || true)
  sd=$(grep -Eic 'input_type *= *.?(search_document|document|passage)|"passage: ' "$f" 2>/dev/null || true)
  any_input_type=$(grep -Eic 'input_type *=|"query: |"passage: ' "$f" 2>/dev/null || true)
  if [ "$names_asym" -gt 0 ] && [ "$any_input_type" -gt 0 ] && [ "$sd" -eq 0 ] && [ "$sq" -gt 0 ]; then
    err "asymmetric model uses the query input_type for both sides (no document/passage type found) — recall silently drops. Embed documents with the document/passage input_type."
  fi

  # 3) Hybrid / rerank present but no retrieval-quality metric mentioned (advisory).
  has_hybrid=$(grep -Eic 'rerank|rrf|reciprocal.?rank|bm25|hybrid' "$f" 2>/dev/null || true)
  has_metric=$(grep -Eic 'recall@|recall_at|ndcg|mrr|golden|relevant' "$f" 2>/dev/null || true)
  if [ "$has_hybrid" -gt 0 ] && [ "$has_metric" -eq 0 ]; then
    note "hybrid/rerank present but no recall/nDCG/MRR or golden-set mention — measure relevance before vs after on a fixed query set."
  fi

  # 4) Chunk size declared with no overlap and no token-accurate counting (advisory).
  has_chunk_size=$(grep -Eic 'chunk_size' "$f" 2>/dev/null || true)
  has_overlap=$(grep -Eic 'chunk_overlap|overlap' "$f" 2>/dev/null || true)
  has_token_count=$(grep -Eic 'tiktoken|tokenizer|encoding_name|token.?accurate|from_tiktoken' "$f" 2>/dev/null || true)
  if [ "$has_chunk_size" -gt 0 ] && [ "$has_overlap" -eq 0 ] && [ "$has_token_count" -eq 0 ]; then
    note "chunk_size declared with no overlap and no token-accurate counting — add 10–20% overlap and count tokens (tiktoken/tokenizer), not characters."
  fi
done

if [ "$EXIT" -eq 0 ]; then
  ok "no hard violations"
fi
exit "$EXIT"
