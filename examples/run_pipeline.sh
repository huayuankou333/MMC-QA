#!/usr/bin/env bash
# End-to-end MMC-QA evaluation for a single model.
#
# Usage:
#   export MMCQA_API_KEY=...        MMCQA_BASE_URL=...
#   export MMCQA_JUDGE_API_KEY=...  MMCQA_JUDGE_BASE_URL=...
#   bash examples/run_pipeline.sh gpt-5.2 gemini-3.1-pro pt-PT
set -euo pipefail

MODEL="${1:?usage: run_pipeline.sh <model> <judge-model> [language]}"
JUDGE_MODEL="${2:?usage: run_pipeline.sh <model> <judge-model> [language]}"
LANGUAGE="${3:-}"   # empty = all languages

DATA="data/mmc_qa.jsonl"
SAFE_MODEL="${MODEL//\//_}"
OUT="runs/${SAFE_MODEL}${LANGUAGE:+_$LANGUAGE}"
mkdir -p runs

LANG_FLAG=()
[ -n "$LANGUAGE" ] && LANG_FLAG=(--language "$LANGUAGE")

echo "[1/3] Generating answers with $MODEL ..."
python -m mmc_qa.generate --data "$DATA" "${LANG_FLAG[@]}" \
    --model "$MODEL" --output "${OUT}.jsonl" --workers 8

echo "[2/3] Judging with $JUDGE_MODEL ..."
python -m mmc_qa.judge --responses "${OUT}.jsonl" \
    --judge-model "$JUDGE_MODEL" --output "${OUT}.judged.jsonl" --workers 8

echo "[3/3] Scoring ..."
python -m mmc_qa.score --judged "${OUT}.judged.jsonl" \
    --judge-model "$JUDGE_MODEL" --output "${OUT}.metrics"

echo "Done. Metrics written to ${OUT}.metrics.csv (+ per_language / per_category / json)."
