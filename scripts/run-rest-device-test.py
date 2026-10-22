"""Release-only rest reminder acceptance, isolated .qa.design and synthetic memory data."""
from pathlib import Path
from datetime import datetime
import argparse
import json
import os
import re
import shutil
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('device')
parser.add_argument('--rounds', type=int, default=2)
parser.add_argument('--lock-screen', action='store_true')
parser.add_argument('--reuse-apk', action='store_true')
parser.add_argument('--clean-own-failed-probe', action='store_true')
args = parser.parse_args()
assert 0 <= args.rounds <= 3 and (args.rounds or args.lock_screen)
root = Path(os.environ['PUB_CACHE']).parent
assert (root/'AGENTS.md').exists() and 'name: lianji' in (root/'pubspec.yaml').read_text(encoding='utf-8')
package = 'app.lianji.training.qa.design'
adb = str(root/'.tooling/android-sdk/platform-tools/adb.exe')
aapt = str(root/'.tooling/android-sdk/build-tools/36.0.0/aapt.exe')
version, number = re.search(r'^version:\s*([\d.]+)\+(\d+)', (root/'pubspec.yaml').read_text(encoding='utf-8'), re.M).groups()
out = root/f'artifacts/rest-fix-{version}'
out.mkdir(parents=True, exist_ok=True)
meta = root/f'artifacts/qa/rest-release-{version}-probe.json'
if args.reuse_apk:
    token = json.loads(meta.read_text(encoding='utf-8'))['token']
    assert re.fullmatch(r'[a-f0-9]{32}', token)
else:
    token = uuid.uuid4().hex
external = f'/sdcard/Android/data/{package}/files'
init_marker = f'{external}/rest-init-{token}.json'
ready_marker = f'{external}/rest-qa-{token}.json'

def run(*cmd, strict=True, timeout=25):
    value = subprocess.run([adb, '-s', args.device, *cmd], capture_output=True, timeout=timeout)
    if strict and value.returncode:
        raise RuntimeError('ADB operation failed: '+cmd[0])
    return value.stdout.decode('utf-8', 'replace') if value.returncode == 0 else ''

def read_marker(path, seconds=20):
    limit = time.monotonic()+seconds
    while time.monotonic() < limit:
        try:
            result = json.loads(run('exec-out', 'cat', path, strict=False))
            return result
        except json.JSONDecodeError:
            time.sleep(.3)
    raise RuntimeError('No isolated release marker: '+path.rsplit('/',1)[-1])

def nodes():
    remote = f'/data/local/tmp/rest-release-{token}.xml'
    try:
        run('shell', 'uiautomator', 'dump', remote)
        return list(ET.fromstring(run('exec-out', 'cat', remote)).iter('node'))
    finally:
        run('shell', 'rm', '-f', remote, strict=False)

def record():
    # Full system dump stays in memory. Only synthetic package/id 71 is examined.
    raw = run('shell', 'dumpsys', 'notification')
    entries = re.split(r'(?=NotificationRecord\()', raw)
    return next((s for s in entries if re.search(r'\bpkg='+re.escape(package)+r'\b', s.splitlines()[0])
                 and re.search(r'\bid=71\b', s.splitlines()[0])), '')

report = {'version': version+'+'+number, 'testPackage': package, 'buildMode': 'release',
          'trainingDatabaseRead': False, 'permissionsSetupOnlyForIsolatedFixture': True,
          'physicalVibrationUserConfirmed': False, 'headsupVisuallyVerified': False,
          'rounds': []}
try:
    env = os.environ.copy()
    env['LIANJI_TEST_BUILD'] = '1'
    env['LIANJI_QA_SUFFIX'] = '.qa.design'
    apk = root/f'artifacts/qa/lianji-{version}-rest-design-release.apk'
    extra = []
    if args.clean_own_failed_probe:
        assert not args.reuse_apk
        previous = json.loads((out/'third-background-delivery-failed.json').read_text(encoding='utf-8'))
        assert previous['testPackage'] == package and previous['trainingDatabaseRead'] is False
        assert previous['rounds'] and previous['rounds'][0]['systemPostedReminder'] is False
        extra = ['--dart-define=QA_CLEAN_OWN_PROBE=true']
    if not args.reuse_apk:
        with (out/'release-probe-build.log').open('w', encoding='utf-8') as log:
            child = subprocess.Popen(['cmd.exe', '/d', '/c', str(root/'.tooling/flutter/bin/flutter.bat'),
                'build', 'apk', '--release', '-t', 'integration_test/rest_probe_app.dart',
                '--dart-define=QA_TOKEN='+token,*extra], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
            while child.poll() is None:
                run('shell','input','keyevent','224',strict=False)
                time.sleep(5)
            code = child.returncode
        assert code == 0, 'Release probe build failed'
        apk.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root/'build/app/outputs/flutter-apk/app-release.apk', apk)
        meta.write_text(json.dumps({'token':token}),encoding='utf-8')
    badging = subprocess.check_output([aapt, 'dump', 'badging', str(apk)], timeout=20).decode()
    assert "name='"+package+"'" in badging, 'Wrong identity; refuse installation'
    resources = subprocess.check_output([aapt, 'dump', 'resources', str(apk)], timeout=20).decode()
    assert ':drawable/ic_notification' in resources, 'Missing notification resource; refuse installation'
    report['releaseIconPresent'] = True
    installed = run('install', '--no-streaming', '-r', '-t', str(apk), timeout=100)
    assert 'Success' in installed, 'Install failed; never uninstall/retry'
    # Test-fixture setup only. Never change real QA or global device settings.
    # Allow notifications and exact alarms in this fixture's normal system UI first.
    package_dump = run('shell', 'dumpsys', 'package', package)
    uid = re.search(r'(?:userId|appId)=(\d+)', package_dump).group(1)
    contexts = ['other-app'] * args.rounds + (['locked-screen'] if args.lock_screen else [])
    for context in contexts:
        run('shell', 'am', 'force-stop', package)
        for marker in [init_marker, ready_marker]:
            run('shell', 'rm', '-f', marker, strict=False)
        run('shell','input','keyevent','224')
        run('shell', 'am', 'start', '-W', '-n', package+'/app.lianji.training.MainActivity')
        initialized = read_marker(init_marker)
        assert initialized['initialized'], 'Release initialization failed'
        button = None
        for _ in range(5):
            ns = nodes()
            button = next((n for n in ns if n.get('package') == package
                and '完成下一组' in n.get('content-desc','')), None)
            if button is not None: break
            time.sleep(.5)
        assert button is not None, 'Expected synthetic training page'
        x1,y1,x2,y2 = map(int, re.findall(r'\d+',button.get('bounds')))
        run('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
        ready = read_marker(ready_marker)
        assert ready.get('ready', True), 'Timer permission/channel not ready'
        deadline = datetime.fromisoformat(ready['deadline'].replace('Z','+00:00')).timestamp()
        vibration_before = set(run('shell','dumpsys','vibrator_manager').splitlines())
        keyguard_locked = False
        if context == 'locked-screen':
            run('shell','input','keyevent','223')
            sleep_limit = time.monotonic()+4
            power = ''
            while time.monotonic()<sleep_limit:
                power = run('shell','dumpsys','power')
                if re.search(r'mWakefulness=(?:Asleep|Dozing)',power) or re.search(r'state=(?:OFF|DOZE)',power): break
                time.sleep(.2)
            assert re.search(r'mWakefulness=(?:Asleep|Dozing)',power) or re.search(r'state=(?:OFF|DOZE)',power), 'Screen did not sleep'
            trust = run('shell','dumpsys','trust')
            keyguard_locked = bool(re.search(r'deviceLocked\s*=\s*true',trust))
        else:
            run('shell','am','start','-W','-a','android.settings.DISPLAY_SETTINGS')
            window = run('shell','dumpsys','window')
            assert re.search(r'mCurrentFocus=[^\n]*com\.android\.settings',window), 'Other app not foreground'
        last_wake = 0.0
        while time.time() < deadline-.4:
            if context == 'other-app' and time.monotonic()-last_wake > 5:
                run('shell','input','keyevent','224')
                last_wake = time.monotonic()
            time.sleep(.2)
        observed = None
        while time.time() < deadline+15:
            if record(): observed=time.time(); break
            time.sleep(.25)
        finished = False
        vibration = []
        vibration_limit = time.monotonic()+8
        while time.monotonic() < vibration_limit:
            vibration = [line for line in run('shell','dumpsys','vibrator_manager').splitlines()
                         if line not in vibration_before and package in line
                         and re.search(r'\b'+uid+r'\b',line)]
            finished = any(re.search(r'\bfinished\b',line,re.I) for line in vibration)
            if finished: break
            time.sleep(.3)
        result = {'context':context, 'releaseInitializationPassed':True,
                  'systemPostedReminder':observed is not None,
                  'observedDelayMs':round((observed-deadline)*1000) if observed else None,
                  'vibrationServiceObserved':bool(vibration), 'vibrationServiceFinished':finished,
                  'noTrainingDatabaseRead':True,
                  'keyguardLockedConfirmed':keyguard_locked,
                  'vibrationDurationsMs':[int(m.group(1)) for line in vibration for m in [re.search(r'duration:\s*(\d+)ms',line)] if m]}
        report['rounds'].append(result)
        print(json.dumps(result),flush=True)
        if context == 'locked-screen':run('shell','input','keyevent','224')
        assert observed is not None, 'No system notification before timeout'
        assert finished, 'No completed vibration service event'
        run('shell','am','force-stop',package)
        for marker in [init_marker,ready_marker]:run('shell','rm','-f',marker,strict=False)
    report['passed'] = True
except Exception as error:
    report['passed'] = False
    report['failure'] = str(error)
    raise
finally:
    (out/('release-lock-device.json' if args.lock_screen else 'release-device.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
