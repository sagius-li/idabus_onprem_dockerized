#!/bin/sh
set -eu

ES_WAIT_RETRIES="${ES_WAIT_RETRIES:-60}"
ES_WAIT_INTERVAL_SECONDS="${ES_WAIT_INTERVAL_SECONDS:-1}"

attempt=1
while [ "$attempt" -le "$ES_WAIT_RETRIES" ]; do
  status=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:"$ELASTIC_PASSWORD" http://elasticsearch:9200 || true)

  if [ "$status" = "200" ]; then
    break
  fi

  if [ "$status" = "401" ] || [ "$status" = "403" ]; then
    echo "Elastic authentication failed while waiting for Elasticsearch (status=$status)" >&2
    exit 1
  fi

  if [ "$attempt" -eq "$ES_WAIT_RETRIES" ]; then
    echo "Elasticsearch did not become ready after ${ES_WAIT_RETRIES} attempts" >&2
    exit 1
  fi

  sleep "$ES_WAIT_INTERVAL_SECONDS"
  attempt=$((attempt + 1))
done

auth_status=$(curl -s -o /dev/null -w "%{http_code}" \
  -u kibana_system:"$KIBANA_SYSTEM_PASSWORD" \
  http://elasticsearch:9200/_security/_authenticate || true)

if [ "$auth_status" = "200" ]; then
  echo "kibana_system password already valid; skipping reset"
  exit 0
fi

if [ "$auth_status" != "401" ] && [ "$auth_status" != "403" ]; then
  echo "Unexpected response while validating kibana_system credentials (status=$auth_status)" >&2
  exit 1
fi

reset_status=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:"$ELASTIC_PASSWORD" \
  -X POST http://elasticsearch:9200/_security/user/kibana_system/_password \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$KIBANA_SYSTEM_PASSWORD\"}")

if [ "$reset_status" != "200" ] && [ "$reset_status" != "204" ]; then
  echo "Failed to set kibana_system password (status=$reset_status)" >&2
  exit 1
fi

post_auth_status=$(curl -s -o /dev/null -w "%{http_code}" \
  -u kibana_system:"$KIBANA_SYSTEM_PASSWORD" \
  http://elasticsearch:9200/_security/_authenticate || true)

if [ "$post_auth_status" != "200" ]; then
  echo "kibana_system password verification failed after reset (status=$post_auth_status)" >&2
  exit 1
fi

echo "kibana_system password set and verified"
