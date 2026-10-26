"""Only runs the standalone synthetic .qa.design profile probe. No real DB."""
from pathlib import Path
import json
import re
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
adb = root / '.tooling/android-sdk/platform-tools/adb.exe'
device = sys.argv[1]
package = 'app.lianji.training.qa.design'


def call(*args):
    result = subprocess.run([str(adb), '-s', device, *args], capture_output=True, timeout=90)
    if result.returncode:
        raise RuntimeError('ADB operation failed; stopped without uninstall')
    return result.stdout.decode('utf-8', errors='replace')


if '--collect-only' not in sys.argv:
    call('shell', 'am', 'force-stop', package)
    installed = call('install', '--no-streaming', '-r', '-t',
                     str(root / 'build/app/outputs/flutter-apk/app-profile.apk'))
    if 'Success' not in installed:
        raise RuntimeError('Profile install failed; no uninstall retry')
    call('shell', 'run-as', package, 'rm', '-f', 'cache/input-profile-report.json')
    call('shell', 'am', 'start', '-W', '-n', package + '/app.lianji.training.MainActivity')
pid = call('shell', 'pidof', '-s', package).strip()
if not re.fullmatch(r'\d+', pid):
    raise RuntimeError('Profile process not found')
for _ in range(45):
    saved = subprocess.run([str(adb), '-s', device, 'exec-out', 'run-as', package,
                            'cat', 'cache/input-profile-report.json'],
                           capture_output=True, timeout=15)
    if saved.returncode == 0 and saved.stdout:
        try:
            report = json.loads(saved.stdout)
        except (json.JSONDecodeError, UnicodeDecodeError):
            # adb exec-out may return a remote cat error on stdout, or the
            # application may still be writing. Neither is a valid report.
            time.sleep(2)
            continue
        target = root / 'artifacts/input-0.2.12/profile-device.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False))
        call('shell', 'am', 'force-stop', package)
        if not all(report[str(n)]['latencyP95Within50ms'] for n in [200, 1000]):
            raise RuntimeError('Measured latency exceeds 50ms target')
        break
    time.sleep(2)
else:
    call('shell', 'am', 'force-stop', package)
    raise RuntimeError('Profile report timed out; no synthetic success recorded')
