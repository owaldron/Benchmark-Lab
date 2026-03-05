#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# my_test.sh — Container entrypoint for the benchmark experiment.
# Runs INSIDE the Docker container (both local and AWS Batch).
#
# Expected environment variables:
#   RUN_KEY     — unique identifier for this run
#   S3_BUCKET   — (optional) S3 bucket for uploading results
#   S3_PREFIX   — (optional) key prefix in the bucket (default: benchmark-results)
#   AWS_REGION  — (optional) AWS region (default: us-east-2)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REGION="${AWS_REGION:-us-east-2}"
RUN_KEY="${RUN_KEY:-run-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
S3_KEY_PREFIX="${S3_PREFIX:-benchmark-results}"

# Set up results paths
RESULTS_DIR="/app/results"
RESULTS_PATH="$RESULTS_DIR/results.json"
HARDWARE_PATH="$RESULTS_DIR/hardware.json"

mkdir -p "$RESULTS_DIR"

echo "=== Run Key: $RUN_KEY ==="
echo "Results directory: $RESULTS_DIR"

# 1. Collect hardware info
if [[ -f "$SCRIPT_DIR/collect_hardware.sh" ]]; then
  echo "Collecting hardware info..."
  "$SCRIPT_DIR/collect_hardware.sh" "$HARDWARE_PATH"
else
  echo "Warning: collect_hardware.sh not found; skipping hardware collection."
fi

# 2. Run the experiment
echo "Running experiment..."
my_experiment "$RESULTS_PATH"

# 3. Print results
if [[ ! -f "$RESULTS_PATH" ]]; then
  echo "Error: results.json not found at $RESULTS_PATH"
  exit 1
fi

echo "Results:"
cat "$RESULTS_PATH"

# 4. Upload to S3 (Only in batch mode)
# In local mode, we assume the user wants the results on disk, not uploaded.
if [[ "${RUN_MODE:-local}" == "batch" ]]; then
  if [[ -n "${S3_BUCKET:-}" ]]; then
    S3_DEST="$S3_KEY_PREFIX/$RUN_KEY"
    echo "Uploading results to s3://$S3_BUCKET/$S3_DEST/ ($REGION)..."
    aws s3 cp "$RESULTS_PATH" "s3://$S3_BUCKET/$S3_DEST/results.json" --region "$REGION"
    if [[ -f "$HARDWARE_PATH" ]]; then
      aws s3 cp "$HARDWARE_PATH" "s3://$S3_BUCKET/$S3_DEST/hardware.json" --region "$REGION"
    fi
    echo "Upload complete."
  else
    echo "No S3_BUCKET set; skipping upload."
  fi
else
  echo "Running in local mode; skipping S3 upload."
fi

echo "Experiment finished successfully."
