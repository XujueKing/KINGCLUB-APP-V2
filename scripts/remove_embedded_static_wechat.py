"""Remove SPM's embedded static WeChat archive before Xcode signs Runner."""
import os
from pathlib import Path
import shutil
import struct
import plistlib
import subprocess
import re


def is_static(data):
    if data.startswith(b"!<arch>\n"):
        return True
    if data[:4] == b"\xca\xfe\xba\xbe":
        count = struct.unpack_from(">I", data, 4)[0]
        if not 0 < count <= 8:
            return False
        for index in range(count):
            offset, size = struct.unpack_from(">II", data, 8 + index * 20 + 8)
            if offset + size > len(data) or not data[offset:offset + 8] == b"!<arch>\n":
                return False
        return True
    return False


if __name__ == "__main__":
    app = (Path(os.environ["TARGET_BUILD_DIR"]) / os.environ["WRAPPER_NAME"]).resolve()
    framework = app / "Frameworks/WechatOpenSDK.framework"
    if framework.exists():
        if framework.resolve().parent != app / "Frameworks":
            raise SystemExit("Unexpected WeChat framework path")
        binary = framework / "WechatOpenSDK"
        if is_static(binary.read_bytes()):
            shutil.rmtree(framework)
            print("Removed embedded static WeChat archive; linked SDK remains in Runner")
        else:
            # Xcode 26 can wrap an SPM static binary in a dynamic framework,
            # while retaining the vendor plist's older deployment target.
            headers = subprocess.check_output(['xcrun', 'otool', '-hv', str(binary)], text=True)
            if 'DYLIB' not in headers:
                raise SystemExit('Unexpected WeChat binary type: ' + headers)
            commands = subprocess.check_output(['xcrun', 'otool', '-l', str(binary)], text=True)
            versions = re.findall(r'\bminos\s+(\d+(?:\.\d+){0,2})', commands)
            if not versions:
                raise SystemExit('WeChat deployment target missing: ' + commands)
            numeric = lambda value: tuple((list(map(int, value.split('.'))) + [0, 0])[:3])
            minimum = max(versions, key=numeric)
            app_minimum = os.environ['IPHONEOS_DEPLOYMENT_TARGET']
            if numeric(minimum) > numeric(app_minimum):
                raise SystemExit(f'WeChat requires iOS {minimum}, app targets {app_minimum}')
            info_path = framework / 'Info.plist'
            info = plistlib.loads(info_path.read_bytes())
            print(f"WeChat minimum: plist={info.get('MinimumOSVersion')}, Mach-O={minimum}")
            info['MinimumOSVersion'] = minimum
            info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
            identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY', '')
            if identity and os.environ.get('CODE_SIGNING_ALLOWED') != 'NO':
                subprocess.run(['codesign', '--force', '--sign', identity, '--preserve-metadata=identifier,entitlements', str(framework)], check=True)
    else:
        print("No embedded WeChat framework to remove")
