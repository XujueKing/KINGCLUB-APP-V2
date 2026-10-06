"""Remove SPM's embedded static WeChat archive before Xcode signs Runner."""
import os
from pathlib import Path
import shutil
import struct


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
        if not is_static(binary.read_bytes()):
            raise SystemExit("WeChat SDK changed: inspect dynamic framework before packaging")
        shutil.rmtree(framework)
        print("Removed embedded static WeChat archive; linked SDK remains in Runner")
    else:
        print("No embedded WeChat framework to remove")
