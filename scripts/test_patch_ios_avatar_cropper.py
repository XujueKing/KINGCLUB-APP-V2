import json
from pathlib import Path
import tempfile
import unittest

from patch_ios_avatar_cropper import ANCHOR, MARKER, apply, patch_source


class AvatarCropperPatchTests(unittest.TestCase):
    def test_source_patch_is_idempotent_and_keeps_delegate_callbacks(self):
        source = "@implementation Cropper\n" + ANCHOR + "\n// original delegate"
        patched = patch_source(source)
        self.assertEqual(patched.count(MARKER), 1)
        self.assertEqual(patch_source(patched), patched)
        self.assertTrue(patched.endswith("// original delegate"))

    def test_unknown_source_or_partial_patch_is_rejected(self):
        for source in ["", ANCHOR + ANCHOR, MARKER + ANCHOR]:
            with self.assertRaises(ValueError):
                patch_source(source)

    def test_resolved_package_is_patched_once_and_new_version_is_not_written(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package = root / "package"
            target = package / "ios/image_cropper/Sources/image_cropper/FLTImageCropperPlugin.m"
            target.parent.mkdir(parents=True)
            target.write_text(ANCHOR, encoding="utf-8")
            pubspec = package / "pubspec.yaml"
            pubspec.write_text("version: 12.2.1\n", encoding="utf-8")
            config = root / "package_config.json"
            config.write_text(json.dumps({"packages": [{
                "name": "image_cropper", "rootUri": package.as_uri() + "/"
            }]}), encoding="utf-8")
            apply(config)
            first = target.read_bytes()
            apply(config)
            self.assertEqual(target.read_bytes(), first)
            pubspec.write_text("version: 99.0.0\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                apply(config)
            self.assertEqual(target.read_bytes(), first)


if __name__ == "__main__":
    unittest.main()
