"""Run with python3 -m unittest discover -s scripts -p test_xcode_cloud_config.py."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "configure_cloud_build", ROOT / "ios/ci_scripts/configure_cloud_build.py"
)
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)


class CloudConfigurationTest(unittest.TestCase):
    def settings(self, **updates):
        return {
            "CI_BUILD_NUMBER": "200",
            "CI_TEAM_ID": "239E9W6PEN",
            "KINGCLUB_TENCENT_MAP_KEY": "test-only-key",
            **updates,
        }

    def test_live_endpoints_keep_independent_business_paths(self):
        result = CONFIG.build_defines(self.settings())
        self.assertEqual(result["KINGCLUB_API_BASE_URL"], "https://api.wuyexin.cn/kingclub-v2")
        self.assertEqual(result["KINGCLUB_COMMERCE_API_BASE_URL"], "https://api.wuyexin.cn/commerce")
        self.assertEqual(result["KINGCLUB_IOS_SYSTEM_CALLS"], "false")

    def test_rejects_old_or_invalid_build_numbers(self):
        for number in ("", "1", "179", "-1", "200.1", "two hundred"):
            with self.subTest(number=number), self.assertRaises(ValueError):
                CONFIG.build_defines(self.settings(CI_BUILD_NUMBER=number))

    def test_requires_map_key_without_echoing_it_on_error(self):
        with self.assertRaises(ValueError):
            CONFIG.build_defines(self.settings(KINGCLUB_TENCENT_MAP_KEY=""))
        with self.assertRaises(ValueError) as error:
            CONFIG.build_defines(self.settings(CI_TEAM_ID="OTHER_TEAM"))
        self.assertNotIn("test-only-key", str(error.exception))

    def test_rejects_malformed_version_and_call_flag(self):
        for updates in ({"KINGCLUB_BUILD_NAME": "1.2"}, {"KINGCLUB_IOS_SYSTEM_CALLS": "yes"}):
            with self.subTest(updates=updates), self.assertRaises(ValueError):
                CONFIG.build_defines(self.settings(**updates))


if __name__ == "__main__":
    unittest.main()
