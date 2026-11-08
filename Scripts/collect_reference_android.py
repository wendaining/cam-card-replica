#!/usr/bin/env python3
"""Capture CamCard Basic results through its normal album and review UI.

Preconditions: user-installed official app, completed login and agreements,
English + Simplified Chinese recognition, an isolated Android test emulator.
"""
import argparse,hashlib,json,re,subprocess,time,xml.etree.ElementTree as E
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from reference_camcard_ui import PREFIX,parse_pages,ui_nodes
ROOT=Path(__file__).resolve().parent.parent
CURRENT='/storage/emulated/0/Pictures/CamCardReferenceCurrent/'

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

class Collector:
    def __init__(self,adb,serial,evidence):self.executable=adb;self.serial=serial;self.evidence=evidence
    def adb(self,*args,binary=False):
        result=subprocess.run([self.executable,'-s',self.serial,*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=50)
        return result.stdout if binary else result.stdout.decode(errors='replace').strip()
    def dump(self):
        name='/data/local/tmp/camcard-reference-ui.xml'
        self.adb('shell','rm','-f',name)
        output=self.adb('shell','uiautomator','dump','--compressed',name)
        if 'dumped' not in output.lower():raise RuntimeError('Fresh UI dump failed: '+output)
        xml=self.adb('exec-out','cat',name);return xml,E.fromstring(xml)
    @staticmethod
    def nodes(root,identifier=None,text=None):
        return [n for n in root.iter('node') if (identifier is None or n.get('resource-id')==PREFIX+identifier) and (text is None or n.get('text')==text)]
    def wait(self,predicate,timeout=40):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            try:
                xml,root=self.dump()
                if predicate(root):return xml,root
            except (RuntimeError,subprocess.CalledProcessError,subprocess.TimeoutExpired):pass
            time.sleep(.25)
        raise RuntimeError('Expected UI state did not appear')
    def tap(self,node):
        if node.get('enabled')=='false':raise RuntimeError('Refusing disabled control')
        values=list(map(int,re.findall(r'\d+',node.get('bounds'))));self.adb('shell','input','tap',str((values[0]+values[2])//2),str((values[1]+values[3])//2))
    def save_view(self,directory,name,xml):
        directory.mkdir(parents=True,exist_ok=True);(directory/(name+'.xml')).write_text(xml)
        (directory/(name+'.png')).write_bytes(self.adb('exec-out','screencap','-p',binary=True))
    def media_rows(self):
        text=self.adb('shell','content query --uri content://media/external/images/media --projection _id:_data')
        return [(int(i),path.strip()) for i,path in re.findall(r'_id=(\d+), _data=([^\r\n]+)',text)]
    def prepare(self,file):
        for mid,path in self.media_rows():
            if path.startswith(CURRENT):
                if not re.fullmatch(r'[a-z0-9-]+\.(png|jpg)',Path(path).name):raise RuntimeError('Unexpected test directory content')
                self.adb('shell','content','delete','--uri','content://media/external/images/media/'+str(mid))
        self.adb('shell','mkdir','-p',CURRENT);self.adb('push',str(ROOT/'TestData/cards'/file),CURRENT+file)
        self.adb('shell','am','broadcast','-a','android.intent.action.MEDIA_SCANNER_SCAN_FILE','-d','file://'+CURRENT+file)
        deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            rows=[(i,p) for i,p in self.media_rows() if p.startswith(CURRENT)]
            if len(rows)==1 and rows[0][1]==CURRENT+file:break
            time.sleep(.3)
        else:raise RuntimeError('One-image album did not update')
        actual=self.adb('shell','sha256sum',CURRENT+file).split()[0];expected=sha(ROOT/'TestData/cards'/file)
        if actual!=expected:raise RuntimeError('Input image changed')
        return {'devicePath':CURRENT+file,'mediaURI':'content://media/external/images/media/'+str(rows[0][0]),'deviceSHA256':actual}
    def import_image(self,directory):
        xml,root=self.wait(lambda r:bool(self.nodes(r,'ll_album')))
        if not self.nodes(root,text='Multiple'):
            self.tap(self.nodes(root,'tv_basic')[0]);xml,root=self.wait(lambda r:bool(self.nodes(r,text='Multiple')))
        self.tap(self.nodes(root,'ll_album')[0]);xml,root=self.wait(lambda r:bool(self.nodes(r,'tv_choose_album')))
        if self.nodes(root,'tv_choose_album')[0].get('text')!='CamCardReferenceCurrent':
            self.tap(self.nodes(root,'rl_choose_album_layout')[0]);xml,root=self.wait(lambda r:bool(self.nodes(r,text='CamCardReferenceCurrent')));self.tap(self.nodes(root,text='CamCardReferenceCurrent')[0])
        xml,root=self.wait(lambda r:len(self.nodes(r,'cb_checkbox'))==1 and bool(self.nodes(r,'tv_choose_album','CamCardReferenceCurrent')))
        self.tap(self.nodes(root,'cb_checkbox')[0]);xml,root=self.wait(lambda r:any(n.get('enabled')=='true' for n in self.nodes(r,'btn_send_img')))
        self.save_view(directory,'selected-input',xml);self.tap(self.nodes(root,'btn_send_img')[0])
        xml,root=self.wait(lambda r:bool(self.nodes(r,'save_background')) and bool(self.nodes(r,'tv_language_content')),timeout=60)
        language=self.nodes(root,'tv_language_content')[0].get('text','')
        if set(re.split('[,，]',language))!={'English','Simplified Chinese'}:raise RuntimeError('Unexpected recognition languages: '+language)
        return xml,root
    def collect(self,directory,xml,root):
        pages=[]
        for index in range(1,13):
            self.save_view(directory,'page-'+str(index),xml);pages.append(directory/('page-'+str(index)+'.xml'))
            if self.nodes(root,'btn_edit_contact_improve_result'):return parse_pages(pages),root,pages
            scroll=[n for n in root.iter('node') if n.get('resource-id')==PREFIX+'scrollview']
            if len(scroll)!=1:raise RuntimeError('Field scroll view missing')
            bounds=list(map(int,re.findall(r'\d+',scroll[0].get('bounds'))));bottom=bounds[3]-80;top=max(bounds[1]+35,bottom-600)
            self.adb('shell','input','swipe','600',str(bottom),'600',str(top),'550');xml,root=self.dump()
        raise RuntimeError('End of the complete review form was not reached')
    def ensure_camera(self):
        xml,root=self.dump()
        if self.nodes(root,'reply_dialog_title'):
            self.adb('shell','input','keyevent','4');xml,root=self.wait(lambda r:bool(self.nodes(r,'btn_pick_next')))
        if self.nodes(root,'btn_pick_next'):
            self.tap(self.nodes(root,'btn_pick_next')[0]);self.wait(lambda r:bool(self.nodes(r,'ll_album')));return
        if self.nodes(root,'ll_album'):return
        if self.nodes(root,'menu_item_add_cards_capture'):
            self.tap(self.nodes(root,'menu_item_add_cards_capture')[0]);self.wait(lambda r:bool(self.nodes(r,'ll_album')));return
        raise RuntimeError('Collector requires camera or saved-card screen; inspect the current UI')
    def discard_and_next(self,root):
        self.adb('shell','input','keyevent','4')
        xml,root=self.wait(lambda r:bool(self.nodes(r,'tv_recapture')) or bool(self.nodes(r,'ll_album')))
        if self.nodes(root,'tv_recapture'):
            self.tap(self.nodes(root,'tv_recapture')[0]);self.wait(lambda r:bool(self.nodes(r,'ll_album')))
    def save_and_next(self,root):
        self.tap(self.nodes(root,'save_background')[0])
        xml,root=self.wait(lambda r:bool(self.nodes(r,'btn_pick_next')) or bool(self.nodes(r,'reply_dialog_title')))
        if self.nodes(root,'reply_dialog_title'):
            self.adb('shell','input','keyevent','4');xml,root=self.wait(lambda r:bool(self.nodes(r,'btn_pick_next')))
        self.tap(self.nodes(root,'btn_pick_next')[0]);self.wait(lambda r:bool(self.nodes(r,'ll_album')))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb',default=str(Path.home()/'Library/Caches/cam-card-replica/android-sdk/platform-tools/adb'))
    parser.add_argument('--serial',default='emulator-5580')
    parser.add_argument('--evidence-dir',type=Path,default=ROOT/'docs/reports/evidence/reference-2026-11-08')
    parser.add_argument('--files',nargs='*')
    args=parser.parse_args();corpus=json.loads((ROOT/'TestData/ground-truth/ground_truth.json').read_text())['cards'];allowed={r['file'] for r in corpus}
    files=args.files or [r['file'] for r in corpus]
    if not set(files)<=allowed:raise ValueError('Input outside fixed corpus')
    c=Collector(args.adb,args.serial,args.evidence_dir)
    c.ensure_camera()
    for file in files:
        directory=args.evidence_dir/'android-ocr'/file
        if (directory/'record.json').exists():print('Already recorded '+file,flush=True);continue
        print('Recognizing '+file,flush=True);started=time.monotonic();source=c.prepare(file)
        xml,root=c.import_image(directory);record,root,pages=c.collect(directory,xml,root)
        record.update(inputFile=file,observedAt=datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),inputSHA256=sha(ROOT/'TestData/cards'/file),inputMedia=source,mode='Basic',languages=['English','Simplified Chinese'],version='8.25.0.20260129',viewport='720x1824',noFieldEdits=True,libraryPolicy='active library empty; retake after capture; no recognition results saved',collectionComplete=True,pages=[p.name for p in pages],collectionSeconds=round(time.monotonic()-started,3))
        (directory/'record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');c.discard_and_next(root)
        (directory/'discarded.txt').write_text('Retake control and camera observed after capture; recognized fields were not saved.\n')
        count=len(list((args.evidence_dir/'android-ocr').glob('*/record.json')));print('Recorded '+file+'; complete '+str(count)+'/76',flush=True)
if __name__=='__main__':main()
