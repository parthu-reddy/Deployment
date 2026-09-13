#!/usr/bin/env python3
"""Every alert rule carries a runbook.

Runs from anywhere:

    python3 Deployment/validate_prometheus_rules.py

Two things changed on 2026-09-11, both because the previous version was failing for the wrong
reason and passing for the wrong reason at the same time:

1. **It asserted `len(rules) != 5`.** Two legitimate alerts were added to `money.yml`
   (`MoneyOutboxBacklogStalled`, `MoneyReconciliationPartialRun`) and the gate went red on the
   count — not on anything being wrong. A check that fails every time someone adds an alert trains
   people to ignore it. The count is not the property worth guarding; the runbook is. A floor
   replaces it, so the check still fails if the file is emptied or the rules go missing.

2. **It only read `money.yml`, and only its first group.** `refund_alerts.yml` sat beside it with
   four alerts, none of which had a `runbook_url` — invisible to the gate for as long as it existed.
   Every rule file is read now, and every group in it.

It also resolves its own paths. The old version opened `prometheus/rules/money.yml` relative to the
working directory, so it only worked when run from `Deployment/` and otherwise died with a
FileNotFoundError that read like a missing file rather than a wrong cwd.
"""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

RULES_DIR = Path(__file__).resolve().parent / "prometheus" / "rules"

# A floor, not an exact count: adding an alert must not break the build, but silently losing the
# whole rule set must.
MINIMUM_EXPECTED_RULES = 5


def main() -> int:
    if not RULES_DIR.is_dir():
        print(f"ERROR: {RULES_DIR} does not exist")
        return 1

    rule_files = sorted(RULES_DIR.glob("*.yml")) + sorted(RULES_DIR.glob("*.yaml"))
    if not rule_files:
        # A scan that found nothing would otherwise report "all rules valid" while guarding none.
        print(f"ERROR: no rule files found in {RULES_DIR}")
        return 1

    total = 0
    missing: list[str] = []

    for path in rule_files:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except yaml.YAMLError as exc:
            print(f"ERROR: {path.name} is not valid YAML: {exc}")
            return 1

        groups = data.get("groups") or []
        if not groups:
            print(f"ERROR: {path.name} declares no groups")
            return 1

        for group in groups:
            for rule in group.get("rules") or []:
                # Recording rules have no `alert` and nobody gets paged for one, so a runbook is
                # meaningless there. Only alerts are checked.
                name = rule.get("alert")
                if not name:
                    continue
                total += 1
                if "runbook_url" not in (rule.get("annotations") or {}):
                    missing.append(f"{path.name}:{group.get('name', '?')}:{name}")

    if total < MINIMUM_EXPECTED_RULES:
        print(f"ERROR: found {total} alert rule(s) across {len(rule_files)} file(s), "
              f"expected at least {MINIMUM_EXPECTED_RULES}")
        return 1

    if missing:
        print(f"ERROR: {len(missing)} alert(s) have no runbook_url:")
        for m in missing:
            print(f"  - {m}")
        return 1

    print(f"SUCCESS: {total} alert rule(s) across {len(rule_files)} file(s), "
          f"every one carrying a runbook_url.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
