import yaml

with open('api-gateway.yml', 'r') as f:
    data = yaml.safe_load(f)

# Add route for ONDC service
new_route = {
    'id': 'ondc-integration-service',
    'uri': 'lb://ondc-integration-service',
    'predicates': ['Path=/ondc/**, /search, /select, /init, /confirm, /cancel, /status, /track, /update, /rating, /on_search, /on_select, /on_init, /on_confirm, /on_cancel, /on_status, /on_track']
}
data['spring']['cloud']['gateway']['routes'].append(new_route)

# Add to RBAC (assuming open or authenticated for ONDC, ONDC uses custom auth filter)
# So it doesn't need to be in customer/restaurant lists if the gateway passes it through,
# but let's just make sure it's accessible. We don't add it to rbac rules so it passes as public if no rule matches,
# or we add an 'ondc' block if needed. The custom filter in ONDC service will handle auth.

with open('api-gateway.yml', 'w') as f:
    yaml.dump(data, f, sort_keys=False)
