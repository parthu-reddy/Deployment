import sys

with open('docker-compose.yml', 'r') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if '- JAVA_TOOL_OPTIONS=' in line:
        # Also remove any surrounding empty lines if this was the last item, but just skipping the line is fine
        i += 1
        continue
    
    if line.rstrip().endswith('deploy:'):
        # Peak ahead
        if i + 3 < len(lines) and 'resources:' in lines[i+1] and 'limits:' in lines[i+2] and 'cpus:' in lines[i+3]:
            if i + 4 < len(lines) and 'memory:' in lines[i+4]:
                i += 5
            else:
                i += 4
            continue

    new_lines.append(line)
    i += 1

with open('docker-compose.yml', 'w') as f:
    f.writelines(new_lines)
