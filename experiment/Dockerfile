# Build stage
FROM rust:bookworm AS builder
WORKDIR /usr/src/app

# Copy source and build the release binary
COPY . .
RUN cargo install --path .

# Run stage
FROM debian:bookworm-slim
# Install CA certificates required for HTTPS requests to AWS S3
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app/results
COPY --from=builder /usr/src/app/target/release/my_experiment /usr/local/bin/my_experiment

# The executable will use environment variables passed by docker-compose or AWS Batch
ENTRYPOINT ["my_experiment"]
