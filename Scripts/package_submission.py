#!/usr/bin/env python3
"""Create a clean coursework archive from a git archive of the repository."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE_PATHS = [
    'Sources', 'Tests', 'UITests', 'Resources', 'TestData', 'docs', 'Scripts',
    'README.md', 'Makefile', 'project.yml', '.swiftlint.yml', '.swiftformat',
]
REPORT_PDFS = ('项目报告.pdf', 'final-report.pdf')

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
    reference_count = 0
    reference_evidence = ROOT / 'docs/reports/evidence/reference-android'
    if reference_evidence.exists():
        from compare_reference_camcard import validate_submission_reference
        reference_count = validate_submission_reference(reference_evidence, truth, {record['file']: record for record in records})

    archive_bytes = subprocess.check_output(
        ['git', 'archive', '--format=zip', '--prefix=CamCardReplica/', 'HEAD', '--', *ARCHIVE_PATHS],
        cwd=ROOT,
    )
    entries = {}
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as source:
        for info in source.infolist():
            if info.is_dir():
                continue
            entries[info.filename] = source.read(info)
    for archive_name, local_name in PERSONAL_FILES.items():
        local_path = ROOT / local_name
        if local_path.is_file():
            entries['CamCardReplica/' + archive_name] = local_path.read_bytes()
    report_pdf = next((ROOT / name for name in REPORT_PDFS if (ROOT / name).is_file()), None)
    if report_pdf is None:
        raise SystemExit('Report PDF is missing: expected one of ' + ', '.join(REPORT_PDFS))
    entries['CamCardReplica/' + report_pdf.name] = report_pdf.read_bytes()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    archive = args.output_dir / 'CamCardReplica-Submission.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for name, data in sorted(entries.items()):
            output.writestr(name, data)
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None:
            raise SystemExit('Archive CRC validation failed')
        for name, data in entries.items():
            if digest(check.read(name)) != digest(data):
                raise SystemExit('Archive content validation failed: ' + name)
    checksum = args.output_dir / (archive.name + '.sha256')
    checksum.write_text(digest(archive.read_bytes()) + '  ' + archive.name + '\n')
    print(f'{archive}\n{checksum}\nVerified {len(entries)} archive entries, {len(records)} OCR records and {reference_count} reference records')


if __name__ == '__main__':
    main()
