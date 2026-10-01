#!/usr/bin/env bash
# Shared by both wait paths. Callers provide psql_db, SSH_KEY, VM and COMPOSE_DIR.
service_is_ready() {
    local state
    state="$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=20 -i "$SSH_KEY" "$VM" \
        "cd '$COMPOSE_DIR' && container_id=\$(docker compose ps -q '$1') && [ -n \"\$container_id\" ] && docker inspect --format '{{.State.Health.Status}}' \"\$container_id\"" \
        </dev/null 2>/dev/null)" || return 1
    [ "$state" = healthy ]
}

schema_is_ready() { # database, owning service, table or table.column
    local db="$1" owner="$2" sentinel="$3" predicate result table column
    [[ "$db" =~ ^[a-z_]+$ && "$owner" =~ ^[a-z0-9-]+$ && "$sentinel" =~ ^[a-z_]+(\.[a-z_]+)?$ ]] || return 1
    service_is_ready "$owner" || return 1
    if [[ "$sentinel" == *.* ]]; then
        table="${sentinel%.*}"; column="${sentinel#*.}"
        predicate="EXISTS (SELECT FROM information_schema.columns WHERE table_schema='public' AND table_name='$table' AND column_name='$column')"
    else
        predicate="EXISTS (SELECT FROM information_schema.tables WHERE table_schema='public' AND table_name='$sentinel')"
    fi
    # Missing history, failed queries, failed migrations and an empty history all mean not ready.
    # Spring's healthy application has completed startup; the sentinel additionally guards drift.
    result="$(psql_db "$db" "SELECT ($predicate) AND (SELECT COUNT(*) > 0 AND COALESCE(bool_and(success), false) FROM public.flyway_schema_history);")" || return 1
    [ "$result" = t ]
}
