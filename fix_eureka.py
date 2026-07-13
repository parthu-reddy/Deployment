import yaml

with open('docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)

# Delete eureka-server-2
if 'eureka-server-2' in compose['services']:
    del compose['services']['eureka-server-2']

for service_name, service_config in compose['services'].items():
    # Remove eureka-server-2 from depends_on
    if 'depends_on' in service_config and 'eureka-server-2' in service_config['depends_on']:
        if isinstance(service_config['depends_on'], list):
            service_config['depends_on'].remove('eureka-server-2')
        elif isinstance(service_config['depends_on'], dict):
            del service_config['depends_on']['eureka-server-2']

    # Update EUREKA_URLS
    if 'environment' in service_config:
        env = service_config['environment']
        if isinstance(env, dict) and 'EUREKA_URLS' in env:
            urls = env['EUREKA_URLS'].split(',')
            new_urls = [url for url in urls if 'eureka-server-2' not in url]
            env['EUREKA_URLS'] = ','.join(new_urls)
        elif isinstance(env, list):
            new_env = []
            for item in env:
                if item.startswith('EUREKA_URLS='):
                    val = item.split('=', 1)[1]
                    urls = val.split(',')
                    new_urls = [url for url in urls if 'eureka-server-2' not in url]
                    new_env.append('EUREKA_URLS=' + ','.join(new_urls))
                else:
                    new_env.append(item)
            service_config['environment'] = new_env

# Ensure eureka-server-1 doesn't have eureka-server-2 in its EUREKA_URLS (it shouldn't, but just in case)
# Wait, for Eureka Server itself, it shouldn't try to replicate if it's standalone.
# We should set EUREKA_CLIENT_REGISTER_WITH_EUREKA: false and EUREKA_CLIENT_FETCH_REGISTRY: false
if 'eureka-server-1' in compose['services']:
    env = compose['services']['eureka-server-1'].get('environment', [])
    
    new_env = []
    if isinstance(env, list):
        for item in env:
            if not item.startswith('EUREKA_URLS='):
                new_env.append(item)
        new_env.append('EUREKA_CLIENT_REGISTER_WITH_EUREKA=false')
        new_env.append('EUREKA_CLIENT_FETCH_REGISTRY=false')
        compose['services']['eureka-server-1']['environment'] = new_env
    elif isinstance(env, dict):
        if 'EUREKA_URLS' in env:
            del env['EUREKA_URLS']
        env['EUREKA_CLIENT_REGISTER_WITH_EUREKA'] = 'false'
        env['EUREKA_CLIENT_FETCH_REGISTRY'] = 'false'

class MyDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(MyDumper, self).increase_indent(flow, False)

with open('docker-compose.yml', 'w') as f:
    yaml.dump(compose, f, Dumper=MyDumper, default_flow_style=False, sort_keys=False)
