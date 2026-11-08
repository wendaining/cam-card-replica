#!/usr/bin/env python3
import tempfile,unittest
from pathlib import Path
from reference_camcard_ui import PREFIX,parse_pages
FIXTURE=Path(__file__).resolve().parent/'Fixtures/CamCardUI'
PAGES=sorted(FIXTURE.glob('en-01-page-*.xml'))

class ReferenceUIEvidenceTests(unittest.TestCase):
    def test_nickname_does_not_become_an_address_component(self):
        pages=sorted((Path(__file__).parent/'Fixtures/CamCardUI').glob('bi-08-page-*.xml'))
        result=parse_pages(pages)
        self.assertFalse(any(c['component']=='box_nickname' for a in result['addressComponents'] for c in a))
        self.assertTrue(any(f.get('resourceID')==PREFIX+'box_nickname' and f['value']=='Zhao Min' for f in result['unmappedFields']))
    def test_actual_output_preserves_email_error_and_multiple_departments(self):
        actual=parse_pages(PAGES)
        self.assertEqual(actual['fields']['emails'],['david.chen@example.or9','info@example.org'])
        self.assertEqual(actual['fields']['department'],['Platform Engineering','ABC Technologies'])
        self.assertEqual(actual['fields']['company'],[])
        self.assertEqual(actual['fields']['jobTitle'],['Technical Director'])
    def test_phone_types_and_all_values_survive_scrolling(self):
        fields=parse_pages(PAGES)['fields']
        self.assertEqual(fields['mobile'],['+14150001234'])
        self.assertEqual(fields['office'],['+14150008000'])
        self.assertEqual(fields['fax'],[])
    def test_address_components_retain_original_text(self):
        actual=parse_pages(PAGES)
        self.assertEqual(actual['addressComponents'],[[{'component':'box_street','value':'500 Market Street, Suite 900'},{'component':'box_city','value':'San Francisco'},{'component':'box_postcode','value':'94105'}]])
    def test_conflicting_ui_values_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for i,p in enumerate(PAGES):
                out=Path(directory)/p.name;out.write_text(p.read_text().replace('info@example.org','changed@example.org') if i==1 else p.read_text());paths.append(out)
            with self.assertRaisesRegex(ValueError,'UI value changed'):parse_pages(paths)
    def test_incomplete_review_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'Incomplete review form'):parse_pages(PAGES[:2])
    def test_page_order_does_not_duplicate_field_values(self):
        self.assertEqual(parse_pages(PAGES)['fields'],parse_pages(list(reversed(PAGES))+PAGES)['fields'])
    def test_unknown_phone_type_remains_unmapped(self):
        with tempfile.TemporaryDirectory() as directory:
            paths=[]
            for p in PAGES:
                out=Path(directory)/p.name;out.write_text(p.read_text().replace('text="Work"','text="Other"'));paths.append(out)
            actual=parse_pages(paths)
            self.assertEqual(actual['fields']['office'],[])
            self.assertIn({'typeLabel':'Other','value':'+14150008000'},actual['unmappedFields'])

if __name__=='__main__':unittest.main()
