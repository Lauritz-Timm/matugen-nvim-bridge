"""Check repository setup preflight and repeatable ruleset updates."""

import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("configure_repository", ROOT / "scripts/configure-repository.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class RepositorySettingsTests(unittest.TestCase):
    def exercise(self, *, green=True, admin=True, existing=False, app=15368):
        expected = next(
            rule["parameters"]["required_status_checks"]
            for rule in setup.read(".github/rulesets/main.json")["rules"]
            if rule["type"] == "required_status_checks"
        )
        calls = []

        def api(method, endpoint, path=None):
            calls.append((method, endpoint, path))
            if method != "GET":
                return {}
            if endpoint == "repos/owner/plugin":
                return {"permissions": {"admin": admin}, "default_branch": "main"}
            if "/check-runs" in endpoint:
                return {"check_runs": [
                    {
                        "id": index,
                        "name": check["context"],
                        "app": {"id": app},
                        "status": "completed",
                        "conclusion": "success" if green else "failure",
                    }
                    for index, check in enumerate(expected, 1)
                ]}
            if "/rulesets?" in endpoint:
                return [
                    {"id": 41, "name": "Protect main"},
                    {"id": 42, "name": "Protect release tags"},
                ] if existing else []
            raise AssertionError("Unexpected request: " + endpoint)

        with patch.object(setup.shutil, "which", return_value="/usr/bin/gh"):
            with patch.object(setup, "api", side_effect=api):
                with contextlib.redirect_stdout(io.StringIO()):
                    try:
                        setup.configure("owner/plugin")
                    except RuntimeError as error:
                        return calls, str(error)
        return calls, None

    def test_success_applies_settings_after_preflight(self):
        calls, error = self.exercise()
        self.assertIsNone(error)
        writes = [call for call in calls if call[0] != "GET"]
        self.assertEqual(len(writes), 4)
        self.assertTrue(writes[0][1] == "repos/owner/plugin")
        self.assertEqual(sum(method == "POST" for method, _, _ in writes), 2)

    def test_failed_ci_changes_nothing(self):
        calls, error = self.exercise(green=False)
        self.assertIn("Required CI has not passed", error)
        self.assertTrue(all(method == "GET" for method, _, _ in calls))

    def test_matching_check_name_from_another_app_is_rejected(self):
        calls, error = self.exercise(app=999)
        self.assertIn("Required CI has not passed", error)
        self.assertTrue(all(method == "GET" for method, _, _ in calls))

    def test_existing_rulesets_are_updated(self):
        calls, error = self.exercise(existing=True)
        self.assertIsNone(error)
        self.assertFalse(any(method == "POST" for method, _, _ in calls))
        endpoints = [endpoint for method, endpoint, _ in calls if method == "PUT"]
        self.assertIn("repos/owner/plugin/rulesets/41", endpoints)
        self.assertIn("repos/owner/plugin/rulesets/42", endpoints)

    def test_non_admin_account_changes_nothing(self):
        calls, error = self.exercise(admin=False)
        self.assertIn("must administer", error)
        self.assertTrue(all(method == "GET" for method, _, _ in calls))

    def test_dry_run_requires_no_cli_or_network(self):
        with patch.object(setup, "api", side_effect=AssertionError("Unexpected API request")):
            with patch.object(setup.shutil, "which", return_value=None):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    setup.configure("owner/plugin", dry_run=True)
        self.assertIn("required_approving_review_count", output.getvalue())


if __name__ == "__main__":
    unittest.main()
