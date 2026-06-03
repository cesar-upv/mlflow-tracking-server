#!/bin/sh
set -eu

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${MINIO_ENDPOINT:=http://storage:9000}"

echo "Waiting for MinIO at ${MINIO_ENDPOINT}..."

until mc alias set local "${MINIO_ENDPOINT}" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"; do
  echo "MinIO is not ready yet. Retrying..."
  sleep 2
done

until mc ready local; do
  echo "MinIO API is not ready yet. Retrying..."
  sleep 2
done

echo "Creating bucket if missing: ${S3_BUCKET}"
mc mb --ignore-existing "local/${S3_BUCKET}"

echo "Bucket is ready: ${S3_BUCKET}"
