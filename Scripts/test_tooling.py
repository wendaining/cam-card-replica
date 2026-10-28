"""Requirement checks for corpus typography and build/install consistency."""
import subprocess
import unittest
import random
from pathlib import Path
from unittest.mock import patch

from PIL import ImageDraw

import generate_test_cards as generator


class ToolingTests(unittest.TestCase):
    def test_all_printed_text_fits_the_corpus_canvas(self):
        original = ImageDraw.ImageDraw.text
        current_card = []

        def checked_text(drawer, xy, text, *args, **kwargs):
            box = drawer.textbbox(xy, text, font=kwargs.get("font"), anchor=kwargs.get("anchor"))
            width, height = drawer._image.size
            self.assertGreaterEqual(box[0], 0, current_card)
            self.assertGreaterEqual(box[1], 0, current_card)
            self.assertLessEqual(box[2], width, current_card)
            self.assertLessEqual(box[3], height, current_card)
            return original(drawer, xy, text, *args, **kwargs)

        with patch.object(ImageDraw.ImageDraw, "text", checked_text):
            for spec in generator.build_corpus():
                current_card[:] = [spec.cid]
                generator.render_card(spec, random.Random(20261027))

    def test_build_and_install_use_same_derived_data_directory(self):
        output = subprocess.check_output(["make", "-n", "run"], text=True)
        self.assertIn("-derivedDataPath build", output)
        self.assertIn("build/Build/Products/Debug-iphonesimulator/CamCardReplica.app", output)

    def test_corpus_selects_multiple_font_families_per_language(self):
        specs = generator.build_corpus()
        for language in ("zh", "en", "bilingual"):
            fonts = {generator.resolve_font(spec) for spec in specs if spec.lang == language}
            self.assertGreaterEqual(len(fonts), 3, language)
            for font in fonts:
                self.assertTrue(Path(font).is_file(), font)
        self.assertEqual([generator.resolve_font(s) for s in specs],
                         [generator.resolve_font(s) for s in generator.build_corpus()])


if __name__ == "__main__":
    unittest.main()
