#!/usr/bin/env bash
# init-topics.sh — Delete and recreate Kafka topics for dummy data.
# Called by dummy-data-reset.sh; do not run standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/helpers.sh"
source "$SCRIPT_DIR/../../.env"

NS="${DATASPOKE_DEV_KUBE_DUMMY_DATA_NAMESPACE}"

KAFKA_POD=$(kubectl get pod -l app=example-kafka -n "${NS}" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) \
  || error "No example-kafka pod found in namespace '${NS}'."

BOOTSTRAP="localhost:9092"
KAFKA_BIN="/opt/kafka/bin"

TOPICS=(
  "imazon.orders.events"
  "imazon.shipping.updates"
  "imazon.reviews.new"
)

info "Deleting existing topics (if any)..."
for topic in "${TOPICS[@]}"; do
  kubectl exec -n "${NS}" "${KAFKA_POD}" -- \
    "${KAFKA_BIN}/kafka-topics.sh" \
    --bootstrap-server "${BOOTSTRAP}" \
    --delete --topic "${topic}" 2>/dev/null || true
done

# Brief pause to let deletions propagate
sleep 2

info "Creating topics..."
for topic in "${TOPICS[@]}"; do
  kubectl exec -n "${NS}" "${KAFKA_POD}" -- \
    "${KAFKA_BIN}/kafka-topics.sh" \
    --bootstrap-server "${BOOTSTRAP}" \
    --create \
    --topic "${topic}" \
    --partitions 1 \
    --replication-factor 1
  info "  Created topic: ${topic}"
done

info "Verifying topics..."
kubectl exec -n "${NS}" "${KAFKA_POD}" -- \
  "${KAFKA_BIN}/kafka-topics.sh" \
  --bootstrap-server "${BOOTSTRAP}" \
  --list

info "Kafka topics initialized."
