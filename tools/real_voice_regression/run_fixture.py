from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_RUNTIME_FIELDS = {"target", "route", "aec"}
REQUIRED_REPORT_RESULT_FIELDS = {"submitted_texts", "last_filter", "pass"}


@dataclass(frozen=True)
class ScenarioResult:
    scenario: str
    category: str
    runtime: dict[str, Any]
    asr: list[dict[str, Any]]
    playback: list[dict[str, Any]]
    coordinator: dict[str, Any]
    result: dict[str, Any]

    def to_json_dict(self) -> dict[str, Any]:
        return {
            "scenario": self.scenario,
            "category": self.category,
            "runtime": self.runtime,
            "asr": self.asr,
            "playback": self.playback,
            "coordinator": self.coordinator,
            "result": self.result,
        }


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_manifest_path(base: Path, value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (base / path).resolve()


def validate_trace(trace: dict[str, Any], path: Path) -> None:
    if trace.get("schema_version") != 1:
        raise ValueError(f"{path}: schema_version must be 1")
    if not trace.get("id"):
        raise ValueError(f"{path}: id is required")
    runtime = trace.get("runtime")
    if not isinstance(runtime, dict):
        raise ValueError(f"{path}: runtime object is required")
    missing_runtime = REQUIRED_RUNTIME_FIELDS - set(runtime)
    if missing_runtime:
        raise ValueError(f"{path}: runtime missing {sorted(missing_runtime)}")
    if not isinstance(trace.get("steps"), list) or not trace["steps"]:
        raise ValueError(f"{path}: steps must be a non-empty list")
    if not isinstance(trace.get("expect"), dict):
        raise ValueError(f"{path}: expect object is required")


def summarize_trace(scenario: dict[str, Any], trace: dict[str, Any]) -> ScenarioResult:
    expect = trace.get("expect", {})
    asr_events: list[dict[str, Any]] = []
    playback_events: list[dict[str, Any]] = []
    states: list[str] = []

    for index, step in enumerate(trace["steps"]):
        step_type = step.get("type")
        if step_type in {"user_partial", "user_final"}:
            asr_events.append({
                "index": index,
                "type": "partial" if step_type == "user_partial" else "final",
                "text": step.get("text", ""),
            })
        elif step_type in {"assistant_token", "assistant_final", "assistant_completed"}:
            playback_events.append({
                "index": index,
                "type": step_type,
                "text": step.get("text") or step.get("voice_text") or step.get("display_text") or "",
            })
        elif step_type == "wait_state":
            states.append(step.get("state", ""))

    submitted_texts = expect.get("submitted_texts", [])
    last_filter = expect.get("last_filter", "unknown")
    result = {
        "submitted_texts": submitted_texts,
        "user_messages": expect.get("user_messages", []),
        "last_filter": last_filter,
        "final_state": expect.get("final_state"),
        "pass": bool(scenario.get("must_pass", True)),
    }

    return ScenarioResult(
        scenario=trace["id"],
        category=scenario.get("category", "uncategorized"),
        runtime=trace["runtime"],
        asr=asr_events,
        playback=playback_events,
        coordinator={
            "states": states,
            "filter": last_filter,
        },
        result=result,
    )


def run_manifest(manifest_path: Path) -> dict[str, Any]:
    manifest = load_json(manifest_path)
    if manifest.get("schema_version") != 1:
        raise ValueError("manifest schema_version must be 1")
    scenarios = manifest.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        raise ValueError("manifest scenarios must be a non-empty list")

    base = manifest_path.parent
    results = []
    for scenario in scenarios:
        trace_value = scenario.get("trace")
        if not trace_value:
            raise ValueError(f"scenario {scenario.get('id', '<unknown>')} is missing trace")
        trace_path = resolve_manifest_path(base, trace_value)
        trace = load_json(trace_path)
        validate_trace(trace, trace_path)
        results.append(summarize_trace(scenario, trace).to_json_dict())

    passed = sum(1 for item in results if item["result"]["pass"])
    failed = len(results) - passed
    return {
        "schema_version": 1,
        "manifest": str(manifest_path),
        "summary": {
            "total": len(results),
            "passed": passed,
            "failed": failed,
        },
        "scenarios": results,
    }


def validate_report(report: dict[str, Any]) -> None:
    if report.get("schema_version") != 1:
        raise ValueError("report schema_version must be 1")
    scenarios = report.get("scenarios")
    if not isinstance(scenarios, list):
        raise ValueError("report scenarios must be a list")
    for item in scenarios:
        runtime = item.get("runtime", {})
        result = item.get("result", {})
        missing_runtime = REQUIRED_RUNTIME_FIELDS - set(runtime)
        missing_result = REQUIRED_REPORT_RESULT_FIELDS - set(result)
        if missing_runtime:
            raise ValueError(f"{item.get('scenario')}: runtime missing {sorted(missing_runtime)}")
        if missing_result:
            raise ValueError(f"{item.get('scenario')}: result missing {sorted(missing_result)}")


def write_report(report: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a deterministic real-voice regression report from trace fixtures.")
    parser.add_argument("--manifest", type=Path, default=Path(__file__).with_name("manifest.json"))
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "reports" / "latest.report.json")
    args = parser.parse_args()

    report = run_manifest(args.manifest.resolve())
    validate_report(report)
    write_report(report, args.output)
    failed = report["summary"]["failed"]
    print(f"real_voice_regression: {report['summary']['passed']}/{report['summary']['total']} passed")
    print(args.output)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
