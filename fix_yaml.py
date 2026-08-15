import os
import glob

appended_block = """
management:
  tracing:
    enabled: true
    sampling:
      probability: 1.0
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces

spring:
  kafka:
    listener:
      observation-enabled: true
    template:
      observation-enabled: true
"""

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # If the appended block is in the content (at the end), remove it
    if appended_block.strip() in content:
        # Strip from the right and remove the block
        content = content[:content.rfind(appended_block.strip())].rstrip() + "\n"
    elif appended_block in content:
        content = content.replace(appended_block, "")
    else:
        # Maybe it doesn't have it? Just continue
        pass

    lines = content.split('\n')
    new_lines = []
    
    management_block = """  tracing:
    enabled: true
    sampling:
      probability: 1.0
  otlp:
    tracing:
      endpoint: http://localhost:4318/v1/traces"""
      
    spring_block = """  kafka:
    listener:
      observation-enabled: true
    template:
      observation-enabled: true"""

    has_management = any(line.startswith('management:') for line in lines)
    has_spring = any(line.startswith('spring:') for line in lines)
    
    management_inserted = False
    spring_inserted = False
    
    for line in lines:
        new_lines.append(line)
        if line.startswith('management:') and not management_inserted:
            new_lines.extend(management_block.split('\n'))
            management_inserted = True
        if line.startswith('spring:') and not spring_inserted:
            new_lines.extend(spring_block.split('\n'))
            spring_inserted = True

    if not has_management:
        new_lines.append("")
        new_lines.append("management:")
        new_lines.extend(management_block.split('\n'))
        
    if not has_spring:
        new_lines.append("")
        new_lines.append("spring:")
        new_lines.extend(spring_block.split('\n'))
        
    with open(filepath, 'w') as f:
        f.write('\n'.join(new_lines) + '\n')
    print(f"Fixed {filepath}")

# Find all yaml files that might be affected
yamls = glob.glob('*/src/main/resources/*.yml')
for yml in yamls:
    with open(yml, 'r') as f:
        if 'observation-enabled' in f.read():
            fix_file(yml)
