#!/usr/bin/env python3
"""Export measured fields, original OCR observations, and hashed input images."""
import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
FIELDS = ('name', 'company', 'jobTitle', 'department', 'emails', 'website', 'address', 'mobile', 'office', 'fax')


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_records(log):
    if '** TEST SUCCEEDED **' not in log or '** TEST FAILED **' in log:
        raise ValueError('A successful completed test run is required')
    if log.count('CORPUS_JSON_BEGIN\n') != 1 or log.count('\nCORPUS_JSON_END') != 1:
        raise ValueError('Exactly one complete corpus output is required')
    return json.loads(log.split('CORPUS_JSON_BEGIN\n', 1)[1].split('\nCORPUS_JSON_END', 1)[0])


def parsed_values(parsed):
    result = {field: [parsed[field]['value']] if parsed.get(field) else []
              for field in ('name', 'company', 'jobTitle', 'department', 'website', 'address')}
    result['emails'] = [value['value'] for value in parsed['emails']]
    for kind in ('mobile', 'office', 'fax'):
        result[kind] = [phone['value']['value'] for phone in parsed['phones'] if phone['kind'] == kind]
    return result


def normalized(values):
    return Counter(value.strip().lower() for value in values if value.strip())


def validate_records(records, source_dir, image_dir):
    if not records or len({record['file'] for record in records}) != len(records):
        raise ValueError('Empty corpus or duplicate source files')
    for record in records:
        for key in ('file', 'processedImageFile'):
            if Path(record[key]).name != record[key]:
                raise ValueError('Evidence filenames must stay inside their directory')
        if sha256(Path(source_dir) / record['file']) != record['sourceSHA256']:
            raise ValueError('Source hash mismatch: ' + record['file'])
        if sha256(Path(image_dir) / record['processedImageFile']) != record['processedImageSHA256']:
            raise ValueError('Processed image hash mismatch: ' + record['file'])
        ocr = record.get('ocr')
        if not ocr or not ocr.get('rawText') or not ocr.get('lines'):
            raise ValueError('Missing actual OCR text or observations: ' + record['file'])
        for line in ocr['lines']:
            if not line.get('text') or not 0 <= line['confidence'] <= 1 or 'boundingBox' not in line:
                raise ValueError('Invalid OCR observation: ' + record['file'])
        actual = parsed_values(record['parsed'])
        comparisons = record['comparisons']
        if Counter(item['field'] for item in comparisons) != Counter(FIELDS):
            raise ValueError('Incomplete field comparisons: ' + record['file'])
        for item in comparisons:
            wanted, found = normalized(item['expected']), normalized(item['actual'])
            if normalized(actual[item['field']]) != found:
                raise ValueError('Comparison differs from initial parsed value: ' + record['file'])
            if (item['correct'], item['missing'], item['extra']) != (
                    wanted == found, sum((wanted - found).values()), sum((found - wanted).values())):
                raise ValueError('Comparison counts are inconsistent: ' + record['file'])


def summarize(records):
    groups = defaultdict(Counter)
    for record in records:
        for item in record['comparisons']:
            dimensions = [('all', 'all'), ('kind', record['kind']), ('lang', record['lang']),
                          ('layout', record['layout']), ('font', Path(record.get('fontFile') or 'unknown').name),
                          ('labels', str(record['labels']))]
            for dimension, value in dimensions:
                counts = groups[(dimension, value, item['field'])]
                counts['total'] += 1
                counts['correct'] += item['correct']
                counts['missing'] += item['missing']
                counts['extra'] += item['extra']
                counts['expected_values'] += len(item['expected'])
                if item['expected']:
                    counts['present'] += 1
                    counts['present_correct'] += item['correct']
                else:
                    counts['absent'] += 1
                    counts['hallucinated'] += not item['correct']
    return groups


def export_images(records, xcresult, image_dir):
    with tempfile.TemporaryDirectory(prefix='camcard-attachments-') as temporary:
        subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(xcresult),
                        '--output-path', temporary,
                        '--test-id', 'ImageCorpusTests/testEveryCorpusImageIsComparedAgainstGroundTruth()'], check=True)
        by_hash = {sha256(path): path for path in Path(temporary).iterdir() if path.is_file()}
        for record in records:
            source = by_hash.get(record['processedImageSHA256'])
            if source is None:
                raise ValueError('Missing actual image attachment: ' + record['processedImageFile'])
            shutil.copyfile(source, image_dir / record['processedImageFile'])


def write_json(path, payload):
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def render_report(records, groups, run, output, evidence_dir):
    json_path = output.with_suffix('.json')
    legacy_keys = ('file', 'kind', 'lang', 'layout', 'labels', 'fontFile', 'comparisons')
    write_json(json_path, [{key: record[key] for key in legacy_keys if key in record} for record in records])
    relative = Path(__import__('os').path.relpath(evidence_dir, output.parent)).as_posix()
    lines = ['# 图像到字段：语料 v2 实测', '',
             f"测量日期：{run['date']}；{run['environment']}；图片数量：{len(records)}。", '',
             f'[OCR 原始证据与识别输入]({relative}/README.md)包含逐图文字、位置、置信度、初始解析及图片哈希。', '',
             '字段以完整值集合比较，忽略大小写及首尾空白，保留电话号码内部格式。字段错值同时计入漏值与多值。', '',
             '“全部正确”包含原本缺失且输出为空的字段；“已印字段正确”仅统计印有该字段的图片。', '',
             '| 图片组 | 字段 | 全部正确 | 已印字段正确 | 缺失误填 | 漏值数 | 多值数 |',
             '|---|---|---:|---:|---:|---:|---:|']
    for (dimension, kind, field), counts in sorted(groups.items()):
        if dimension == 'kind':
            lines.append(f"| {kind} | {field} | {counts['correct']}/{counts['total']} | "
                         f"{counts['present_correct']}/{counts['present']} | {counts['hallucinated']}/{counts['absent']} | "
                         f"{counts['missing']} | {counts['extra']} |")
    lines += ['', f'[逐图字段比较]({json_path.name})；[全部维度统计]({relative}/metrics.csv)。', '',
              '图片来自确定性生成的合成语料。真机拍照质量、正版相同输入识别结果及人工修改次数仍待填写。']
    output.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', default='TestResults/bench.log')
    parser.add_argument('--output', default='docs/reports/image-accuracy-latest.md')
    parser.add_argument('--date', required=True, help='Actual measurement date, YYYY-MM-DD')
    parser.add_argument('--environment', required=True, help='Measured Xcode, device, and runtime')
    parser.add_argument('--xcresult', required=True, type=Path)
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    datetime.strptime(args.date, '%Y-%m-%d')
    log_path, output, evidence = Path(args.log), Path(args.output), args.evidence_dir
    records = read_records(log_path.read_text(encoding='utf-8'))
    for directory in (evidence, evidence / 'images', evidence / 'raw-text', evidence / 'parsed'):
        directory.mkdir(parents=True, exist_ok=True)
    export_images(records, args.xcresult, evidence / 'images')
    validate_records(records, ROOT / 'TestData/cards', evidence / 'images')
    truth_path = ROOT / 'TestData/ground-truth/ground_truth.json'
    truth = {item['file']: item for item in json.loads(truth_path.read_text())['cards']}
    if set(truth) != {record['file'] for record in records}:
        raise ValueError('Measured source files differ from the Ground Truth corpus')
    for record in records:
        fields = truth[record['file']]['fields']
        expected = {field: [fields[field]] if fields.get(field) else []
                    for field in ('name', 'company', 'jobTitle', 'department', 'website', 'address')}
        expected['emails'] = fields['emails']
        for kind in ('mobile', 'office', 'fax'):
            expected[kind] = [phone['number'] for phone in fields['phones'] if phone['kind'] == kind]
        if any(normalized(item['expected']) != normalized(expected[item['field']])
               for item in record['comparisons']):
            raise ValueError('Expected values differ from the shipped Ground Truth: ' + record['file'])
    run = dict(schemaVersion=1, date=args.date, environment=args.environment, recordCount=len(records),
               sourceRevision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               workingTreePatchSHA256=hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT)).hexdigest(),
               resultBundle=args.xcresult.name, benchmarkLogSHA256=sha256(log_path),
               groundTruthSHA256=sha256(truth_path),
               sourceFilesSHA256={path.relative_to(ROOT).as_posix(): sha256(path)
                                  for directory in ('Sources', 'Tests')
                                  for path in sorted((ROOT / directory).rglob('*.swift'))},
               recognizerConfiguration=dict(level='accurate', languages=['zh-Hans', 'en-US'],
                                            usesLanguageCorrection=True, minimumTextHeight=.008), comparison='complete collections, case-insensitive, trimmed',
               humanCorrectionStatus='pending-user-evidence', referenceAppStatus='pending-user-evidence')
    write_json(evidence / 'run.json', run)
    write_json(evidence / 'recognition-records.json', records)
    index = ['# OCR 原始证据', '', f"测量日期：{args.date}。环境：{args.environment}。", '',
             '每条记录包含当次 Vision 输出、初始解析结果、检测四角、原图哈希和实际识别输入图片。', '',
             '[运行元数据](run.json)；[完整识别记录](recognition-records.json)；[字段统计](metrics.csv)。', '',
             '图片坐标采用归一化值，原点位于左上角；四角顺序为左上、右上、右下、左下。', '',
             '逐行文字保留 Vision 第一候选结果；rawText 由 VisionTextRecognizer 按纵向位置排序后拼接。', '',
             '人工修改记录和正版观察结果由使用者填写在提交模板中。', '',
             '| 原始图片 | OCR 原文 | 初始解析 | 实际识别输入 |', '|---|---|---|---|']
    for record in records:
        name = record['file']
        (evidence / 'raw-text' / (name + '.txt')).write_text(record['ocr']['rawText'] + '\n', encoding='utf-8')
        write_json(evidence / 'parsed' / (name + '.json'), record['parsed'])
        index.append(f"| [{name}](../../../../TestData/cards/{name}) | [文字](raw-text/{name}.txt) | "
                     f"[字段与依据](parsed/{name}.json) | [图片](images/{record['processedImageFile']}) |")
    (evidence / 'README.md').write_text('\n'.join(index) + '\n', encoding='utf-8')
    groups = summarize(records)
    keys = ('correct', 'total', 'present_correct', 'present', 'absent', 'hallucinated', 'missing', 'extra', 'expected_values')
    with (evidence / 'metrics.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(('dimension', 'bucket', 'field', *keys))
        for key, counts in sorted(groups.items()):
            writer.writerow((*key, *(counts[item] for item in keys)))
    render_report(records, groups, run, output, evidence)
    manifest = {path.relative_to(evidence).as_posix(): sha256(path)
                for path in sorted(evidence.rglob('*')) if path.is_file() and path.name != 'SHA256SUMS.json'}
    write_json(evidence / 'SHA256SUMS.json', manifest)
    print(f'Exported {len(records)} verified OCR records to {evidence}')
    print(output)


if __name__ == '__main__':
    main()
