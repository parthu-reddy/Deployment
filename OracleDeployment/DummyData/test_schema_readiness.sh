#!/usr/bin/env bash
set -eu
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/schema_readiness.sh"
health=healthy mock_result=t query_status=0
service_is_ready() { [ "$health" = healthy ]; }
psql_db() {
    [[ "$2" == *"bool_and(success)"* && "$2" == *"COUNT(*) > 0"* ]] || exit 9
    [[ "$2" == *"table_name='outlets' AND column_name='city_id'"* ]] || exit 9
    printf '%s' "$mock_result"
    return "$query_status"
}
schema_is_ready restaurant_db restaurant-service outlets.city_id
for mock_result in f '' 'connection timeout' 't extra'; do
    if schema_is_ready restaurant_db restaurant-service outlets.city_id; then
        echo "incorrectly accepted: $mock_result" >&2; exit 1
    fi
done
mock_result=t health=starting
if schema_is_ready restaurant_db restaurant-service outlets.city_id; then exit 1; fi
health=healthy query_status=1
if schema_is_ready restaurant_db restaurant-service outlets.city_id; then exit 1; fi
query_status=0
if schema_is_ready restaurant_db restaurant-service "outlets.city_id;bad"; then exit 1; fi
echo 'Schema readiness: healthy/success, incomplete/error/invalid cases passed'
