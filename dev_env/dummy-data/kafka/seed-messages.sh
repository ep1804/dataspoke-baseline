#!/usr/bin/env bash
# seed-messages.sh — Produce ~45 JSON messages to Kafka topics.
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

produce_messages() {
  local topic="$1"
  shift
  local messages=("$@")
  local payload
  payload=$(printf '%s\n' "${messages[@]}")
  echo "${payload}" | kubectl exec -i -n "${NS}" "${KAFKA_POD}" -- \
    "${KAFKA_BIN}/kafka-console-producer.sh" \
    --bootstrap-server "${BOOTSTRAP}" \
    --topic "${topic}"
}

# --- imazon.orders.events (20 messages) ---
info "Producing messages to imazon.orders.events..."
ORDER_EVENTS=(
  '{"event_id":"evt-001","order_id":"ORD-2024-00001","event_type":"placed","timestamp":"2024-11-01T09:12:00Z","items":[{"edition_id":1,"qty":1},{"edition_id":4,"qty":1}],"total":34.98}'
  '{"event_id":"evt-002","order_id":"ORD-2024-00001","event_type":"confirmed","timestamp":"2024-11-01T09:15:00Z","warehouse":"WH-East"}'
  '{"event_id":"evt-003","order_id":"ORD-2024-00001","event_type":"shipped","timestamp":"2024-11-02T08:00:00Z","carrier":"UPS","tracking":"1Z999AA10001"}'
  '{"event_id":"evt-004","order_id":"ORD-2024-00001","event_type":"delivered","timestamp":"2024-11-04T14:30:00Z","signed_by":"E. Smith"}'
  '{"event_id":"evt-005","order_id":"ORD-2024-00002","event_type":"placed","timestamp":"2024-11-02T14:30:00Z","items":[{"edition_id":5,"qty":1}],"total":13.29}'
  '{"event_id":"evt-006","order_id":"ORD-2024-00002","event_type":"confirmed","timestamp":"2024-11-02T14:35:00Z","warehouse":"WH-West"}'
  '{"event_id":"evt-007","order_id":"ORD-2024-00002","event_type":"shipped","timestamp":"2024-11-03T10:00:00Z","carrier":"FedEx","tracking":"FX100200300"}'
  '{"event_id":"evt-008","order_id":"ORD-2024-00002","event_type":"delivered","timestamp":"2024-11-05T11:00:00Z","signed_by":"M. Jones"}'
  '{"event_id":"evt-009","order_id":"ORD-2024-00003","event_type":"placed","timestamp":"2024-11-03T11:45:00Z","items":[{"edition_id":7,"qty":1},{"edition_id":9,"qty":1}],"total":40.98}'
  '{"event_id":"evt-010","order_id":"ORD-2024-00003","event_type":"confirmed","timestamp":"2024-11-03T11:50:00Z","warehouse":"WH-East"}'
  '{"event_id":"evt-011","order_id":"ORD-2024-00003","event_type":"shipped","timestamp":"2024-11-04T09:00:00Z","carrier":"DHL","tracking":"DH5001001"}'
  '{"event_id":"evt-012","order_id":"ORD-2024-00003","event_type":"delivered","timestamp":"2024-11-06T16:20:00Z","signed_by":"A. Weber"}'
  '{"event_id":"evt-013","order_id":"ORD-2024-00004","event_type":"placed","timestamp":"2024-11-04T08:20:00Z","items":[{"edition_id":10,"qty":1}],"total":29.69}'
  '{"event_id":"evt-014","order_id":"ORD-2024-00004","event_type":"confirmed","timestamp":"2024-11-04T08:25:00Z","warehouse":"WH-East"}'
  '{"event_id":"evt-015","order_id":"ORD-2024-00004","event_type":"shipped","timestamp":"2024-11-05T07:30:00Z","carrier":"UPS","tracking":"1Z999AA10002"}'
  '{"event_id":"evt-016","order_id":"ORD-2024-00004","event_type":"delivered","timestamp":"2024-11-07T13:45:00Z","signed_by":"L. Kim"}'
  '{"event_id":"evt-017","order_id":"ORD-2024-00005","event_type":"placed","timestamp":"2024-11-05T16:55:00Z","items":[{"edition_id":11,"qty":1}],"total":29.99}'
  '{"event_id":"evt-018","order_id":"ORD-2024-00005","event_type":"confirmed","timestamp":"2024-11-05T17:00:00Z","warehouse":"WH-West"}'
  '{"event_id":"evt-019","order_id":"ORD-2024-00005","event_type":"shipped","timestamp":"2024-11-06T08:15:00Z","carrier":"FedEx","tracking":"FX100200301"}'
  '{"event_id":"evt-020","order_id":"ORD-2024-00005","event_type":"delivered","timestamp":"2024-11-08T10:30:00Z","signed_by":"T. Nguyen"}'
)
produce_messages "imazon.orders.events" "${ORDER_EVENTS[@]}"
info "  Produced 20 messages to imazon.orders.events"

# --- imazon.shipping.updates (15 messages) ---
info "Producing messages to imazon.shipping.updates..."
SHIPPING_UPDATES=(
  '{"tracking":"1Z999AA10001","carrier":"UPS","order_id":"ORD-2024-00001","status":"picked_up","timestamp":"2024-11-01T18:00:00Z","location":"New York, NY"}'
  '{"tracking":"1Z999AA10001","carrier":"UPS","order_id":"ORD-2024-00001","status":"in_transit","timestamp":"2024-11-02T06:00:00Z","location":"Philadelphia, PA"}'
  '{"tracking":"1Z999AA10001","carrier":"UPS","order_id":"ORD-2024-00001","status":"delivered","timestamp":"2024-11-04T14:30:00Z","location":"Boston, MA"}'
  '{"tracking":"FX100200300","carrier":"FedEx","order_id":"ORD-2024-00002","status":"picked_up","timestamp":"2024-11-02T20:00:00Z","location":"Los Angeles, CA"}'
  '{"tracking":"FX100200300","carrier":"FedEx","order_id":"ORD-2024-00002","status":"in_transit","timestamp":"2024-11-03T08:00:00Z","location":"Phoenix, AZ"}'
  '{"tracking":"FX100200300","carrier":"FedEx","order_id":"ORD-2024-00002","status":"delivered","timestamp":"2024-11-05T11:00:00Z","location":"Denver, CO"}'
  '{"tracking":"DH5001001","carrier":"DHL","order_id":"ORD-2024-00003","status":"picked_up","timestamp":"2024-11-04T07:00:00Z","location":"Chicago, IL"}'
  '{"tracking":"DH5001001","carrier":"DHL","order_id":"ORD-2024-00003","status":"in_transit","timestamp":"2024-11-05T12:00:00Z","location":"Detroit, MI"}'
  '{"tracking":"DH5001001","carrier":"DHL","order_id":"ORD-2024-00003","status":"delivered","timestamp":"2024-11-06T16:20:00Z","location":"Cleveland, OH"}'
  '{"tracking":"1Z999AA10002","carrier":"UPS","order_id":"ORD-2024-00004","status":"picked_up","timestamp":"2024-11-05T06:00:00Z","location":"Houston, TX"}'
  '{"tracking":"1Z999AA10002","carrier":"UPS","order_id":"ORD-2024-00004","status":"in_transit","timestamp":"2024-11-06T10:00:00Z","location":"Dallas, TX"}'
  '{"tracking":"1Z999AA10002","carrier":"UPS","order_id":"ORD-2024-00004","status":"delivered","timestamp":"2024-11-07T13:45:00Z","location":"Austin, TX"}'
  '{"tracking":"FX100200304","carrier":"FedEx","order_id":"ORD-2024-00015","status":"in_transit","timestamp":"2024-11-17T22:00:00Z","location":"Oakland, CA"}'
  '{"tracking":"FX100200304","carrier":"FedEx","order_id":"ORD-2024-00015","status":"delayed","timestamp":"2024-11-18T10:00:00Z","location":"Customs, CA","reason":"Customs clearance delay"}'
  '{"tracking":"1Z999AA10010","carrier":"UPS","order_id":"ORD-2024-00035","status":"delayed","timestamp":"2024-12-07T06:00:00Z","location":"Louisville, KY","reason":"Mechanical delay at sort facility"}'
)
produce_messages "imazon.shipping.updates" "${SHIPPING_UPDATES[@]}"
info "  Produced 15 messages to imazon.shipping.updates"

# --- imazon.reviews.new (10 messages) ---
info "Producing messages to imazon.reviews.new..."
REVIEW_MESSAGES=(
  '{"review_id":"rev-001","edition_id":1,"user_id":"user_301","rating":5,"title":"Unputdownable!","text":"Could not stop reading. Best thriller of the year.","timestamp":"2025-01-10T08:00:00Z"}'
  '{"review_id":"rev-002","edition_id":3,"user_id":"user_302","rating":4,"title":"Great sci-fi","text":"Loved the world-building and hard science elements.","timestamp":"2025-01-11T10:30:00Z"}'
  '{"review_id":"rev-003","edition_id":7,"user_id":"user_303","rating":5,"title":"Fantasy masterpiece","text":"The Dragon Codex trilogy is the best fantasy I have read in years.","timestamp":"2025-01-12T14:00:00Z"}'
  '{"review_id":"rev-004","edition_id":14,"user_id":"user_304","rating":5,"title":"Kids love it","text":"My children ask for this every bedtime. Beautiful illustrations.","timestamp":"2025-01-13T07:15:00Z"}'
  '{"review_id":"rev-005","edition_id":20,"user_id":"user_305","rating":4,"title":"Solid sequel","text":"The Frost Blade continues the story well, though pacing dips in the middle.","timestamp":"2025-01-14T09:45:00Z"}'
  '{"review_id":"rev-006","edition_id":24,"user_id":"user_306","rating":5,"title":"Mind-bending","text":"Marcus Chen does it again. The Pocket Universe is brilliant.","timestamp":"2025-01-15T11:00:00Z"}'
  '{"review_id":"rev-007","edition_id":31,"user_id":"user_307","rating":5,"title":"AI explained well","text":"Neural Paths makes complex AI concepts accessible to everyone.","timestamp":"2025-01-16T13:30:00Z"}'
  '{"review_id":"rev-008","edition_id":35,"user_id":"user_308","rating":4,"title":"Thrilling cyber story","text":"Zero Day keeps you on the edge. Vasquez is a master of suspense.","timestamp":"2025-01-17T15:00:00Z"}'
  '{"review_id":"rev-009","edition_id":38,"user_id":"user_309","rating":5,"title":"Poetic and beautiful","text":"The Clockwork Forest is hauntingly beautiful. Dubois at her best.","timestamp":"2025-01-18T08:30:00Z"}'
  '{"review_id":"rev-010","edition_id":39,"user_id":"user_310","rating":5,"title":"Adorable!","text":"Space Puppies is the cutest book ever. My toddler is obsessed.","timestamp":"2025-01-19T07:00:00Z"}'
)
produce_messages "imazon.reviews.new" "${REVIEW_MESSAGES[@]}"
info "  Produced 10 messages to imazon.reviews.new"

info "Kafka seed messages complete (45 total)."
