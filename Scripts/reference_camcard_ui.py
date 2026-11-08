import xml.etree.ElementTree as E
from pathlib import Path
PREFIX='com.intsig.BizCardReader:id/'
EDITABLE={'android.widget.EditText','android.widget.AutoCompleteTextView'}
FIELDS=('name','company','jobTitle','department','emails','website','address','mobile','office','fax')
TITLES={'phone_field_title':'phone','email_field_title':'emails','org_field_title':'org','web_field_title':'website','address_field_title':'address','nick_field_title':'nickname'}
ADDRESS_COMPONENTS={'box_country','box_state','box_region','box_city','box_area','box_street','box_postcode'}
PLACEHOLDERS={'et_display_name':{'Name'},'box_company':{'Company'},'box_department':{'Department'},'box_jobtitle':{'JobTitle','Job Title'},'box_street':{'Street','Street Address'},'box_city':{'City'},'box_postcode':{'PostCode','Postcode','Zip Code','Postal Code'},'box_state':{'State','Province'},'box_country':{'Country'}}
def ui_nodes(root):
    scrolls=[n for n in root.iter('node') if n.get('resource-id')==PREFIX+'scrollview']
    if len(scrolls)!=1:raise ValueError('Expected one field scroll view')
    found={}
    def walk(n,path):
        key=path+(int(n.get('index','0')),)
        found[key]=dict(n.attrib)
        for child in n:walk(child,key)
    walk(scrolls[0],())
    return found

def parse_pages(paths):
    merged={}
    for path in paths:
        root=E.parse(path).getroot()
        for key,value in ui_nodes(root).items():
            if key in merged:
                for field in ['text','resource-id','class']:
                    if merged[key].get(field)!=value.get(field):raise ValueError(f'UI value changed while collecting {key}: {field}')
            merged[key]=value
    identifiers={n.get('resource-id') for n in merged.values()}
    if PREFIX+'et_display_name' not in identifiers or PREFIX+'btn_edit_contact_improve_result' not in identifiers:
        raise ValueError('Incomplete review form: name or end marker missing')
    result={f:[] for f in FIELDS};section=None;kind=None;address=None;addresses=[];raw=[];unmapped=[]
    def finish_address():
        nonlocal address
        if address:
            addresses.append(address)
            result['address'].append(', '.join(x['value'] for x in address))
        address=None
    for key,n in sorted(merged.items()):
        rid=n.get('resource-id','');short=rid.removeprefix(PREFIX);text=n.get('text','').strip()
        if short in TITLES:
            if section=='address':finish_address()
            section=TITLES[short];kind=None
        if rid=='android:id/text1':
            kind=text
            if section=='address':finish_address();address=[]
        if n.get('class') not in EDITABLE:continue
        placeholder=text in PLACEHOLDERS.get(short,set())
        raw.append({'path':list(key),'resourceID':rid,'text':text,'section':section,'typeLabel':kind,'placeholder':placeholder})
        if not text or placeholder:continue
        if short=='et_display_name':result['name'].append(text)
        elif short in ['box_company','box_department','box_jobtitle']:
            result[{'box_company':'company','box_department':'department','box_jobtitle':'jobTitle'}[short]].append(text)
        elif short=='data':
            if section=='phone':
                lower=(kind or '').lower()
                if 'fax' in lower:target='fax'
                elif 'mobile' in lower or 'cell' in lower:target='mobile'
                elif lower=='work':target='office'
                else:unmapped.append({'typeLabel':kind,'value':text});continue
                result[target].append(text)
            elif section in ['emails','website']:result[section].append(text)
            else:unmapped.append({'section':section,'value':text})
        elif section=='address' and short in ADDRESS_COMPONENTS:
            if address is None:address=[]
            address.append({'component':short,'value':text})
        else:unmapped.append({'resourceID':rid,'value':text,'section':section})
    finish_address()
    return dict(fields=result,addressComponents=addresses,rawEditableFields=raw,unmappedFields=unmapped)
# The collector uses public Android UI controls and the system MediaStore.
# It never reads CamCard's private files or changes recognized text fields.
