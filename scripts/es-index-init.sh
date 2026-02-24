#!/bin/sh
set -eu

until curl -fsS -u elastic:"$ELASTIC_PASSWORD" http://elasticsearch:9200 >/dev/null; do
  sleep 2
done

for index in events eventsarchive resources workflowexecution; do
  status=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:"$ELASTIC_PASSWORD" -I "http://elasticsearch:9200/$index")

  if [ "$status" = "200" ]; then
    echo "Index $index already exists; skipping"
  elif [ "$status" = "404" ]; then
    echo "Creating index $index"
    create_status=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:"$ELASTIC_PASSWORD" \
      -X PUT "http://elasticsearch:9200/$index" \
      -H "Content-Type: application/json" \
      --data-binary @- <<'JSON'
        {
          "settings": {
            "number_of_shards": 1,
            "index.mapping.ignore_malformed": true,
            "index.mapping.total_fields.limit": 2500,
            "analysis": {
              "normalizer": {
                "string_normalizer": {
                  "type": "custom",
                  "char_filter": [],
                  "filter": ["lowercase", "asciifolding"]
                }
              }
            }
          },
          "mappings": {
            "date_detection": false,
            "dynamic_templates": [
              {
                "ignore_x_fields": {
                  "path_match": "x_*",
                  "mapping": {"type": "object", "enabled": false}
                }
              },
              {
                "ignore_nested_x_fields": {
                  "path_match": "*.x_*",
                  "mapping": {"type": "object", "enabled": false}
                }
              },
              {
                "string_fields": {
                  "match": "s_*",
                  "mapping": {
                    "type": "keyword",
                    "normalizer": "string_normalizer",
                    "ignore_above": 1024
                  }
                }
              },
              {
                "all_other_strings": {
                  "match_mapping_type": "string",
                  "mapping": {"type": "keyword", "ignore_above": 1024}
                }
              }
            ]
          }
        }
JSON
)
    if [ "$create_status" != "200" ] && [ "$create_status" != "201" ]; then
      echo "Failed creating index $index (status=$create_status)" >&2
      exit 1
    fi
  else
    echo "Unexpected status $status while checking index $index" >&2
    exit 1
  fi
done
