#!/usr/bin/env python3
import unittest
from pathlib import Path
from compare_reference_camcard import comparison,normalized_value,ordered_address,require_complete,validate_selected_input

class ReferenceComparisonTests(unittest.TestCase):
    def test_actual_single_image_selection_is_accepted(self):
        validate_selected_input((Path(__file__).parent/'Fixtures/CamCardUI/en-01-selected-input.xml').read_text())
    def test_selection_in_another_album_is_rejected(self):
        xml=(Path(__file__).parent/'Fixtures/CamCardUI/en-01-selected-input.xml').read_text()
        with self.assertRaisesRegex(ValueError,'sole checked image'):validate_selected_input(xml.replace('CamCardReferenceCurrent','Camera'))
    def test_unchecked_input_is_rejected(self):
        xml=(Path(__file__).parent/'Fixtures/CamCardUI/en-01-selected-input.xml').read_text()
        with self.assertRaisesRegex(ValueError,'sole checked image'):validate_selected_input(xml.replace('checked="true"','checked="false"'))
    def test_phone_formatting_is_separate_from_strict_matching(self):
        self.assertFalse(comparison('mobile',['+86 138 0000 1234'],['+8613800001234'],'strict')['correct'])
        self.assertTrue(comparison('mobile',['+86 138 0000 1234'],['+8613800001234'],'content')['correct'])
    def test_phone_digits_are_not_repaired(self):
        result=comparison('mobile',['+8613800001234'],['+8613800001235'],'content')
        self.assertEqual((result['correct'],result['missing'],result['extra']),(False,1,1))
    def test_repeated_values_continue_to_count_as_extra(self):
        result=comparison('emails',['a@example.org'],['a@example.org','a@example.org'],'content')
        self.assertEqual((result['correct'],result['missing'],result['extra'],result['truePositive']),(False,0,1,1))
    def test_email_character_errors_are_preserved(self):
        self.assertFalse(comparison('emails',['david.chen@example.org'],['david.chen@example.or9'],'content')['correct'])
    def test_chinese_address_component_order_is_defined(self):
        address=ordered_address([{'component':'box_street','value':'杨浦区四平路1239号'},{'component':'box_city','value':'上海市'},{'component':'box_postcode','value':'200092'}])
        self.assertTrue(comparison('address',['上海市杨浦区四平路1239号 200092'],[address],'content')['correct'])
    def test_address_missing_components_are_not_added(self):
        address=ordered_address([{'component':'box_street','value':'500 Market Street, Suite 900'},{'component':'box_city','value':'San Francisco'},{'component':'box_postcode','value':'94105'}])
        self.assertFalse(comparison('address',['500 Market Street, Suite 900, San Francisco, CA 94105'],[address],'content')['correct'])
    def test_root_website_formatting_preserves_meaningful_path_slashes(self):
        self.assertEqual(normalized_value('website','https://www.abc.example/','content'),'www.abc.example')
        self.assertEqual(normalized_value('website','https://www.abc.example/path/','content'),'www.abc.example/path/')
    def test_incomplete_evidence_sets_are_rejected(self):
        with self.assertRaisesRegex(ValueError,'Complete measured set required'):require_complete({'en-01.png'}, {'en-01.png','zh-01.png'})
        require_complete({'en-01.png'},{'en-01.png'})

if __name__=='__main__':unittest.main()
