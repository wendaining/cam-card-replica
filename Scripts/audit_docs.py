#!/usr/bin/env python3
"""Check the documentation against the repository.

A handoff is only as good as the docs someone will read, so this script verifies
the parts that can be checked mechanically:

  * every backticked repo path exists
  * every `make <target>` mentioned in docs exists in the Makefile
  * every `testTxx...` method mentioned in docs exists in UITests
  * numeric claims ("65 个单元/集成测试", "76 张图", "50 张名片", "5 篇 ADR",
    "N 个场景") match the repository

It deliberately does NOT try to validate Swift type names: Apple framework types
are mentioned all over the docs and distinguishing them from project types needs
a symbol graph, which is not worth the complexity here.

Usage: python3 Scripts/audit_docs.py
Exit code 1 when something is wrong, so CI could run it too.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {"build", ".git", "TestResults", "DerivedData"}

# The research plan was written before the code existed and lives on as a record
# of the planning, not as a specification; its illustrative paths are allowed to
# point at things that were later renamed or dropped.
HISTORICAL_DOCS = {"00-作业调研与执行方案.md"}

# Names that look like paths but are runtime artifacts or external files.
ALLOWED_PATHS = {"library.json", "spec.md"}


def docs() -> list[Path]:
    found = list(ROOT.glob("*.md")) + list(ROOT.glob("docs/**/*.md"))
    return sorted(p for p in found if not any(part in SKIP_DIRS for part in p.parts))


def repo_facts() -> dict:
    ground_truth = json.loads(
        (ROOT / "TestData/ground-truth/ground_truth.json").read_text(encoding="utf-8")
    )
    unit_methods = 0
    for path in (ROOT / "Tests").rglob("*.swift"):
        unit_methods += len(re.findall(r"func\s+test\w*\s*\(", path.read_text(encoding="utf-8")))
    ui_methods = 0
    for path in (ROOT / "UITests").rglob("*.swift"):
        ui_methods += len(re.findall(r"func\s+test\w*\s*\(", path.read_text(encoding="utf-8")))
    fixtures = [
        p for p in (ROOT / "Resources/Fixtures").iterdir() if p.suffix in {".jpg", ".png"}
    ]
    adrs = list((ROOT / "docs/architecture/adr").glob("ADR-*.md"))
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    return {
        "cards": ground_truth["card_count"],
        "images": len(ground_truth["cards"]),
        "unit_tests": unit_methods,
        "ui_tests": ui_methods,
        "scenarios": ui_methods - 1,  # one UI method captures screenshots
        "fixtures": len(fixtures),
        "adrs": len(adrs),
        "make_targets": set(re.findall(r"^([a-z][a-z-]*):", makefile, re.M)),
        "test_names": {
            name
            for folder in (ROOT / "Tests", ROOT / "UITests")
            for path in folder.rglob("*.swift")
            for name in re.findall(r"func\s+(test\w+)\s*\(", path.read_text(encoding="utf-8"))
        },
    }


def check() -> list[str]:
    facts = repo_facts()
    problems: list[str] = []

    path_re = re.compile(r"`([A-Za-z0-9_./-]+\.(?:swift|md|yml|yaml|py|json|sh|png|jpg|pdf))`")
    make_re = re.compile(r"make\s+([a-z][a-z-]*)")
    test_re = re.compile(r"`(test[A-Z]\w*)")
    number_re = re.compile(
        r"(\d+)\s*(?:个)?\s*(单元/集成测试|单元测试|场景|张图|张名片|张代表性名片|篇 ADR|个验收场景)"
    )

    expectations = {
        "单元/集成测试": ("unit_tests", "unit/integration test methods"),
        "单元测试": ("unit_tests", "unit/integration test methods"),
        "场景": ("scenarios", "acceptance scenarios (UI methods minus the screenshot helper)"),
        "个验收场景": ("scenarios", "acceptance scenarios"),
        "张图": ("images", "corpus images"),
        "张名片": ("cards", "corpus cards"),
        "张代表性名片": ("fixtures", "bundled fixtures"),
        "篇 ADR": ("adrs", "ADR documents"),
    }

    for doc in docs():
        text = doc.read_text(encoding="utf-8")
        rel = doc.relative_to(ROOT)

        if doc.name in HISTORICAL_DOCS:
            continue

        for match in path_re.finditer(text):
            target = match.group(1)
            if Path(target).name in ALLOWED_PATHS:
                continue
            candidates = [ROOT / target, doc.parent / target]
            if not any(c.exists() for c in candidates):
                problems.append(f"{rel}: path `{target}` does not exist")

        for match in make_re.finditer(text):
            target = match.group(1)
            if target not in facts["make_targets"]:
                problems.append(f"{rel}: make target `{target}` is missing from the Makefile")

        for match in test_re.finditer(text):
            name = match.group(1)
            if name.endswith("Tests"):
                continue
            # docs often cite a prefix ("testT03_*") because several methods share it
            if any(existing.startswith(name) for existing in facts["test_names"]):
                continue
            problems.append(f"{rel}: test `{name}` does not exist in Tests/UITests")

        for match in number_re.finditer(text):
            claimed = int(match.group(1))
            kind = match.group(2)
            key, what = expectations[kind]
            actual = facts[key]
            if claimed != actual:
                problems.append(f"{rel}: claims {claimed} {kind}, repository has {actual} ({what})")

    return problems


def main() -> int:
    facts = repo_facts()
    print("repo facts:")
    for key in ("cards", "images", "unit_tests", "ui_tests", "scenarios", "fixtures", "adrs"):
        print(f"  {key:12} {facts[key]}")
    print(f"  documents    {len(docs())}")

    problems = check()
    print(f"\nproblems: {len(problems)}")
    for problem in problems:
        print(f"  - {problem}")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
