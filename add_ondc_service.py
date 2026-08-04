import yaml

with open('docker-compose.yml', 'r') as f:
    data = yaml.safe_load(f)

data['services']['ondc-integration-service'] = {
    'build': {
        'context': '../',
        'dockerfile': 'ONDCIntegrationService/Dockerfile'
    },
    'container_name': 'ondc-integration-service',
    'ports': ['8098:8098'], # Let's say 8098
    'environment': [
        'SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE:-default}',
        'CONFIG_SERVER_URL=http://${CONFIG_USER}:${CONFIG_PASSWORD}@config-service:8888',
        'DB_URL=jdbc:postgresql://postgres:5432/ondc_db',
        'DB_USERNAME=${POSTGRES_USER}',
        'DB_PASSWORD=${POSTGRES_PASS}',
        'KAFKA_BOOTSTRAP_SERVERS=kafka:29092',
        'REDIS_HOST=redis',
        'EUREKA_URLS=http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@eureka-server-1:8761/eureka/,http://${EUREKA_USER:-admin}:${EUREKA_PASSWORD:-admin}@eureka-server-2:8761/eureka/',
        'EUREKA_USER=${EUREKA_USER:-admin}',
        'EUREKA_PASSWORD=${EUREKA_PASSWORD:-admin}',
        'SPRING_CONFIG_IMPORT=optional:configserver:http://${CONFIG_USER}:${CONFIG_PASSWORD}@config-service:8888'
    ],
    'depends_on': {
        'config-service': {'condition': 'service_healthy'},
        'eureka-server-1': {'condition': 'service_healthy'},
        'postgres': {'condition': 'service_healthy'},
        'kafka': {'condition': 'service_healthy'},
        'redis': {'condition': 'service_healthy'}
    },
    'restart': 'on-failure'
}

with open('docker-compose.yml', 'w') as f:
    yaml.dump(data, f, sort_keys=False)
