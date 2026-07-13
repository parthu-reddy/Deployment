import yaml

with open('docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)

for service_name, service in compose['services'].items():
    if service_name not in ['zookeeper', 'kafka', 'postgres', 'redis', 'food-delivery-app-ui']:
        if 'deploy' not in service:
            service['deploy'] = {}
        if 'resources' not in service['deploy']:
            service['deploy']['resources'] = {}
        if 'limits' not in service['deploy']['resources']:
            service['deploy']['resources']['limits'] = {}
        service['deploy']['resources']['limits']['cpus'] = '0.5'

with open('docker-compose.yml', 'w') as f:
    yaml.dump(compose, f, default_flow_style=False, sort_keys=False)
