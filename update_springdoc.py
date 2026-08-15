import os
import glob
import re

plugin_xml = """            <plugin>
                <groupId>org.springdoc</groupId>
                <artifactId>springdoc-openapi-maven-plugin</artifactId>
                <version>1.4</version>
                <executions>
                    <execution>
                        <id>integration-test</id>
                        <goals>
                            <goal>generate</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
"""

mcp_dep_xml = """        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-mcp</artifactId>
            <version>3.1.0</version>
        </dependency>
"""

def update_pom(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Update springdoc-openapi-starter-webmvc-ui version to """ + NEW_SPRINGDOC_VERSION + """
    # The previous injection looked like:
    # <dependency>
    #     <groupId>org.springdoc</groupId>
    #     <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    #     <version>2.5.0</version>
    # </dependency>
    
    content = re.sub(
        r'<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>\s*<version>2.5.0</version>',
        r'<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>\n            <version>3.1.0</version>',
        content
    )
    
    # 2. Add springdoc-openapi-starter-webmvc-mcp
    if 'springdoc-openapi-starter-webmvc-mcp' not in content:
        # inject it after springdoc-openapi-starter-webmvc-ui
        content = re.sub(
            r'(<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>\s*<version>3.1.0</version>\s*</dependency>)',
            r'\1\n' + mcp_dep_xml,
            content
        )

    # 3. Add springdoc-openapi-maven-plugin
    if 'springdoc-openapi-maven-plugin' not in content:
        # check if <plugins> exists
        if '<plugins>' in content:
            content = content.replace('<plugins>', '<plugins>\n' + plugin_xml, 1)
        else:
            # check if <build> exists
            if '<build>' in content:
                content = content.replace('<build>', '<build>\n        <plugins>\n' + plugin_xml + '        </plugins>', 1)
            else:
                # Add before </project>
                content = content.replace('</project>', '    <build>\n        <plugins>\n' + plugin_xml + '        </plugins>\n    </build>\n</project>')
                
    with open(filepath, 'w') as f:
        f.write(content)

    print(f"Updated {filepath}")

# Find all pom.xml files containing the old springdoc dependency
poms = glob.glob('*/pom.xml')
for pom in poms:
    with open(pom, 'r') as f:
        if 'springdoc-openapi-starter-webmvc-ui' in f.read():
            update_pom(pom)
