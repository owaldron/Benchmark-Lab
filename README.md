# Benchmark-Lab

This repo is meant to serve as a flexible emperiment framework designed to run performance benchmarks or general computing experiments.
The provided scripts are meant to make it easy to run on varying hardware and reproduce results.
It provides a standardized way to execute your code either **locally** using Docker Compose or **in the cloud** using AWS Batch.

## Prerequisites

Before using the repository, ensure you have the following installed:

1. **[Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/install/)**: Required to build the experiment images and run them locally.
2. **[AWS CLI](https://aws.amazon.com/cli/)**: Required if you plan to run experiments in `batch` mode on AWS. You must authenticate via `aws configure` or standard AWS environment variables.
3. **[jq](https://stedolan.github.io/jq/)**: A command-line JSON processor required by the deployment script to dynamically modify AWS Batch job definitions.
4. **Bash environment**: The scripts are written in bash (`run_experiments.sh`).

*Note: While the sample experiment is written in Rust, you don't strictly need Rust installed on your host machine to run it, as the compilation happens inside the Docker container.*

---

## Directory Structure & Code Changes

All experiment-specific code lives in the `experiment/` directory. If you are starting a new benchmark, these are the files you will modify:

### 1. The Application Code (`experiment/src/main.rs` & `experiment/Cargo.toml`)
This repository comes with a sample Rust application.
*   **`main.rs`**: Replace the logic here with the system or algorithm you want to benchmark.
*   **`Cargo.toml`**: Add any dependencies your Rust project requires.

### 2. The Container Definition (`experiment/Dockerfile`)
The Dockerfile defines the environment where your experiment runs.
*   If your benchmark requires specific system packages (like Python, CUDA, or specific C libraries), add the installation commands (`apt-get install ...`) here.
*   The default Dockerfile compiles the Rust project and sets up the entrypoint scripts.

### 3. Execution Scripts
*   **`experiment/my_test.sh`**: This is the main entry script executed when the container starts. It typically invokes your compiled binary (e.g., `./target/release/my_experiment`). You can modify this to pass different arguments to your application, loop over test iterations, or trigger other scripts.
*   **`experiment/collect_hardware.sh`**: Runs before the experiment to log CPU, memory, and (optionally) GPU details into a `hardware.json` file. You can extend this if you need to capture more specialized metrics.

---

## AWS Setup

To run experiments in `batch` mode on AWS, you need to configure several cloud resources beforehand. These can be created via the AWS Console, AWS CLI, or infrastructure-as-code tools like Terraform/CDK.

### 1. Elastic Container Registry (ECR)
Create an ECR repository to store your Docker images. This registry will hold the compiled environment for your experiment.
```bash
aws ecr create-repository --repository-name benchmark-lab-test --region us-east-2
```
*Update `ECR_REPO` in `config.env` with the resulting `repositoryUri` limit string.*

### 2. AWS Batch Compute Environment & Job Queue
Before submitting jobs, AWS Batch requires a designated queue linked to actual computing infrastructure.
1. **Compute Environment**: Create a Managed Compute Environment in AWS Batch. You can back it with EC2 instances, Fargate, or cost-saving spot instances depending on your experiment's hardware requirements (e.g., GPUs). Ensure the networking (VPC, Subnets) allows outbound internet access to pull the Docker image.
2. **Job Queue**: Create a Job Queue and associate it with one or more Compute Environments.

*Update `BATCH_JOB_QUEUE` in `config.env` with the name of this Job Queue.*

### 3. AWS Batch Job Definition (Base)
Create a "base" Job Definition. The `run_experiments.sh` script dynamically updates this definition by creating new revisions on every run, automatically injecting the newly tagged Docker image URI and runtime environment variables.
* **Platform Type**: Choose Fargate or EC2 (ensure this matches your Compute Environment).
* **Execution Role**: Provide an ECS Task Execution Role that has IAM permissions to pull the image from ECR and stream logs to Amazon CloudWatch.
* **Job Role**: Provide a Task IAM Role with permissions to access your AWS resources (specifically, `s3:PutObject` for writing metrics to your `S3_BUCKET`).
* **Container Properties**: You can specify a minimal dummy image (like `alpine`) and base vCPUs/Memory. The deployment script dynamically overrides the image, and CLI args can overwrite the compute requirements per job submission.

*Update `BATCH_JOB_DEFINITION` in `config.env` with the name of this job definition.*

### 4. Amazon S3 Bucket
Create an S3 bucket to store the experiment results. The container uses AWS credentials to upload `results.json` and `hardware.json` back to this bucket once the experiment finishes.
```bash
aws s3api create-bucket --bucket benchmark-lab-results-test --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
```
*Ensure the Task IAM Role assigned in step 3 has write access (`s3:PutObject`) to this bucket, and update `S3_BUCKET` and `S3_PREFIX` in `config.env` with your bucket details.*

---

## Configuration (`config.env`)

The `config.env` file located in the root directory manages the global defaults for your infrastructure and test runs. 

Key configurations include:

*   **`EXPERIMENT_MODE`**: Set to `"local"` to run on your machine, or `"batch"` to push to AWS and run on AWS Batch.
*   **AWS Configuration**: Set your desired `AWS_REGION`, `S3_BUCKET`, and `S3_PREFIX` (used to store results).
*   **ECR & Batch**: 
    *   `ECR_REPO`: The AWS Elastic Container Registry URI where the Docker image will be pushed.
    *   `BATCH_JOB_DEFINITION` & `BATCH_JOB_QUEUE`: The target AWS Batch queue and job definition.
*   **Resource Overrides (Batch only)**: `BATCH_VCPUS`, `BATCH_MEMORY`, and `BATCH_GPUS` let you easily request larger EC2 instances for heavy benchmarks without modifying the underlying AWS Job Definition manually.

### Best Practice
Commit base/safe defaults to `config.env`. Avoid committing temporary tweaks; instead, override them using CLI arguments via the deployment script.

---

## Running Experiments

Use the `./run_experiments.sh` script to execute your benchmark. This script sources `config.env` but allows you to override any variable via command-line arguments.

### Local Execution

To test your code locally on your machine:

```bash
./run_experiments.sh --mode local
```

**What it does:**
1. Generates a unique `RUN_KEY` (e.g., `run-2026...`).
2. Triggers `docker compose up --build` on the `experiment/` directory.
3. Automatically maps standard outputs (`results.json`, `hardware.json`) out of the container volume into a local timestamped `/experiment/results/...` directory for your review.

### Cloud Execution (AWS Batch)

To run the experiment asynchronously on AWS:

```bash
./run_experiments.sh --mode batch --vcpus 8 --memory 32768
```

**What it does:**
1. Authenticates your local Docker daemon with your AWS ECR registry.
2. Builds the `experiment` directory specifically for `linux/amd64` architecture.
3. Tags and pushes the Docker image to your defined `ECR_REPO`.
4. Uses `jq` to dynamically create a *new* revision of your AWS Batch `BATCH_JOB_DEFINITION` that points to the freshly pushed container image.
5. Submits an AWS Batch Job to the `BATCH_JOB_QUEUE`, injecting the environmental variables (like S3 info and the `RUN_KEY`) and any provided resource overrides (`--vcpus`, `--memory`).

### CLI Argument Reference

You can override `config.env` using these flags:
*   `--mode [local|batch]`
*   `--bucket [S3_BUCKET_NAME]`
*   `--region [AWS_REGION]`
*   `--ecr-repo [ECR_URI]`
*   `--job-def [BATCH_JOB_DEF_NAME]`
*   `--queue [BATCH_QUEUE_NAME]`
*   `--vcpus [INT]`
*   `--memory [INT_MIB]`
*   `--gpus [INT]`