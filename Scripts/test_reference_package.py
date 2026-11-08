#!/usr/bin/env python3
import hashlib,json,tempfile,unittest
from pathlib import Path
from compare_reference_camcard import validate_submission_reference

class ReferencePackageTests(unittest.TestCase):
    def test_incomplete_measurement_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError,'metadata missing'):validate_submission_reference(Path(directory),[],{})
    def test_changed_evidence_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'comparison-run.json').write_text('{}');(root/'comparisons.json').write_text('[]');(root/'README.md').write_text('changed')
            files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.iterdir()}
            files['README.md']='0'*64;(root/'SHA256SUMS.json').write_text(json.dumps(files))
            with self.assertRaisesRegex(ValueError,'hash mismatch'):validate_submission_reference(root,[],{})
    def test_unmanifested_files_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'comparison-run.json').write_text('{}');(root/'comparisons.json').write_text('[]')
            files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.iterdir()};(root/'SHA256SUMS.json').write_text(json.dumps(files));(root/'unexpected.xml').write_text('<unexpected/>')
            with self.assertRaisesRegex(ValueError,'file set mismatch'):validate_submission_reference(root,[],{})
if __name__=='__main__':unittest.main()
