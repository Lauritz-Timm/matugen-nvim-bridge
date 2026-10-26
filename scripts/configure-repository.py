#!/usr/bin/env python3
"""Apply the checked-in repository settings with an authenticated GitHub CLI."""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def api(method, endpoint, path=None):
    command = ["gh", "api", "--hostname", "github.com", "--method", method, endpoint]
    if path is not None:
        command += ["--input", str(ROOT / path)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def configure(repo, dry_run=False):
    settings = [
        ".github/repository.json",
        ".github/actions-permissions.json",
        ".github/rulesets/main.json",
        ".github/rulesets/releases.json",
    ]
    if dry_run:
        for path in settings:
            print(path)
            print(json.dumps(read(path), indent=2))
        return

    if not shutil.which("gh"):
        raise RuntimeError("Install GitHub CLI and authenticate with gh auth login")
    metadata = api("GET", f"repos/{repo}")
    if not metadata.get("permissions", {}).get("admin"):
        raise RuntimeError("The authenticated account must administer the repository")

    branch = metadata["default_branch"]
    checks = api("GET", f"repos/{repo}/commits/{branch}/check-runs?per_page=100")["check_runs"]
    required = next(
        rule["parameters"]["required_status_checks"]
        for rule in read(".github/rulesets/main.json")["rules"]
        if rule["type"] == "required_status_checks"
    )
    for expected in required:
        matches = [
            check for check in checks
            if check["name"] == expected["context"]
            and check.get("app", {}).get("id") == expected["integration_id"]
        ]
        latest = max(matches, key=lambda check: check["id"], default=None)
        if latest is None or latest["status"] != "completed" or latest["conclusion"] != "success":
            raise RuntimeError("Required CI has not passed: " + expected["context"])

    # Complete preflight before changing any repository settings.
    existing = api("GET", f"repos/{repo}/rulesets?includes_parents=false&per_page=100")
    by_name = {ruleset["name"]: ruleset["id"] for ruleset in existing}
    api("PATCH", f"repos/{repo}", ".github/repository.json")
    api("PUT", f"repos/{repo}/actions/permissions/workflow", ".github/actions-permissions.json")
    for path in (".github/rulesets/main.json", ".github/rulesets/releases.json"):
        ruleset = read(path)
        identifier = by_name.get(ruleset["name"])
        endpoint = f"repos/{repo}/rulesets" + (f"/{identifier}" if identifier is not None else "")
        api("PUT" if identifier is not None else "POST", endpoint, path)
        print("Active: " + ruleset["name"])
    print("Repository and workflow settings applied to " + repo)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="GitHub repository in owner/name form")
    parser.add_argument("--dry-run", action="store_true", help="Print settings without contacting GitHub")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
        parser.error("--repo must be in owner/name form")
    configure(args.repo, args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error)) from error
