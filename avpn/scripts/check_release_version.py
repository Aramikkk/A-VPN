"""Reject Android release versionCodes that do not increase."""
import os
from pathlib import Path
import re
import subprocess
import sys


def check_version(version_line, previous_codes):
    match = re.fullmatch(r"version:\s*([0-9]+(?:\.[0-9]+){2})\+([0-9]+)\s*", version_line)
    if not match:
        raise ValueError("Expected version: x.y.z+buildNumber")
    code = int(match[2])
    if code <= max(previous_codes, default=0):
        raise ValueError("Android buildNumber must exceed every published versionCode")
    return code


def main(repo, releases):
    version = next(line for line in Path(repo, 'pubspec.yaml').read_text(encoding='utf-8').splitlines() if line.startswith('version:'))
    apks = list(Path(releases).glob('*/*.apk'))
    codes = []
    if apks:
        sdk = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/build-tools'
        tools = sorted(sdk.glob('*/aapt.exe'), key=lambda p: tuple(int(n) for n in p.parent.name.split('.')))
        if not tools:
            raise RuntimeError('aapt.exe is required to verify published versionCodes')
        for apk in apks:
            data = subprocess.check_output([str(tools[-1]), 'dump', 'badging', str(apk)], text=True, encoding='utf-8')
            match = re.search(r"versionCode='([0-9]+)'", data)
            if not match:
                raise ValueError('Missing versionCode in ' + str(apk))
            codes.append(int(match[1]))
    print('Verified Android versionCode', check_version(version, codes))


if __name__ == '__main__':
    main(*sys.argv[1:])
