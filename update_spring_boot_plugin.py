import glob
import re

execution_xml = """                <executions>
                    <execution>
                        <id>pre-integration-test</id>
                        <goals>
                            <goal>start</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>post-integration-test</id>
                        <goals>
                            <goal>stop</goal>
                        </goals>
                    </execution>
                </executions>
"""

def update_spring_boot_plugin(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Find the spring-boot-maven-plugin block
    # and insert <executions> if not present
    if 'spring-boot-maven-plugin' in content and 'pre-integration-test' not in content:
        # We need to insert inside the spring-boot-maven-plugin block.
        # It usually looks like:
        # <plugin>
        #     <groupId>org.springframework.boot</groupId>
        #     <artifactId>spring-boot-maven-plugin</artifactId>
        #     <configuration>...
        
        # We will use regex to find the artifactId and insert right after it
        content = re.sub(
            r'(<artifactId>spring-boot-maven-plugin</artifactId>)',
            r'\1\n' + execution_xml,
            content
        )
        
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

# Find all pom.xml files
poms = glob.glob('*/pom.xml')
for pom in poms:
    update_spring_boot_plugin(pom)
