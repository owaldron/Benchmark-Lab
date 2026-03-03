#!/bin/bash
set -e

# Default configurations
MODE="local"
BUCKET=""
REGION="us-east-2"
JOB_DEF="benchmark-job-definition:1"
JOB_QUEUE="benchmark-gpu-queue"

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift ;;
        --bucket) BUCKET="$2"; shift ;;
        --region) REGION="$2"; shift ;;
        --job-def) JOB_DEF="$2"; shift ;;
        --queue) JOB_QUEUE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$BUCKET" ] && [ "$MODE" == "batch" ]; then
    echo "Error: --bucket is required for batch mode."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$SCRIPT_DIR/experiment"

# Generate a unique key for this run
RUN_KEY="run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
echo "=== Run Key: $RUN_KEY ==="

if [ "$MODE" == "local" ]; then
    echo "Starting local benchmark run..."
    export S3_BUCKET=$BUCKET
    export AWS_REGION=$REGION
    export RUN_KEY

    "$EXPERIMENT_DIR/my_test.sh"

elif [ "$MODE" == "batch" ]; then
    echo "Submitting benchmark job to AWS Batch..."
    
    # Submit job and override the container environment variables dynamically
    aws batch submit-job \
        --job-name "benchmark-run-$(date +%s)" \
        --job-queue "$JOB_QUEUE" \
        --job-definition "$JOB_DEF" \
        --region "$REGION" \
        --container-overrides "{
            \"environment\": [
                {\"name\": \"RUN_MODE\", \"value\": \"batch\"},
                {\"name\": \"S3_BUCKET\", \"value\": \"$BUCKET\"},
                {\"name\": \"AWS_REGION\", \"value\": \"$REGION\"},
                {\"name\": \"RUN_KEY\", \"value\": \"$RUN_KEY\"}
            ]
        }"
    
    echo "Job submitted successfully to $JOB_QUEUE."
else
    echo "Invalid mode. Use '--mode local' or '--mode batch'."
    exit 1
fi
