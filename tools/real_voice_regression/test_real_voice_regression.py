import json
import tempfile
import unittest
from pathlib import Path

from tools.real_voice_regression.run_fixture import (
    run_manifest,
    validate_report,
    write_report,
)
from tools.real_voice_regression.summarize_report import markdown_summary


class RealVoiceRegressionToolTests(unittest.TestCase):
    def test_manifest_generates_valid_report(self):
        manifest = Path("tools/real_voice_regression/manifest.json").resolve()
        report = run_manifest(manifest)
        validate_report(report)

        self.assertEqual(report["summary"]["total"], 2)
        self.assertEqual(report["summary"]["failed"], 0)
        scenarios = {item["scenario"]: item for item in report["scenarios"]}
        self.assertEqual(
            scenarios["assistant_tail_echo"]["result"]["last_filter"],
            "rejected echo",
        )
        self.assertEqual(
            scenarios["short_answer_after_prompt"]["result"]["submitted_texts"],
            ["看一下行情", "黄金"],
        )

    def test_report_write_and_markdown_summary(self):
        manifest = Path("tools/real_voice_regression/manifest.json").resolve()
        report = run_manifest(manifest)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "latest.report.json"
            write_report(report, output)
            loaded = json.loads(output.read_text(encoding="utf-8"))
            validate_report(loaded)

        markdown = markdown_summary(report)
        self.assertIn("assistant_tail_echo", markdown)
        self.assertIn("short_answer_after_prompt", markdown)
        self.assertIn("| Scenario |", markdown)


if __name__ == "__main__":
    unittest.main()
