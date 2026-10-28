#!/usr/bin/env python3
"""Extract real-image comparisons without changing any acceptance thresholds."""
import argparse
import collections
import json
from pathlib import Path


def summarize(records):
    groups = collections.defaultdict(lambda: collections.Counter())
    for record in records:
        for item in record['comparisons']:
            for dimension, value in [('kind', record['kind']), ('lang', record['lang']),
                                     ('layout', record['layout']), ('font', Path(record['fontFile']).name),
                                     ('labels', str(record['labels']))]:
                counts = groups[(dimension, value, item['field'])]
                counts['total'] += 1
                counts['correct'] += item['correct']
                counts['missing'] += item['missing']
                counts['extra'] += item['extra']
                if item['expected']:
                    counts['present'] += 1
                    counts['present_correct'] += item['correct']
                else:
                    counts['absent'] += 1
                    counts['hallucinated'] += not item['correct']
    return groups


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--log', default='TestResults/bench.log')
    ap.add_argument('--output', default='docs/reports/image-accuracy-latest.md')
    args = ap.parse_args()
    text = Path(args.log).read_text()
    records = json.loads(text.split('CORPUS_JSON_BEGIN\n', 1)[1].split('\nCORPUS_JSON_END', 1)[0])
    groups = summarize(records)
    output = Path(args.output)
    json_path = output.with_suffix('.json')
    json_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    lines = ['# 图像到字段：语料 v2 实测', '',
             '> 日期：2026-10-28；iPhone 18 Pro / iOS 27.0；真实 Vision；全部76张图。', '',
             '这是概率性测量，不能将数字表述成确定性场景通过率。比较完整集合，忽略大小写/首尾空白，保留号码内部格式。错值同时产生一个漏值和一个多值。', '',
             '“全部正确”包含字段本来就缺失且输出为空；“已印字段正确”只统计该字段已印出的图片；“缺失误填”是不存在的字段被填。', '',
             '| 图片组 | 字段 | 全部正确 | 已印字段正确 | 缺失误填 | 漏值数 | 多值数 |',
             '|---|---|---:|---:|---:|---:|---:|']
    for (dimension, kind, field), c in sorted(groups.items()):
        if dimension != 'kind':
            continue
        lines.append(f"| {kind} | {field} | {c['correct']}/{c['total']} | {c['present_correct']}/{c['present']} | {c['hallucinated']}/{c['absent']} | {c['missing']} | {c['extra']} |")
    lines += ['', f'逐图期望值、实际值以及语言/版式/字体/标签维度可从[完整测量数据]({json_path.name})复算。', '',
              '复现：先跑 make bench，再运行 python3 Scripts/report_benchmark.py。', '',
              '目标与限制：原理想文本门槛保持不变。本表中的图像错误仍需人工确认，不能把理想文本准确率当作实际图像准确率；未对 Vision 读错的 0/O/l/1 加语料专用纠错。真机拍摄与正版 CamCard 仍需单独验收。']
    output.write_text('\n'.join(lines) + '\n')
    print(output)
    print(json_path)
    print('dimension,bucket,field,correct,total,present_correct,present,absent,hallucinated,missing,extra')
    for key, c in sorted(groups.items()):
        print(','.join(key) + ',' + ','.join(str(c[k]) for k in ['correct', 'total', 'present_correct', 'present', 'absent', 'hallucinated', 'missing', 'extra']))


if __name__ == '__main__':
    main()
