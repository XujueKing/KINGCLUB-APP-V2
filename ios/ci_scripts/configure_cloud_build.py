"""Validate Xcode Cloud settings and write Flutter defines without logging keys."""

import argparse
import json
import os
from pathlib import Path
import re


def build_defines(env):
    # Bind the hook to the onboarded cloud product. Its CI_TEAM_ID value need
    # not match the signing identifier in Runner's DEVELOPMENT_TEAM setting.
    if env.get("CI_PRODUCT_ID", "").upper() not in (
        "", "5420A5FE-2D74-4869-BA7D-C1794832C49A"
    ):
        raise ValueError("Xcode Cloud must use the KINGCLUB product")
    if env.get("CI_BUNDLE_ID") not in (None, "", "com.lingmei.kingclub"):
        raise ValueError("Xcode Cloud must use the KINGCLUB bundle identifier")
    number = env.get("CI_BUILD_NUMBER", "")
    if not re.fullmatch(r"[1-9][0-9]*", number) or int(number) < 180:
        raise ValueError("Set Xcode Cloud Next Build Number to 200 or higher before the first build")
    version = env.get("KINGCLUB_BUILD_NAME", "1.2.0")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("KINGCLUB_BUILD_NAME must be a three-part version")
    map_key = env.get("KINGCLUB_TENCENT_MAP_KEY", "").strip()
    if not map_key:
        raise ValueError("Set KINGCLUB_TENCENT_MAP_KEY as a secret workflow environment variable")
    system_calls = env.get("KINGCLUB_IOS_SYSTEM_CALLS", "false").lower()
    if system_calls not in ("true", "false"):
        raise ValueError("KINGCLUB_IOS_SYSTEM_CALLS must be true or false")
    return {
        "KINGCLUB_API_BASE_URL": "https://api.wuyexin.cn/kingclub-v2",
        "KINGCLUB_COMMERCE_API_BASE_URL": "https://api.wuyexin.cn/commerce",
        "KINGCLUB_IOS_WECHAT_PAYMENT": "true",
        "KINGCLUB_IOS_SYSTEM_CALLS": system_calls,
        "KINGCLUB_TENCENT_MAP_KEY": map_key,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate-only", action="store_true")
    mode.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        defines = build_defines(os.environ)
    except ValueError as error:
        parser.exit(1, str(error) + "\n")
    if args.output:
        # The shell creates this file with umask 077; enforce it for direct use too.
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as stream:
            json.dump(defines, stream)
    print("Xcode Cloud settings validated; sensitive values omitted")


if __name__ == "__main__":
    main()
