import re
with open('docker-compose.yml', 'r') as f:
    lines = f.readlines()
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if line.strip().startswith('- DB_URL='):
        # check if the next line is already SPRING_DATASOURCE_URL
        if i + 1 < len(lines) and 'SPRING_DATASOURCE_URL' in lines[i+1]:
            continue
        db_url = line.strip().split('=')[1]
        padding = line[:len(line) - len(line.lstrip())]
        new_lines.append(f"{padding}- SPRING_DATASOURCE_URL={db_url}\n")
    if line.strip().startswith('- DB_NAME='):
        if i + 1 < len(lines) and 'SPRING_DATASOURCE_URL' in lines[i+1]:
            continue
        db_name = line.strip().split('=')[1]
        padding = line[:len(line) - len(line.lstrip())]
        new_lines.append(f"{padding}- SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/{db_name}\n")
with open('docker-compose.yml', 'w') as f:
    f.writelines(new_lines)
