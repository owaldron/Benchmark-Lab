#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
BUCKET="${1:-${S3_BUCKET:-}}"
REGION="${AWS_REGION:-us-east-2}"
RUN_KEY="${RUN_KEY:-run-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

# Create unique results directory for this run
RUN_DIR="$SCRIPT_DIR/results/$RUN_KEY"
mkdir -p "$RUN_DIR"
RESULTS_PATH="$RUN_DIR/results.json"
HARDWARE_PATH="$RUN_DIR/hardware.json"

echo "=== Run Key: $RUN_KEY ==="
echo "Results directory: $RUN_DIR"

# Collect hardware info
"$SCRIPT_DIR/collect_hardware.sh" "$HARDWARE_PATH"

# Build and run
echo "Building and running experiment via Docker Compose..."
docker compose -f "$COMPOSE_FILE" up --build --abort-on-container-exit
echo "Container finished successfully."

# Move container output into the run directory
CONTAINER_RESULTS="$SCRIPT_DIR/results/results.json"
if [[ -f "$CONTAINER_RESULTS" ]]; then
  mv "$CONTAINER_RESULTS" "$RESULTS_PATH"
fi

# Print results
if [[ ! -f "$RESULTS_PATH" ]]; then
  echo "Error: results.json not found at $RESULTS_PATH"
  exit 1
fi

echo "Results:"
cat "$RESULTS_PATH"

# Upload to S3
if [[ -n "$BUCKET" ]]; then
  S3_PREFIX="benchmark-results/$RUN_KEY"
  echo "Uploading results to s3://$BUCKET/$S3_PREFIX/ ($REGION)..."
  aws s3 cp "$RESULTS_PATH" "s3://$BUCKET/$S3_PREFIX/results.json" --region "$REGION"
  aws s3 cp "$HARDWARE_PATH" "s3://$BUCKET/$S3_PREFIX/hardware.json" --region "$REGION"
  echo "Upload complete."
else
  echo "No bucket specified; skipping S3 upload."
fi
