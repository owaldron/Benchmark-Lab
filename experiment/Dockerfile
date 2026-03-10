# Build stage
FROM rust:1-bookworm AS builder
WORKDIR /usr/src/app

# Copy source and build the release binary
COPY . .
RUN cargo install --path .

# Run stage
FROM debian:bookworm-slim
# Install CA certificates, AWS CLI, and util-linux (lscpu)
RUN apt-get update && \
    apt-get install -y ca-certificates awscli util-linux && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /usr/src/app/target/release/my_experiment /usr/local/bin/my_experiment
COPY collect_hardware.sh /app/collect_hardware.sh
COPY my_test.sh /app/my_test.sh

RUN chmod +x /app/collect_hardware.sh /app/my_test.sh

# my_test.sh orchestrates: hardware collection -> experiment -> S3 upload
ENTRYPOINT ["/app/my_test.sh"]
