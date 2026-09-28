"""Prepare a disposable macOS runner; never run against a developer keychain."""
import base64
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import subprocess

BUNDLE = 'com.lingmei.kingclub'
TEAM = '239E9W6PEN'


def validate_profile(profile, now):
    entitlements = profile.get('Entitlements', {})
    if (profile.get('TeamIdentifier') != [TEAM]
            or entitlements.get('application-identifier') != TEAM + '.' + BUNDLE
            or entitlements.get('aps-environment') != 'development'
            or entitlements.get('get-task-allow') is not True
            or not profile.get('ProvisionedDevices')
            or profile.get('ExpirationDate', datetime.datetime.min) <= now
            or not re.fullmatch(r'[A-Fa-f0-9-]{36}', profile.get('UUID', ''))
            or not profile.get('DeveloperCertificates')):
        raise ValueError('Development provisioning profile does not match this app')


def configure_project(source, uuid, identity):
    # This marker exists only in the three Runner configurations, not plugins/tests.
    marker = '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ' + BUNDLE + ';'
    if source.count(marker) != 3:
        raise ValueError('Unexpected Runner project layout')
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', uuid) or not re.fullmatch(r'[A-F0-9]{40}', identity):
        raise ValueError('Invalid signing identifiers')
    settings = ('CODE_SIGN_STYLE = Manual;', 'DEVELOPMENT_TEAM = ' + TEAM + ';',
                'CODE_SIGN_IDENTITY = "' + identity + '";',
                'PROVISIONING_PROFILE_SPECIFIER = "' + uuid + '";',
                'APS_ENVIRONMENT = development;')
    return source.replace(marker, marker + '\n' + '\n'.join('\t\t\t\t' + s for s in settings))


def main():
    if os.uname().sysname != 'Darwin' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise SystemExit('Only use on a disposable GitHub macOS runner')
    os.umask(0o077)
    root = Path(os.environ['RUNNER_TEMP']) / 'kingclub-signing'
    root.mkdir()
    for name, env in [('identity.p12', 'IOS_P12_BASE64'), ('app.mobileprovision', 'IOS_PROFILE_BASE64')]:
        (root / name).write_bytes(base64.b64decode(os.environ[env], validate=True))
    def run(*args):
        result = subprocess.run(args, capture_output=True)
        if result.returncode:
            raise RuntimeError('Signing preparation command failed: ' + args[0])
        return result.stdout
    profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(root / 'app.mobileprovision')))
    validate_profile(profile, datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None))
    keychain = str(root / 'build.keychain-db')
    password = secrets.token_urlsafe(40)
    run('security', 'create-keychain', '-p', password, keychain)
    run('security', 'set-keychain-settings', '-lut', '3600', keychain)
    run('security', 'unlock-keychain', '-p', password, keychain)
    run('security', 'import', str(root / 'identity.p12'), '-P', os.environ['IOS_P12_PASSWORD'],
        '-k', keychain, '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
    run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:',
        '-s', '-k', password, keychain)
    run('security', 'list-keychains', '-d', 'user', '-s', keychain)
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning', keychain).decode()
    candidates = [hashlib.sha1(c).hexdigest().upper() for c in profile['DeveloperCertificates']]
    matches = [c for c in candidates if c in identities]
    if len(matches) != 1:
        raise ValueError('Profile must match exactly one imported signing identity')
    identity = matches[0]
    installed = []
    for directory in ['Library/MobileDevice/Provisioning Profiles',
                      'Library/Developer/Xcode/UserData/Provisioning Profiles']:
        dest = Path.home() / directory / (profile['UUID'] + '.mobileprovision')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((root / 'app.mobileprovision').read_bytes())
        installed.append(str(dest))
    (root / 'installed-profiles.json').write_text(json.dumps(installed))
    project = Path('ios/Runner.xcodeproj/project.pbxproj')
    project.write_text(configure_project(project.read_text(), profile['UUID'], identity))
    export = {'method': 'development', 'signingStyle': 'manual', 'teamID': TEAM,
              'signingCertificate': identity, 'provisioningProfiles': {BUNDLE: profile['UUID']},
              'manageAppVersionAndBuildNumber': False}
    (root / 'ExportOptions.plist').write_bytes(plistlib.dumps(export))
    print('Development signing configured; matching certificate and device profile verified.')


if __name__ == '__main__':
    main()
