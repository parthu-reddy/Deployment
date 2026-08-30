import sys

def patch(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    # Find the end of the file or a good place to add jaeger
    # It's at the end
    jaeger_service = """  jaeger:
    image: jaegertracing/all-in-one:1.50
    container_name: shared_jaeger
    ports:
    - "16686:16686"
    - "4317:4317"
    - "4318:4318"
    restart: unless-stopped
"""

    if "container_name: shared_jaeger" not in "".join(lines):
        lines.append("\n" + jaeger_service)

    # Now add OTLP_ENDPOINT to all services
    skip_services = ['zookeeper', 'kafka', 'postgres', 'redis', 'jaeger']
    current_service = None
    in_environment = False
    
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check if line defines a new service
        if line.startswith("  ") and not line.startswith("   ") and line.strip().endswith(":"):
            current_service = line.strip()[:-1]
            in_environment = False
            
        if current_service and current_service not in skip_services:
            if line.strip() == "environment:":
                in_environment = True
                new_lines.append(line)
                
                # Check if next lines already have OTLP_ENDPOINT
                j = i + 1
                has_otlp = False
                while j < len(lines) and lines[j].startswith("    "):
                    if "OTLP_ENDPOINT" in lines[j]:
                        has_otlp = True
                        break
                    j += 1
                
                if not has_otlp:
                    # Determine indentation
                    new_lines.append("    - OTLP_ENDPOINT=http://jaeger:4318/v1/traces\n")
                i += 1
                continue
                
        new_lines.append(line)
        i += 1

    with open(filepath, 'w') as f:
        f.writelines(new_lines)
    print("Patched " + filepath)

patch("docker-compose.yml")
