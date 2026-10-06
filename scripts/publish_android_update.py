"""Publish a verified preview APK, then atomically switch its version manifest.

Requires the operator's existing ccsop-test SSH alias and Android SDK aapt.
Never upload signing keys or build configuration. Existing iOS entry is preserved.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt', required=True)
    parser.add_argument('--notes', required=True, type=Path,
                        help='JSON array: Simplified Chinese, English, Traditional Chinese, Thai')
    args = parser.parse_args()
    apk = args.apk.resolve(strict=True)
    notes = json.loads(args.notes.read_text(encoding='utf-8-sig'))
    assert isinstance(notes, list) and len(notes) == 4 and all(isinstance(n, str) for n in notes)
    badging = subprocess.check_output([args.aapt, 'dump', 'badging', str(apk)], text=True, encoding='utf-8')
    match = re.search(r"package: name='com.lingmei.kingclub' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not match or not match[2].endswith('-preview'):
        raise ValueError('Only KINGCLUB preview packages may use this channel')
    build = int(match[1])
    with apk.open('rb') as source:
        sha = hashlib.file_digest(source, 'sha256').hexdigest()
    filename = f'kingclub-{build}-{sha[:12]}.apk'
    entry = {'build': build, 'version': match[2], 'bytes': apk.stat().st_size,
             'sha256': sha, 'url': 'https://test.wuyexin.cn/kingclub-updates/' + filename,
             'notes': notes}
    subprocess.run(['scp', str(apk), 'ccsop-test:/tmp/' + filename + '.part'], check=True)
    # Only structured, validated metadata enters the remote Python program.
    script = '''import hashlib,json,os
from pathlib import Path
entry=json.loads(ENTRY)
filename=FILENAME
root=Path('/var/www/kingclub-updates')
source=Path('/tmp')/(filename+'.part')
with source.open('rb') as f: actual=hashlib.file_digest(f,'sha256').hexdigest()
assert actual==entry['sha256'] and source.stat().st_size==entry['bytes']
manifest=root/'preview.json'
data=json.loads(manifest.read_text())
assert data['schema']==1
previous=data.get('android')
assert not previous or entry['build']>previous['build'] or (entry['build']==previous['build'] and entry['sha256']==previous['sha256'])
target=root/filename
if target.exists():
 with target.open('rb') as f: assert hashlib.file_digest(f,'sha256').hexdigest()==actual
 source.unlink()
else: os.replace(source,target)
target.chmod(0o644)
data['android']=entry
temporary=root/'preview.json.next'
temporary.write_text(json.dumps(data,ensure_ascii=False))
temporary.chmod(0o644)
os.replace(temporary,manifest)
print('Published Android build',entry['build'])
'''.replace('ENTRY', repr(json.dumps(entry))).replace('FILENAME', repr(filename))
    subprocess.run(['ssh', 'ccsop-test', 'sudo python3 -'], input=script, text=True, encoding='utf-8', check=True)


if __name__ == '__main__':
    main()
