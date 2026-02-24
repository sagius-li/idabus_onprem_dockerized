#!/bin/sh
set -eu

until curl -fsS -u elastic:"$ELASTIC_PASSWORD" http://elasticsearch:9200 >/dev/null; do
  sleep 2
done

curl -fsS -u elastic:"$ELASTIC_PASSWORD" \
  -X POST http://elasticsearch:9200/_security/user/kibana_system/_password \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$KIBANA_SYSTEM_PASSWORD\"}" >/dev/null
