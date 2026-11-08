#!/usr/bin/env python3
"""Create a coursework archive with a content manifest and actual evidence."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
ALLOWED_ROOTS = {'Sources', 'Tests', 'UITests', 'Resources', 'TestData', 'docs', 'Scripts', '.github', '.githooks'}
ALLOWED_FILES = {'README.md', 'AGENTS.md', 'HANDOFF.md', 'Makefile', 'project.yml', '.gitignore',
                 '.swiftlint.yml', '.swiftformat', '移动应用开发课程作业-v2.pdf', '00-作业调研与执行方案.md'}

# Filled personal documents stay untracked; if present, they replace the blanks in the archive.
PERSONAL_FILES = {
    'docs/submission/final-signoff.md': 'docs/submission/final-signoff.local.md',
    'docs/submission/manual-corrections.csv': 'docs/submission/manual-corrections.local.csv',
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--date', default=datetime.now(ZoneInfo('Asia/Shanghai')).date().isoformat())
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'output/submission')
    args = parser.parse_args()
    for required in ('docs/reports/final-report.md',
                     'docs/reports/evidence/ocr-2026-11-07/recognition-records.json',
                     'docs/reports/verification-2026-11-07.md'):
        if not (ROOT / required).is_file():
            raise SystemExit('Required submission material is missing: ' + required)
    if not any((ROOT / name).is_file() for name in ('docs/submission/final-signoff.md',
                                                    'docs/submission/final-signoff.local.md')):
        raise SystemExit('Required submission material is missing: docs/submission/final-signoff.md')
    evidence = ROOT / 'docs/reports/evidence/ocr-2026-11-07'
    hashes = json.loads((evidence / 'SHA256SUMS.json').read_text())
    for relative, expected in hashes.items():
        if digest((evidence / relative).read_bytes()) != expected:
            raise SystemExit('Evidence hash mismatch: ' + relative)
    records = json.loads((evidence / 'recognition-records.json').read_text())
    from report_benchmark import validate_records
    validate_records(records, ROOT / 'TestData/cards', evidence / 'images')
    truth = json.loads((ROOT / 'TestData/ground-truth/ground_truth.json').read_text())['cards']
    if {record['file'] for record in records} != {card['file'] for card in truth}:
        raise SystemExit('OCR evidence does not cover the shipped corpus')
    run = json.loads((evidence / 'run.json').read_text())
    for relative, expected in run['sourceFilesSHA256'].items():
        if digest((ROOT / relative).read_bytes()) != expected:
            raise SystemExit('Measured source file has changed: ' + relative)
    reference_evidence = ROOT / 'docs/reports/evidence/reference-2026-11-08'
    reference_count = 0
    if reference_evidence.exists():
        from compare_reference_camcard import validate_submission_reference
        reference_count = validate_submission_reference(reference_evidence, truth, {record['file']: record for record in records})
    listing = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
    files = {}
    for name in listing.decode().split('\0'):
        path = Path(name)
        if name and (path.parts[0] in ALLOWED_ROOTS or name in ALLOWED_FILES) and (ROOT / path).is_file():
            if '__pycache__' in path.parts or path.suffix == '.pyc':
                continue
            files[path.as_posix()] = (ROOT / path).read_bytes()
    used_personal_copies = []
    for archive_name, local_name in PERSONAL_FILES.items():
        local_path = ROOT / local_name
        if local_path.is_file():
            files[archive_name] = local_path.read_bytes()
            used_personal_copies.append(local_name)
    files['START-HERE.md'] = ('# 提交材料\n\n'
                             '[最终报告 Markdown](docs/reports/final-report.md)\n\n'
                             '[提交目录](docs/submission/README.md)\n\n'
                             '[本人操作清单](docs/submission/user-actions.md)\n\n'
                             '[最终填写模板](docs/submission/final-signoff.md)\n\n'
                             '[正版同图统计](docs/reports/reference-comparison-2026-11-08.md)\n\n'
                             '作者信息、本人验收与 TRAE 详细附件保留填写位置。\n').encode()
    metadata = dict(createdAt=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
                    gitRevision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    workingTreeHasChanges=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                    ocrRecordCount=len(records), referenceRecordCount=reference_count, fileCountBeforeManifest=len(files),
                    usedPersonalCopies=used_personal_copies,
                    pendingAuthorRecords=['author identity, signoff and demonstration'],
                    unverifiedScopes=['physical-device shooting quality', 'iOS reference application', 'CamCard VIP export artifacts'])
    files['SUBMISSION.json'] = (json.dumps(metadata, ensure_ascii=False, indent=2) + '\n').encode()
    files['MANIFEST.sha256'] = ''.join(f'{digest(data)}  {name}\n' for name, data in sorted(files.items())).encode()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    name = 'CamCardReplica-Submission-' + args.date
    archive = args.output_dir / (name + '.zip')
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for relative, data in sorted(files.items()):
            output.writestr(name + '/' + relative, data)
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None:
            raise SystemExit('Archive CRC validation failed')
        for relative, data in files.items():
            if digest(check.read(name + '/' + relative)) != digest(data):
                raise SystemExit('Archive content validation failed: ' + relative)
    checksum = args.output_dir / (archive.name + '.sha256')
    checksum.write_text(digest(archive.read_bytes()) + '  ' + archive.name + '\n')
    print(f'{archive}\n{checksum}\nVerified {len(files)} archive entries and {len(records)} OCR records')


if __name__ == '__main__':
    main()
