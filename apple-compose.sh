#!/bin/bash
set -e

COMMAND=$1

if [ "$COMMAND" == "down" ]; then
    echo "Stopping and removing Apple containers..."
    container rm -f shared_zookeeper shared_kafka shared_postgres shared_redis config-service eureka-server-1 identity-service customer-service restaurant-service delivery-service payment-gateway maps-integration communication-integration api-gateway food-delivery-app-ui 2>/dev/null || true
    echo "Done."
    exit 0
fi

if [ "$COMMAND" == "up" ]; then
    shift
    
    if [ -f ".env" ]; then
        echo "Loading .env file..."
        set -a
        source .env
        set +a
    fi
    
    echo "Starting Apple containers..."
    
    # Get host IP for container-to-container communication (since each is its own VM)
    HOST_IP=$(ipconfig getifaddr en0)
    if [ -z "$HOST_IP" ]; then
        HOST_IP=$(ifconfig bridge100 | grep inet | awk '{print $2}')
    fi
    TARGET_SERVICE=$1
    
    echo "Host IP detected as $HOST_IP. Using this for cross-container communication."
    
    if [ -z "$TARGET_SERVICE" ] || [ "$TARGET_SERVICE" == "infra" ]; then
    
    echo "Starting Zookeeper..."
    container run -d --name shared_zookeeper \
        -p 2181:2181 \
        -e ZOOKEEPER_CLIENT_PORT=2181 \
        -e ZOOKEEPER_TICK_TIME=2000 \
        confluentinc/cp-zookeeper:7.5.0
    echo "Waiting 5 seconds for Zookeeper to initialize..."
    sleep 5
        
    echo "Starting Postgres..."
    container run -d --name shared_postgres \
        -p 5432:5432 \
        -e POSTGRES_DB=food_delivery \
        -e POSTGRES_USER="${POSTGRES_USER}" \
        -e POSTGRES_PASS="${POSTGRES_PASS}" \
        -e POSTGRES_PASSWORD="${POSTGRES_PASS}" \
        -e PGDATA=/var/lib/postgresql/data/pgdata \
        -v "$PWD/init-multiple-dbs.sql:/docker-entrypoint-initdb.d/init-multiple-dbs.sql" \
        -v postgres_data:/var/lib/postgresql/data \
        kartoza/postgis:16-3.4
    echo "Waiting 10 seconds for Postgres to initialize..."
    sleep 10
        
    echo "Starting Redis..."
    container run -d --name shared_redis \
        -p 6379:6379 \
        -v redis_data:/data \
        redis:7.2 \
        redis-server --appendonly yes --save 60 1 --loglevel warning
    echo "Waiting 5 seconds for Redis to initialize..."
    sleep 5
        
    echo "Starting Kafka..."
    container run -d --name shared_kafka \
        -p 9092:9092 \
        -p 29092:29092 \
        -e KAFKA_BROKER_ID=1 \
        -e KAFKA_ZOOKEEPER_CONNECT="$HOST_IP:2181" \
        -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:29092,PLAINTEXT_HOST://0.0.0.0:9092 \
        -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://"$HOST_IP":29092,PLAINTEXT_HOST://localhost:9092 \
        -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT \
        -e KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT \
        -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
        confluentinc/cp-kafka:7.5.0
    echo "Waiting 15 seconds for Kafka to initialize..."
    sleep 15
    
    fi # End of infrastructure block
        
    SERVICES=(
        "ConfigService|config-service|8888:8888|spring"
        "EurekaServer|eureka-server-1|8761:8761|spring"
        "IdentityService|identity-service|8086:8086|spring"
        "CustomerApplication|customer-service|8092:8092|spring"
        "RestaurantApplication|restaurant-service|8094:8094|spring"
        "DeliveryExecutiveApplication|delivery-service|8095:8095|spring"
        "PaymentGatewayIntegration|payment-gateway|8085:8085|spring"
        "MapsIntegration|maps-integration|8083:8083|spring"
        "CommunicationIntegration|communication-integration|8081:8081|spring"
        "ApiGateway|api-gateway|8080:8080|spring"
        "FoodDeliveryAppUI|food-delivery-app-ui|3000:80|ui"
    )
    
    DEPLOYMENT_DIR="$PWD"
    
    TARGET_SERVICES=("$@")
    for service_entry in "${SERVICES[@]}"; do
        IFS='|' read -r dir name port type <<< "$service_entry"
        
        if [ ${#TARGET_SERVICES[@]} -gt 0 ] && [ "${TARGET_SERVICES[0]}" != "infra" ]; then
            MATCH=false
            for target in "${TARGET_SERVICES[@]}"; do
                if [ "$target" == "$name" ]; then
                    MATCH=true
                    break
                fi
            done
            if [ "$MATCH" = false ]; then
                continue
            fi
        fi
        
        echo "Starting $name..."
        container rm -f "$name" 2>/dev/null || true
        
        ENV_VARS=""
        if [ "$name" == "config-service" ]; then
            ENV_VARS="-e SPRING_PROFILES_ACTIVE=native -e SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS=file:/config/ -e SPRING_CONFIG_IMPORT=optional:file:/config/config-service.yml -e CONFIG_USER=${CONFIG_USER} -e CONFIG_PASSWORD=${CONFIG_PASSWORD} -e SPRING_SECURITY_USER_NAME=${CONFIG_USER} -e SPRING_SECURITY_USER_PASSWORD=${CONFIG_PASSWORD} -e EUREKA_CLIENT_ENABLED=false -v \"$DEPLOYMENT_DIR:/config\""
        elif [ "$name" == "eureka-server-1" ]; then
            ENV_VARS="-e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_HOSTNAME=$HOST_IP -e EUREKA_CLIENT_REGISTER_WITH_EUREKA=false -e EUREKA_CLIENT_FETCH_REGISTRY=false -e EUREKA_DEFAULT_ZONE=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/"
        elif [ "$name" == "customer-service" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e DB_URL=jdbc:postgresql://$HOST_IP:5432/food_delivery -e DB_USERNAME=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev"
        elif [ "$name" == "restaurant-service" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e DB_URL=jdbc:postgresql://$HOST_IP:5432/restaurant_db -e DB_USERNAME=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e KYB_FSSAI_API_URL=http://$HOST_IP:8080/mock/fssai -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev"
        elif [ "$name" == "delivery-service" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e DB_URL=jdbc:postgresql://$HOST_IP:5432/delivery_db -e DB_USERNAME=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev"
        elif [ "$name" == "payment-gateway" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e PORT=8085 -e DB_URL=jdbc:postgresql://$HOST_IP:5432/payment_db -e DB_USERNAME=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev,debug -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP"
        elif [ "$name" == "maps-integration" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e OLA_MAPS_API_KEY=${OLA_MAPS_API_KEY} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev"
        elif [ "$name" == "communication-integration" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e DB_HOST=$HOST_IP -e DB_PORT=5432 -e DB_NAME=notification_db -e DB_USER=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BROKERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e REDIS_PORT=6379 -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev"
        elif [ "$name" == "api-gateway" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e JWT_PUBLIC_KEY_PATH=file:/certs/public.pem -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e REDIS_HOST=$HOST_IP -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -e SPRING_PROFILES_ACTIVE=dev -v \"$DEPLOYMENT_DIR/certs:/certs\""
        elif [ "$name" == "identity-service" ]; then
            ENV_VARS="-e SPRING_CONFIG_IMPORT=optional:configserver:http://$HOST_IP:8888 -e SPRING_CLOUD_CONFIG_USERNAME=${CONFIG_USER} -e SPRING_CLOUD_CONFIG_PASSWORD=${CONFIG_PASSWORD} -e SPRING_PROFILES_ACTIVE=dev -e JWT_PRIVATE_KEY_PATH=file:/certs/private.pem -e DB_URL=jdbc:postgresql://$HOST_IP:5432/identity_db -e DB_USERNAME=${POSTGRES_USER} -e DB_PASSWORD=${POSTGRES_PASS} -e KAFKA_BOOTSTRAP_SERVERS=$HOST_IP:29092 -e REDIS_HOST=$HOST_IP -e EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@$HOST_IP:8761/eureka/ -e EUREKA_USER=${EUREKA_USER:-admin} -e EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin} -e EUREKA_INSTANCE_IP_ADDRESS=$HOST_IP -v \"$DEPLOYMENT_DIR/certs:/certs\""
        elif [ "$name" == "food-delivery-app-ui" ]; then
            ENV_VARS="-e VITE_API_GATEWAY_URL=http://$HOST_IP:8080 -e VITE_MAPS_API_KEY=${OLA_MAPS_API_KEY}"
        fi
        
        (cd "../$dir" && eval "./run_container.sh --apple -d  --name \"$name\" -p \"$port\" $ENV_VARS")
        
        if [ "$name" == "config-service" ] && [ ${#TARGET_SERVICES[@]} -eq 0 ]; then
            echo "Waiting for config-service to be healthy..."
            while ! curl -s -u "${CONFIG_USER}:${CONFIG_PASSWORD}" http://localhost:8888/actuator/health | grep -q 'UP'; do sleep 2; done
            echo "config-service is healthy!"
        elif [ "$name" == "eureka-server-1" ] && [ ${#TARGET_SERVICES[@]} -eq 0 ]; then
            echo "Waiting for eureka-server to be healthy..."
            while ! curl -s -u "${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}" http://localhost:8761/actuator/health | grep -q 'UP'; do sleep 2; done
            echo "eureka-server is healthy!"
        fi
    done
    
    echo "All Apple containers started."
    exit 0
fi

echo "Usage: ./apple-compose.sh [up|down]"
exit 1
