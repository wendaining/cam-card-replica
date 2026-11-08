#!/usr/bin/env python3
"""Create a clean coursework archive from the repository tree."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ALLOWED_ROOTS = {'Sources', 'Tests', 'UITests', 'Resources', 'TestData', 'docs', 'Scripts'}
ALLOWED_FILES = {'README.md', 'Makefile', 'project.yml', '.swiftlint.yml', '.swiftformat'}

# Filled personal documents stay untracked; if present, they replace the blanks in the archive.
PERSONAL_FILES = {
    'docs/submission/final-signoff.md': 'docs/submission/final-signoff.local.md',
    'docs/submission/manual-corrections.csv': 'docs/submission/manual-corrections.local.csv',
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'output/submission')
    args = parser.parse_args()
    for required in ('docs/reports/final-report.md',
                     'docs/reports/evidence/ocr-measurement/recognition-records.json',
                     'docs/reports/verification-local.md'):
        if not (ROOT / required).is_file():
            raise SystemExit('Required submission material is missing: ' + required)
    if not any((ROOT / name).is_file() for name in ('docs/submission/final-signoff.md',
                                                    'docs/submission/final-signoff.local.md')):
        raise SystemExit('Required submission material is missing: docs/submission/final-signoff.md')
    evidence = ROOT / 'docs/reports/evidence/ocr-measurement'
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
    reference_evidence = ROOT / 'docs/reports/evidence/reference-android'
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
    for archive_name, local_name in PERSONAL_FILES.items():
        local_path = ROOT / local_name
        if local_path.is_file():
            files[archive_name] = local_path.read_bytes()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    archive = args.output_dir / 'CamCardReplica-Submission.zip'
    root = 'CamCardReplica'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for relative, data in sorted(files.items()):
            output.writestr(root + '/' + relative, data)
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None:
            raise SystemExit('Archive CRC validation failed')
        for relative, data in files.items():
            if digest(check.read(root + '/' + relative)) != digest(data):
                raise SystemExit('Archive content validation failed: ' + relative)
    checksum = args.output_dir / (archive.name + '.sha256')
    checksum.write_text(digest(archive.read_bytes()) + '  ' + archive.name + '\n')
    print(f'{archive}\n{checksum}\nVerified {len(files)} archive entries, {len(records)} OCR records and {reference_count} reference records')


if __name__ == '__main__':
    main()
