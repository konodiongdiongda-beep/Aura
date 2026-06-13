from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ is None or __package__ == "":
    sys.path.append(str(Path(__file__).resolve().parents[2]))

from tools.real_voice_regression.run_fixture import validate_report


def markdown_summary(report: dict) -> str:
    lines = [
        "# Real Voice Regression Report",
        "",
        f"- Total: {report['summary']['total']}",
        f"- Passed: {report['summary']['passed']}",
        f"- Failed: {report['summary']['failed']}",
        "",
        "| Scenario | Category | Target | Route | AEC | Filter | Submitted | Pass |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for item in report["scenarios"]:
        runtime = item["runtime"]
        result = item["result"]
        submitted = ", ".join(result.get("submitted_texts", []))
        lines.append(
            "| {scenario} | {category} | {target} | {route} | {aec} | {filter} | {submitted} | {passed} |".format(
                scenario=item["scenario"],
                category=item["category"],
                target=runtime["target"],
                route=runtime["route"],
                aec=runtime["aec"],
                filter=result["last_filter"],
                submitted=submitted,
                passed="yes" if result["pass"] else "no",
            )
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a real-voice regression report as Markdown.")
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report = json.loads(args.report.read_text(encoding="utf-8"))
    validate_report(report)
    rendered = markdown_summary(report)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
