"""Validate that exported OCR evidence stays attached to its actual input."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import report_benchmark as report


class EvidenceExportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.sources = self.root / 'sources'
        self.images = self.root / 'images'
        self.sources.mkdir()
        self.images.mkdir()
        (self.sources / 'sample.png').write_bytes(b'original image fixture')
        (self.images / 'processed-sample.png').write_bytes(b'\x89PNG\r\n\x1a\nprocessed image fixture')
        parsed = dict(name={'value': 'David Chen', 'confidence': .72, 'evidence': 'line 0'},
                      company=None, jobTitle=None, department=None, phones=[], emails=[],
                      website=None, address=None, unassignedLines=[])
        fields = ['name', 'company', 'jobTitle', 'department', 'emails', 'website', 'address',
                  'mobile', 'office', 'fax']
        comparisons = []
        for field in fields:
            values = ['David Chen'] if field == 'name' else []
            comparisons.append(dict(field=field, expected=values, actual=values,
                                    correct=True, missing=0, extra=0))
        self.record = dict(file='sample.png', kind='flat', lang='en', layout='left', labels=True,
                           sourceSHA256=hashlib.sha256((self.sources / 'sample.png').read_bytes()).hexdigest(),
                           processedImageFile='processed-sample.png',
                           processedImageSHA256=hashlib.sha256((self.images / 'processed-sample.png').read_bytes()).hexdigest(),
                           processingMode='whole-image-no-detection', detectedCorners=[],
                           ocr=dict(rawText='David Chen', lines=[dict(text='David Chen', confidence=.73,
                                    boundingBox=[[.1, .2], [.5, .1]])], imageSize=[100, 60],
                                    duration=.1, languages=['en-US']), parsed=parsed, comparisons=comparisons)

    def test_failed_or_missing_run_cannot_be_exported(self):
        log = 'CORPUS_JSON_BEGIN\n' + json.dumps([self.record]) + '\nCORPUS_JSON_END\n'
        with self.assertRaises(ValueError):
            report.read_records(log)
        self.assertEqual(report.read_records(log + '** TEST SUCCEEDED **\n'), [self.record])

    def test_missing_raw_ocr_is_rejected(self):
        record = copy.deepcopy(self.record)
        del record['ocr']
        with self.assertRaises(ValueError):
            report.validate_records([record], self.sources, self.images)

    def test_input_image_changes_are_rejected(self):
        (self.images / 'processed-sample.png').write_bytes(b'changed bytes')
        with self.assertRaises(ValueError):
            report.validate_records([self.record], self.sources, self.images)

    def test_comparisons_must_match_initial_parsed_values(self):
        record = copy.deepcopy(self.record)
        record['comparisons'][0]['actual'] = ['Corrected Name']
        with self.assertRaises(ValueError):
            report.validate_records([record], self.sources, self.images)

    def test_complete_evidence_and_source_hashes_are_accepted(self):
        report.validate_records([self.record], self.sources, self.images)
        with self.assertRaises(ValueError):
            report.validate_records([self.record, self.record], self.sources, self.images)


if __name__ == '__main__':
    unittest.main()
