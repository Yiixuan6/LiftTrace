"""Whitelist-only source package. SDKs, databases, exports and private keys excluded."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parents[1]
version = re.search(r'^version:\s*([\d.]+)\+(\d+)', (root/'pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
stem = 'lianji-' + version
directories = ['assets','lib','test','integration_test','docs','scripts','工作记录','android/app/src','android/gradle/wrapper']
files = ['README.md','AGENTS.md','design-qa.md','.gitignore','.metadata','analysis_options.yaml','pubspec.yaml','pubspec.lock',
         'android/gradlew','android/gradlew.bat','android/build.gradle.kts','android/settings.gradle.kts',
         'android/gradle.properties','android/app/build.gradle.kts','android/.gitignore']
selected = {root / f for f in files if (root / f).is_file()}
for directory in directories:
    base = root / directory
    if base.exists(): selected.update(p for p in base.rglob('*') if p.is_file())
selected = {p for p in selected if '__pycache__' not in p.parts and p.suffix not in {'.pyc','.jks','.keystore','.db'} and p.name not in {'key.properties','local.properties','password.txt','GeneratedPluginRegistrant.java'}}
out = root / 'artifacts/release'
out.mkdir(parents=True,exist_ok=True)
archive = out / (stem + '-source.zip')
manifest = []
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(selected):
        name = p.relative_to(root).as_posix()
        z.write(p,name)
        manifest.append({'path':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    z.writestr('SOURCE_MANIFEST.json',json.dumps(manifest,ensure_ascii=False,indent=2))
(out / 'source-sha256.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n',encoding='utf-8')
print(archive.name, 'files',len(manifest),'bytes',archive.stat().st_size)
evidence=out/(stem+'-evidence.zip')
public_logs=['analyze.log','tests.log','visual-final.log','visual-version.txt','build-unsigned-third.log','build-release.log','build-qa-release.log','plan-integrity.txt','signing-public-info.txt','android-integration.log','android-integration-install-rejected.log','android-recovery-seed.log','android-recovery-process.log','android-recovery-resume.log','android-recovery-resume-first-failed.log','android-release-install.log','android-release-final-launch.log']
public_files=[root/'artifacts'/name for name in public_logs if (root/'artifacts'/name).is_file()]
public_files += [root/'artifacts'/name for name in ['reminders-tests.log', 'rest-background-device.log', 'rest-background-device.json'] if (root/'artifacts'/name).is_file()]
public_files += [root/'artifacts'/name for name in ['rest-background-vm-failed.log', 'rest-background-vm-failed.json'] if (root/'artifacts'/name).is_file()]
public_files += [root/'artifacts/rest-background-standalone-idle-failed.json'] if (root/'artifacts/rest-background-standalone-idle-failed.json').is_file() else []
if (root/'artifacts/android-integration-version.txt').is_file(): public_files.append(root/'artifacts/android-integration-version.txt')
public_files += [root/'artifacts/release'/name for name in ['apk-badging.txt','apk-manifest.txt','unsigned-signature-check.txt','unsigned-sha256.txt','signature-verification.txt','SHA256.txt','release-badging.txt','release-manifest.txt'] if (root/'artifacts/release'/name).is_file()]
public_files+=list((root/'artifacts/screenshots').glob('*.png'))
public_files+=list((root/'artifacts/device-screenshots').glob('*.png'))
public_files+=list((root/'artifacts/ui-redesign').glob('*.png'))
public_files+=list((root/'artifacts/ui-redesign').glob('*.log'))
for evidence_version in set(['0.2.2', '0.2.3', version]):
    public_files += list((root/'artifacts/ui-redesign'/f'{evidence_version}-native-frames').glob('*.png'))
for name in set(['0.2.2-native-sequence.json', '0.2.3-native-sequence.json', f'{version}-native-sequence.json']):
    if (root/'artifacts/ui-redesign'/name).exists(): public_files.append(root/'artifacts/ui-redesign'/name)
if (root/'artifacts/ui-redesign/layout-metrics.json').exists(): public_files.append(root/'artifacts/ui-redesign/layout-metrics.json')
public_files+=list((root/'artifacts/design-concepts').rglob('*.png'))
public_files+=list((root/'artifacts').glob('contact-*.png'))
public_files += list((root/'artifacts/style-refresh').rglob('*.png'))
public_files += list((root/'artifacts/style-refresh').rglob('*.json'))
public_files += list((root/'artifacts').glob('style-*.log'))
public_files += [root/'artifacts'/name for name in ['android-design-preflight.log','qa-release-signature.txt'] if (root/'artifacts'/name).exists()]
for suffix in ('*.png', '*.json', '*.log'):
    public_files += list((root/'artifacts'/f'rest-fix-{version}').rglob(suffix))
public_files += list((root/'artifacts/export-migration-0.2.10').glob('*.json'))
public_files += list((root/'artifacts/rest-fix-0.2.9').rglob('*.json'))
public_files += list((root/'artifacts/localization-0.2.11').rglob('*.png'))
public_files += list((root/'artifacts/localization-0.2.11').glob('*.json'))
public_files += list((root/'artifacts').glob('l10n-*.log'))
for suffix in ('*.png', '*.json', '*.log'):
    public_files += list((root/'artifacts/input-0.2.12').rglob(suffix))
public_files += list((root/'artifacts').glob('input-*.log'))
public_files += [root/'artifacts/input-profile-signature.txt'] if (root/'artifacts/input-profile-signature.txt').exists() else []
with zipfile.ZipFile(evidence,'w',zipfile.ZIP_DEFLATED) as z:
    # Device identifiers are local diagnostics, never public delivery evidence.
    devices = root/'artifacts/android-devices.log'
    serials = re.findall(r'^([\w.:-]+)\s+device\b',devices.read_text(encoding='utf-8-sig',errors='replace'),re.M) if devices.exists() else []
    for p in sorted(public_files):
        if p.suffix == '.png':
            z.write(p,p.relative_to(root).as_posix())
        else:
            content = p.read_text(encoding='utf-8-sig',errors='replace')
            for serial in serials: content=content.replace(serial,'[device-redacted]')
            z.writestr(p.relative_to(root).as_posix(),content)
print(evidence.name,'files',len(public_files),'bytes',evidence.stat().st_size)
