import yaml
import sys

def main():
    try:
        with open('prometheus/rules/money.yml', 'r') as f:
            data = yaml.safe_load(f)
            
        groups = data.get('groups', [])
        if not groups:
            print("ERROR: No groups found in money.yml")
            sys.exit(1)
            
        money_alerts = groups[0]
        rules = money_alerts.get('rules', [])
        
        if len(rules) != 5:
            print(f"ERROR: Expected 5 rules, but found {len(rules)}")
            sys.exit(1)
            
        for rule in rules:
            annotations = rule.get('annotations', {})
            if 'runbook_url' not in annotations:
                print(f"ERROR: Rule {rule.get('alert', 'Unknown')} is missing a runbook_url")
                sys.exit(1)
                
        print("SUCCESS: All Prometheus rules are valid and contain runbook_urls.")
        
    except Exception as e:
        print(f"ERROR: Failed to parse money.yml: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
