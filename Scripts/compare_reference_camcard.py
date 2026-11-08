#!/usr/bin/env python3
"""Validate 76 raw CamCard UI records and compare them with the same Vision corpus."""
import argparse,csv,hashlib,json,re,struct,subprocess,unicodedata,xml.etree.ElementTree as E
from collections import Counter,defaultdict
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from reference_camcard_ui import FIELDS,parse_pages
ROOT=Path(__file__).resolve().parent.parent
LABELS=dict(zip(FIELDS,['姓名','公司','职位','部门','邮箱','网站','地址','手机','座机','传真']))

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write_json(path,value):Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def require_complete(found,expected):
    if set(found)!=set(expected):raise ValueError(f'Complete measured set required: {len(found)}/{len(expected)}')
def expected_values(card):
    data=card['fields'];out={f:[data[f]] if data.get(f) else [] for f in ['name','company','jobTitle','department','website','address']}
    out['emails']=data['emails']
    for kind in ['mobile','office','fax']:out[kind]=[p['number'] for p in data['phones'] if p['kind']==kind]
    return out

def ordered_address(components):
    chinese=any(re.search(r'[\u3400-\u9fff]',c['value']) for c in components)
    order=['country','state','region','city','area','street','postcode'] if chinese else ['street','city','state','region','area','postcode','country']
    rank={name:i for i,name in enumerate(order)}
    indexed=list(enumerate(components));indexed.sort(key=lambda pair:(rank.get(pair[1]['component'].removeprefix('box_'),99),pair[0]))
    return ', '.join(c['value'] for _,c in indexed)

def normalized_value(field,value,mode):
    value=value.strip().lower()
    if mode=='strict':return value
    if field in ['mobile','office','fax']:
        return re.sub(r'[\s\-()（）]','',unicodedata.normalize('NFKC',value))
    if field=='website':
        value=re.sub(r'^https?://','',value)
        if value.endswith('/') and value.count('/')==1:value=value[:-1]
        return value
    if field=='address':return re.sub(r'[\s,，]','',value)
    return value

def values_for(record,field,mode,is_reference):
    if mode=='content' and field=='address' and is_reference:
        return [ordered_address(parts) for parts in record['addressComponents']]
    return record['fields'][field]

def comparison(field,expected,actual,mode):
    wanted=Counter(normalized_value(field,x,mode) for x in expected if x.strip())
    found=Counter(normalized_value(field,x,mode) for x in actual if x.strip())
    return dict(correct=wanted==found,missing=sum((wanted-found).values()),extra=sum((found-wanted).values()),expectedValues=sum(wanted.values()),truePositive=sum((wanted&found).values()))

def validate_selected_input(xml):
    nodes=list(E.fromstring(xml).iter('node'))
    def controls(identifier):return [n for n in nodes if n.get('resource-id')=='com.intsig.BizCardReader:id/'+identifier]
    boxes=controls('cb_checkbox');album=controls('tv_choose_album');buttons=controls('btn_send_img')
    if len(boxes)!=1 or boxes[0].get('checked')!='true' or len(album)!=1 or album[0].get('text')!='CamCardReferenceCurrent' or len(buttons)!=1 or buttons[0].get('text')!='OK(1)' or buttons[0].get('enabled')!='true':
        raise ValueError('Selected input must be the sole checked image in the controlled album')

def validate_record(path,card):
    data=json.loads(path.read_text());file=card['file']
    if data['inputFile']!=file or set(data['fields'])!=set(FIELDS):raise ValueError('Record field set mismatch: '+file)
    actual=digest(ROOT/'TestData/cards'/file)
    if data['inputSHA256']!=actual or data['inputMedia']['deviceSHA256']!=actual:raise ValueError('Input hash mismatch: '+file)
    if data.get('mode')!='Basic' or set(data.get('languages',[]))!={'English','Simplified Chinese'}:raise ValueError('Recognition settings differ: '+file)
    if not data.get('collectionComplete') or not data.get('noFieldEdits') or not (path.parent/'discarded.txt').is_file():raise ValueError('Incomplete workflow: '+file)
    validate_selected_input((path.parent/'selected-input.xml').read_text())
    if not (path.parent/'selected-input.png').is_file():raise ValueError('Missing selected input screenshot: '+file)
    pages=[]
    for page in data['pages']:
        if Path(page).name!=page:raise ValueError('Invalid evidence path')
        file_path=path.parent/page
        if not file_path.is_file() or not file_path.with_suffix('.png').is_file():raise ValueError('Missing UI evidence: '+file)
        image=file_path.with_suffix('.png').read_bytes()
        if image[:8]!=b'\x89PNG\r\n\x1a\n' or len(image)<24 or struct.unpack('>II',image[16:24])!=(720,1824):raise ValueError('Invalid UI screenshot: '+file)
        pages.append(file_path)
    replay=parse_pages(pages)
    for key in ['fields','addressComponents','rawEditableFields','unmappedFields']:
        if replay[key]!=data[key]:raise ValueError('Raw UI replay mismatch: '+file+' '+key)
    return data

def stats(rows,mode,source,field=None):
    result=Counter()
    for row in rows:
        for name in ([field] if field else FIELDS):
            c=row['comparison'][mode][source][name];present=bool(row['expected'][name])
            result.update(total=1,correct=int(c['correct']),present=int(present),presentCorrect=int(present and c['correct']),absent=int(not present),hallucinated=int(not present and not c['correct']),missing=c['missing'],extra=c['extra'],expectedValues=c['expectedValues'],truePositive=c['truePositive'])
    tp=result['truePositive'];precision=tp/(tp+result['extra']) if tp+result['extra'] else 0;recall=tp/(tp+result['missing']) if tp+result['missing'] else 0
    return dict(result,precision=precision,recall=recall,f1=2*precision*recall/(precision+recall) if precision+recall else 0)

def write_reference_csv(rows):
    path=ROOT/'docs/submission/reference-ocr.csv'
    with path.open(encoding='utf-8-sig',newline='') as stream:reader=csv.DictReader(stream);headers=reader.fieldnames;existing=list(reader)
    lookup={r['file']:r for r in rows}
    if {r['file'] for r in existing}!=set(lookup):raise ValueError('Submission CSV does not cover the measured set')
    for row in existing:
        data=lookup[row['file']]['reference']
        for field in FIELDS:row['reference_'+field]=json.dumps(data['fields'][field],ensure_ascii=False)
        row.update(reference_status='已测量：Android Basic 初始字段',observed_at=data['observedAt'],evidence_path='docs/reports/evidence/reference-android/android-ocr/'+row['file']+'/record.json',notes='英语与简体中文；完整字段集合；地址原始组件另行保留；确认后取消保存。')
    with path.open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=headers,lineterminator='\n');writer.writeheader();writer.writerows(existing)

def percent(a,b):return f'{a}/{b}（{a/b:.1%}）' if b else '0/0'
def table_row(label,counts):return f"| {label} | {percent(counts['correct'],counts['total'])} | {percent(counts['presentCorrect'],counts['present'])} | {percent(counts['hallucinated'],counts['absent'])} | {counts['precision']:.1%} | {counts['recall']:.1%} | {counts['f1']:.1%} |"

def validate_submission_reference(evidence,cards,vision):
    for name in ['SHA256SUMS.json','comparison-run.json','comparisons.json']:
        if not (evidence/name).is_file():raise ValueError('Reference measurement metadata missing: '+name)
    manifest=json.loads((evidence/'SHA256SUMS.json').read_text())
    found={p.relative_to(evidence).as_posix() for p in evidence.rglob('*') if p.is_file() and p.name!='SHA256SUMS.json'}
    if found!=set(manifest):raise ValueError('Reference manifest file set mismatch')
    for relative,expected in manifest.items():
        if digest(evidence/relative)!=expected:raise ValueError('Reference evidence hash mismatch: '+relative)
    metadata=json.loads((evidence/'comparison-run.json').read_text())
    truth={c['file']:c for c in cards};actual={p.parent.name:p for p in (evidence/'android-ocr').glob('*/record.json')}
    require_complete(actual,truth)
    rows=json.loads((evidence/'comparisons.json').read_text());lookup={r['file']:r for r in rows};require_complete(lookup,truth)
    if len(rows)!=len(truth) or metadata.get('inputCount')!=len(truth):raise ValueError('Reference measured count mismatch')
    if metadata.get('groundTruthSHA256')!=digest(ROOT/'TestData/ground-truth/ground_truth.json'):raise ValueError('Reference Ground Truth changed')
    if metadata.get('visionRunSHA256')!=digest(ROOT/'docs/reports/evidence/ocr-measurement/run.json'):raise ValueError('Vision run metadata changed')
    for relative,expected in metadata['replaySourceFilesSHA256'].items():
        if digest(ROOT/relative)!=expected:raise ValueError('Reference replay source changed: '+relative)
    for file,card in truth.items():
        reference=validate_record(actual[file],card);row=lookup[file]
        expected=expected_values(card);replica={c['field']:c['actual'] for c in vision[file]['comparisons']}
        if reference!=row['reference'] or expected!=row['expected'] or replica!=row['replica']['fields']:raise ValueError('Stored reference comparison differs: '+file)
        if vision[file]['sourceSHA256']!=reference['inputSHA256']:raise ValueError('Reference input differs from Vision input: '+file)
        for mode in ['strict','content']:
            for source,record in [('replica',row['replica']),('reference',reference)]:
                wanted={field:comparison(field,expected[field],values_for(record,field,mode,source=='reference'),mode) for field in FIELDS}
                if wanted!=row['comparison'][mode][source]:raise ValueError('Reference comparison counts differ: '+file)
    for mode in ['strict','content']:
        for source in ['replica','reference']:
            if stats(rows,mode,source)!=metadata['statistics'][mode][source]:raise ValueError('Reference summary differs from measured records')
    return len(rows)

def render(rows,output,metadata,evidence):
    lines=['# 正版 CamCard 与本项目同图测量','',f"测量日期：2026-11-08。统一输入为 {len(rows)} 张图片，来源于 50 张合成名片及其照片、遮挡变体。",'',
           '参考应用为官方 Android CamCard 8.25.0.20260129，Basic 模式，英语与简体中文同时启用。本项目结果来自 2026-11-07 的实际 Vision 全链路记录。', '',
           '[环境与操作记录](reference-validation.md)；[正版原始证据](evidence/reference-android/README.md)；[本项目原始证据](evidence/ocr-measurement/README.md)。','',
           '## 统计口径','',
           '每个字段比较完整值集合并保留重复次数。错值同时计入漏值与多值。已印字段统计排除 GT 中原本缺失的字段，缺失误填统计保留缺失字段的实际输出。','',
           '严格统计忽略大小写及首尾空白。地址字符串由正版确认页面的原始组件按界面顺序连接。','',
           '内容统计对双方统一处理电话空格、短横线及圆括号；网站去除 http(s) 前缀与根路径末尾斜线。地址按组件语义排列，中文地址使用国家、地区、城市、街道、邮编顺序，拉丁地址使用街道、城市、地区、邮编、国家顺序，再去除空白及逗号。原始组件继续保存在 JSON 中。','',
           '正版可能把双语姓名拆到 Name 与 Nickname，或把组织信息拆成多组。姓名按 Name 控件计分，Nickname 保存在额外控件值中；此类字段表示差异和地址组件表示方式会影响完全匹配。全部逐图比较保留实际值，统计范围限定于当前合成集合。','',
           '## 全部输入','']
    for mode,title in [('strict','严格统计'),('content','内容统计')]:
        lines += ['### '+title,'','| 实现 | 全部字段正确 | 已印字段正确 | 缺失字段误填 | 值精确率 | 值召回率 | 值 F1 |','|---|---:|---:|---:|---:|---:|---:|']
        for source,label in [('replica','本项目 Vision + 规则解析'),('reference','正版 CamCard Basic')]:lines.append(table_row(label,stats(rows,mode,source)))
        lines.append('')
    lines += ['## 各字段内容统计','','| 字段 | 实现 | 完整集合正确 | 已印字段正确 | 缺失误填 | 漏值数 | 多值数 |','|---|---|---:|---:|---:|---:|---:|']
    for field in FIELDS:
        for source,label in [('replica','本项目'),('reference','CamCard')]:
            s=stats(rows,'content',source,field);lines.append(f"| {LABELS[field]} | {label} | {percent(s['correct'],s['total'])} | {percent(s['presentCorrect'],s['present'])} | {percent(s['hallucinated'],s['absent'])} | {s['missing']} | {s['extra']} |")
    lines += ['','## 图片类型与语言','','| 范围 | 实现 | 字段集合正确 | 已印字段正确 | 值 F1 |','|---|---|---:|---:|---:|']
    for dimension in ['kind','lang']:
        for bucket in sorted({r[dimension] for r in rows}):
            subset=[r for r in rows if r[dimension]==bucket]
            for source,label in [('replica','本项目'),('reference','CamCard')]:
                s=stats(subset,'content',source);lines.append(f"| {dimension}: {bucket}，{len(subset)} 张 | {label} | {percent(s['correct'],s['total'])} | {percent(s['presentCorrect'],s['present'])} | {s['f1']:.1%} |")
    lines += ['','## 完整图片与空结果','','| 实现 | 十类字段全部正确的图片 | 十类字段均为空的图片 |','|---|---:|---:|']
    for source,label in [('replica','本项目'),('reference','CamCard')]:
        all_correct=sum(all(r['comparison']['content'][source][f]['correct'] for f in FIELDS) for r in rows);empty=sum(not any(r[source]['fields'][f] for f in FIELDS) for r in rows);lines.append(f'| {label} | {all_correct}/{len(rows)} | {empty}/{len(rows)} |')
    unmapped=sum(len(r['reference']['unmappedFields']) for r in rows)
    lines += ['',f'正版有 {unmapped} 条无法直接映射到课程字段的实际值，保存在各记录的 unmappedFields；十类字段统计限定于表中字段，额外控件值单独保留。','',
              '## 实际差异示例','','每个字段按固定语料顺序选择首个内容统计不一致的输入，保留 GT 与双方实际输出。完整比较见附件 JSON。','',
              '| 输入 | 字段 | GT | 本项目 | CamCard |','|---|---|---|---|---|']
    for field in FIELDS:
        example=next((r for r in rows if not r['comparison']['content']['replica'][field]['correct'] or not r['comparison']['content']['reference'][field]['correct']),None)
        if example:
            def cell(value):return json.dumps(value,ensure_ascii=False).replace('|','\\|').replace('\n',' ')
            file=example['file'];link='evidence/reference-android/android-ocr/'+file+'/record.json'
            lines.append(f"| [{file}]({link}) | {LABELS[field]} | {cell(example['expected'][field])} | {cell(example['replica']['fields'][field])} | {cell(example['reference']['fields'][field])} |")
    lines += ['','## 附件与范围','','[逐图比较](evidence/reference-android/comparisons.json)保存严格与内容统计的全部漏值、多值和一致状态；[参考 OCR 表](../submission/reference-ocr.csv)填写全部实际字段。','',
              '当前统计采用保存前的初始字段，采集过程中保持原始文字。collectionSeconds 包含导入、界面等待、滚动与截图。本人实际修改次数继续使用作者填写表。','',
              'Android Basic、iOS Vision 与规则解析各自按照其当前流程处理相同原图。iOS 正版、真实拍摄质量及 CamCard 会员导出文件未验证。']
    if (evidence/'interpretation-replay.json').is_file():
        lines += ['','[字段读取重算](evidence/reference-android/interpretation-replay.json)记录 Nickname 与地址分离的工具修正；原始 XML 与截图保留，最终统计使用修正后的解释。']
    if (evidence/'empty-recheck-summary.json').is_file():
        lines += ['','[空结果复查](evidence/reference-android/empty-recheck-summary.json)单独保存重复输入的结果，首次结果继续计入统计；[最终名片夹](evidence/reference-android/final-library-check.json)记录联系人数量。']
    output.write_text('\n'.join(lines)+'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir',type=Path,default=ROOT/'docs/reports/evidence/reference-android')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/reports/reference-comparison.md')
    args=parser.parse_args();evidence=args.evidence_dir
    cards=json.loads((ROOT/'TestData/ground-truth/ground_truth.json').read_text())['cards'];truth={r['file']:r for r in cards}
    actual={p.parent.name:p for p in (evidence/'android-ocr').glob('*/record.json')}
    require_complete(actual,truth)
    vision_dir=ROOT/'docs/reports/evidence/ocr-measurement'
    vision={r['file']:r for r in json.loads((vision_dir/'recognition-records.json').read_text())}
    if set(vision)!=set(truth):raise ValueError('Vision corpus mismatch')
    rows=[]
    for card in cards:
        file=card['file'];reference=validate_record(actual[file],card);original=vision[file]
        if original['sourceSHA256']!=reference['inputSHA256']:raise ValueError('Implementations received different originals: '+file)
        expected=expected_values(card);replica={'fields':{c['field']:c['actual'] for c in original['comparisons']}};compare={}
        for mode in ['strict','content']:
            compare[mode]={}
            for source,record in [('replica',replica),('reference',reference)]:
                compare[mode][source]={f:comparison(f,expected[f],values_for(record,f,mode,source=='reference'),mode) for f in FIELDS}
        rows.append(dict(file=file,kind=card['kind'],lang=card['lang'],expected=expected,replica=replica,reference=reference,comparison=compare))
    metadata=dict(schemaVersion=1,createdAt=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),inputCount=len(rows),uniqueCards=50,referenceVersion='8.25.0.20260129',referenceMode='Basic',referenceLanguages=['English','Simplified Chinese'],visionRunSHA256=digest(vision_dir/'run.json'),groundTruthSHA256=digest(ROOT/'TestData/ground-truth/ground_truth.json'),gitRevision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),replaySourceFilesSHA256={p.relative_to(ROOT).as_posix():digest(p) for p in [ROOT/'Scripts/reference_camcard_ui.py',Path(__file__).resolve()]},statistics={mode:{source:stats(rows,mode,source) for source in ['replica','reference']} for mode in ['strict','content']})
    write_json(evidence/'comparison-run.json',metadata)
    write_json(evidence/'comparisons.json',rows)
    write_reference_csv(rows)
    render(rows,args.output,metadata,evidence)
    lines=['# 正版 CamCard 原始证据','',f"观察日期：2026-11-08。官方 Android 版本 8.25.0.20260129，Basic 模式，英语与简体中文。独立采集 {len(rows)} 张固定输入。",'',
           '[环境与流程](../../reference-validation.md)；[同图统计](../../reference-comparison.md)；[运行元数据](comparison-run.json)；[逐图比较](comparisons.json)。','',
           '每条记录包含原始控件值、完整字段集合、地址组件、输入与设备文件哈希、单图选择截图，以及确认页面各滚动位置的截图和 XML。正式识别完成后使用 Retake 取消保存，当前名片夹保持为空。','',
           '| 原始输入 | 实际字段与依据 | 单图选择 | 确认页面首屏 |','|---|---|---|---|']
    for row in rows:
        f=row['file'];lines.append(f'| [{f}](../../../../TestData/cards/{f}) | [JSON](android-ocr/{f}/record.json) | [截图](android-ocr/{f}/selected-input.png) | [截图](android-ocr/{f}/page-1.png) |')
    for name,label in [('interpretation-replay.json','字段解释修正与旧解释记录'),('empty-recheck-summary.json','独立空结果复查'),('final-library-check.json','最终空名片夹检查'),('collection.log','完整采集过程')]:
        if (evidence/name).is_file():lines += ['',f'[{label}]({name})。']
    (evidence/'README.md').write_text('\n'.join(lines)+'\n')
    manifest={p.relative_to(evidence).as_posix():digest(p) for p in sorted(evidence.rglob('*')) if p.is_file() and p.name!='SHA256SUMS.json'}
    write_json(evidence/'SHA256SUMS.json',manifest)
    print('Validated and compared '+str(len(rows))+' unchanged inputs')
    print(json.dumps(metadata['statistics'],ensure_ascii=False,indent=2))
if __name__=='__main__':main()
