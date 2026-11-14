"""Writes latest.json next to the release's APK: what the app's own update reads (version, build number, the APK's name and
size, and what is new from the top of the changelog). Usage: python make_latest.py <repo> <release folder>"""
import hashlib
import json
import re
import sys
from pathlib import Path


def main(repo, release):
    repo, release = Path(repo), Path(release)
    pubspec = (repo / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([0-9.]+)\+([0-9]+)', pubspec, re.M)
    version, build = match.group(1), int(match.group(2))
    apk = next(release.glob('A-VPN-[0-9]*-arm64.apk'))
    log = (repo / 'avpn' / 'CHANGELOG.md').read_text(encoding='utf-8')
    head = re.search(r'^## ' + re.escape(version) + r'\b.*?\n(.*?)(?=^## |\Z)', log, re.M | re.S)
    notes = '\n'.join(line.lstrip('- ').strip() for line in (head.group(1) if head else '').splitlines() if line.strip())
    data = {'version': version, 'build': build, 'apk': apk.name, 'size': apk.stat().st_size, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'notes': notes}
    (release / 'latest.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    print('latest.json:', version, build, apk.name, apk.stat().st_size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
