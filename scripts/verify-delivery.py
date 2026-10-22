"""Verify release archives and write an evidence-based delivery manifest."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/release'
version_match = re.search(r'^version:\s*([\d.]+)\+(\d+)', (root/'pubspec.yaml').read_text(encoding='utf-8'), re.M)
version, build = version_match.groups()
stem = 'lianji-' + version
password_file = root / 'artifacts/private/signing/password.txt'
private_literal = password_file.read_bytes() if password_file.exists() else None
for name in [stem+'-source.zip', stem+'-evidence.zip']:
    with zipfile.ZipFile(out / name) as archive:
        if archive.testzip() is not None:
            raise ValueError('Archive CRC failed')
        for entry in archive.namelist():
            path = Path(entry)
            if (any(part in {'.tooling', '.pub-cache', 'private', 'build', '__pycache__'} for part in path.parts)
                    or path.suffix in {'.jks', '.keystore', '.db', '.pyc'}
                    or path.name in {'key.properties', 'password.txt', 'local.properties', 'GeneratedPluginRegistrant.java'}):
                raise ValueError('Excluded file found: ' + entry)
            if private_literal and private_literal in archive.read(entry):
                raise ValueError('Private credential literal found in archive')
        if name.endswith('-source.zip'):
            assert 'assets/images/home-hero-jade.png' in archive.namelist(), 'Offline hero asset missing from source'
            assert 'assets/icons/arm-flex.png' in archive.namelist(), 'Offline muscle icon missing'
            assert 'assets/icons/arm-flex.svg' in archive.namelist(), 'Upstream icon source missing'
            assert 'assets/licenses/mdi.txt' in archive.namelist(), 'Icon license missing'
            assert 'assets/icons/recent-dumbbell.png' in archive.namelist(), 'Recent/bar navigation icon missing'
            assert 'assets/icons/recent-dumbbell.svg' in archive.namelist(), 'Recent icon upstream source missing'
            assert 'assets/licenses/fontawesome.txt' in archive.namelist(), 'Recent icon attribution missing'
            assert 'assets/shaders/liquid_glass.frag' in archive.namelist(), 'Liquid refraction shader source missing'
            assert 'lib/ui/liquid_glass.dart' in archive.namelist(), 'Liquid surface implementation missing'
            assert 'lib/l10n/app_strings.dart' in archive.namelist(), 'Localization delegate missing'
            assert 'assets/translations/en.json' in archive.namelist(), 'English messages missing'
            assert 'assets/translations/zh_Hant.json' in archive.namelist(), 'Traditional Chinese messages missing'
            assert 'test/localization_test.dart' in archive.namelist(), 'Locale and data preservation tests missing'
            assert 'integration_test/localization_test.dart' in archive.namelist(), 'Native localization fixture missing'
            assert 'docs/REST_REMINDERS.md' in archive.namelist(), 'Cross-app reminder handoff missing'
            assert 'test/reminders_test.dart' in archive.namelist(), 'Notification regression missing'
            assert 'test/rest_workflow_test.dart' in archive.namelist(), 'Rest workflow regression missing'
            assert 'test/rest_layout_test.dart' in archive.namelist(), 'Rest controls accessibility regression missing'
            assert 'android/app/src/main/res/raw/keep.xml' in archive.namelist(), 'Notification drawable keep rule missing'
            assert 'scripts/check-reminder-apk.ps1' in archive.namelist(), 'Release notification resource gate missing'
            assert 'test/set_order_test.dart' in archive.namelist(), 'Newest-first set identity regression missing'
            assert 'test/statistics_presentation_test.dart' in archive.namelist(), 'Statistics conservation tests missing'
            assert 'test/statistics_layout_test.dart' in archive.namelist(), 'Statistics interaction tests missing'
            assert 'test/field_layout_test.dart' in archive.namelist(), 'External captions and equal action sizes regression missing'
            assert 'docs/PAGE_REFRESH.md' in archive.namelist(), 'Editorial page handoff missing'
            assert 'integration_test/rest_probe_app.dart' in archive.namelist(), 'Standalone device fixture missing'
            assert 'design-qa.md' in archive.namelist(), 'Visual QA report missing from source'
            manifest = json.loads(archive.read('SOURCE_MANIFEST.json'))
            assert len(manifest) + 1 == len(archive.namelist())
            for item in manifest:
                assert hashlib.sha256(archive.read(item['path'])).hexdigest() == item['sha256']
    print(name, 'CRC / exclusions / source hashes verified')

def log(name):
    path = root / 'artifacts' / name
    return path.read_text(encoding='utf-8-sig', errors='replace') if path.exists() else ''

apk = out / (stem+'.apk')
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
assert digest in (out / 'SHA256.txt').read_text(encoding='utf-8-sig').lower()
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in (out / 'signature-verification.txt').read_text(encoding='utf-8-sig')
flow = 'All tests passed!' in log('android-integration.log')
recovery = all('All tests passed!' in log('android-recovery-' + phase + '.log') for phase in ['seed', 'resume'])
optics_version = version if log('ui-redesign/'+version+'-gpu-optics.log') else '0.2.3'
navigation_version = version if log('ui-redesign/'+version+'-native-sequence.json') else '0.2.3'
rest_probe = json.loads(log('rest-background-device.json') or '{}')
release_rest = json.loads(log(f'rest-fix-{version}/release-device.json') or '{}')
release_sleep = json.loads(log(f'rest-fix-{version}/release-lock-device.json') or '{}')
release_upgrade = json.loads(log(f'rest-fix-{version}/user-upgrade.json') or '{}')
manifest = {
    'status': 'signed_release_partial_device_acceptance' if flow else 'signed_release_device_acceptance_pending',
    'applicationId': 'app.lianji.training', 'version': version+'+'+build,
    'packageRoles': {'formal': 'app.lianji.training', 'existingPhoneQa': 'app.lianji.training.qa', 'currentDailyApp': 'app.lianji.training'},
    'currentDailyAppVersion': (json.loads(log('localization-0.2.11/report.json') or '{}').get('phoneInstalledVersion', '0.2.10+12')),
    'retainedPhoneQaVersion': '0.2.9+11',
    'visualEvidenceBaselineVersion': '0.2.9+11',
    'minimumAndroidApi': 26, 'targetAndroidApi': 36,
    'automatedTestsPassed': int(re.findall(r'\+(\d+)[^\n]*All tests passed!', log('tests.log'))[-1]), 'visualScreenshots': len(list((root/'artifacts/screenshots').glob('*.png'))),
    'visualPagesAt200Percent': 16, 'apkSigned': True,
    'releaseKeyCreated': True,
    'certificateSha256': '2246bdf6a62b0c1e059d56d24b5d556bb046b0f6bfadd5aa2f43a3eefb320944',
    'deviceInstallAttempted': True,
    'deviceAndroidApi': 36,
    'qaReleaseInstallAndLaunchPassed': 'Status: ok' in log('android-release-final-launch.log'),
    'qaNormalHomeVersion': version+'+'+build if 'normal_home_visible=True' in log('ui-redesign/'+version+'-normal-home.log') else None,
    'qaNormalHomeVisible': 'normal_home_visible=True' in log('ui-redesign/'+version+'-normal-home.log'),
    'nativeHomeScreenshots': len(list((root / 'artifacts/device-screenshots').glob('*.png'))),
    'qaTrainingFlowPassed': flow, 'qaForceStopRecoveryPassed': recovery,
    'qaTrainingFlowVersion': log('android-integration-version.txt').strip() or '0.2.1+3',
    'qaTabSwitchIntermediateFramesPassed': flow,
    'navigationImplementation': 'StatefulShellRoute.indexedStack',
    'qaGlassTransparencyPixelRegressionPassed': '玻璃内部实际透出背后颜色' in log('ui-redesign/'+version+'-capture.log') and 'All tests passed!' in log('ui-redesign/'+version+'-capture.log'),
    'qaSetOrderRegressionPassed': 'All tests passed!' in log('ui-redesign/'+version+'-set-order.log'),
    'qaSetOrderScreenshotSuitePassed': 'All tests passed!' in log('ui-redesign/'+version+'-set-order-capture.log'),
    'qaSetOrderScreenshot': 'artifacts/ui-redesign/'+version+'-reverse-sets.png',
    'qaSetOrderFixtureReadsExistingDatabase': False,
    'visualMultiSizeEvidenceVersion': log('visual-version.txt').strip() or '0.2.4+6',
    'qaCompactWorkoutScreenshot': 'artifacts/ui-redesign/'+version+'-compact-training.png' if (root/'artifacts/ui-redesign'/f'{version}-compact-training.png').exists() else None,
    'qaMovesNewestFirstRegressionPassed': '紧凑统计与休息下方入口' in log('ui-redesign/'+version+'-set-order.log') and 'All tests passed!' in log('ui-redesign/'+version+'-set-order.log'),
    'qaLiquidGpuOpticsPassed': 'All tests passed!' in log('ui-redesign/'+optics_version+'-gpu-optics.log'),
    'qaLiquidGpuOpticsEvidenceVersion': optics_version,
    'qaNativeNavigationSampleCount': json.loads(log('ui-redesign/'+navigation_version+'-native-sequence.json') or '{}').get('screenshots',0),
    'qaNativeNavigationCaptureType': json.loads(log('ui-redesign/'+navigation_version+'-native-sequence.json') or '{}').get('captureType'),
    'qaNativeMemoryNavigationPassed': 'All tests passed!' in log('ui-redesign/'+navigation_version+'-native-memory-navigation.log'),
    'qaNativeNavigationEvidenceVersion': navigation_version,
    'qaNativeVisualReadsExistingDatabase': json.loads(log('ui-redesign/'+navigation_version+'-native-sequence.json') or '{}').get('readsExistingDatabase'),
    'qaRestOtherAppNotificationPosted': rest_probe.get('systemPostedSyntheticReminder', False),
    'qaRestProbeVersion': rest_probe.get('version'),
    'restReleaseFixEvidence': release_rest,
    'restReleaseScreenOffEvidence': release_sleep,
    'restControlsSixThemesLargeFontPassed': 'All tests passed!' in log(f'rest-fix-{version}/layout-capture.log'),
    'restControlsScreenshotCount': len(list((root/'artifacts'/f'rest-fix-{version}'/'screenshots').glob('*.png'))),
    'qaRestHeadsUpVisuallyVerified': rest_probe.get('headsupVisuallyVerified', False),
    'qaRestVibratorServiceObserved': rest_probe.get('vibratorHistoryHasQaUid', False),
    'qaRestVibratorServiceFinished': rest_probe.get('vibratorServiceFinishedVerified', False),
    'qaRestVibrationDurationMilliseconds': rest_probe.get('systemVibrationDurationMs'),
    'qaRestNotificationObservedDelayMilliseconds': rest_probe.get('observedPostDelayMilliseconds'),
    'qaRestProbeReadsTrainingDatabase': rest_probe.get('trainingDatabaseRead'),
    'qaRestPhysicalVibrationUserConfirmed': rest_probe.get('physicalVibrationUserConfirmed', False),
    'qaNativeContinuousRecordingPassed': False,
    'qaNavigationInstantaneousFlickerUserRetestPending': True,
    'qaRecordingProbeCleanedByAuthorizedReboot': 'screenrecord_absent=true' in log('ui-redesign/0.2.2-reboot-cleanup.log'),
    'qaRecordingProbeCleanupBaselineVersion': '0.2.2+4',
    'qaForceStopRecoveryBaselineVersion': '0.1.0+1',
    'qaUpgradeFrom010PreservationPassed': 'All tests passed!' in log('ui-redesign/android-upgrade.log'),
    'qaUpgradeFrom010PreservationBaselineVersion': '0.2.0+2',
    'visualDesignQaPassed': 'final result: passed' in (root/'design-qa.md').read_text(encoding='utf-8'),
    'allAcceptanceItemsPassed': False,
    'editorialPagesVersion': '0.2.9+11',
    'multilingualEvidence': json.loads(log('localization-0.2.11/report.json') or '{}'),
    'exportNamingAndFormalMigrationEvidence': json.loads(log('export-migration-0.2.10/report.json') or '{}'),
    'restReleasePriorVersion': '0.2.9+11',
    'restReleasePriorEvidence': json.loads(log('rest-fix-0.2.9/release-device.json') or '{}'),
    'externalCaptionAndEqualActionRegressionPassed': 'All tests passed!' in log('style-fields-statistics-final.log') and '标签空值、有值、焦点和200%' in log('style-fields-statistics-final.log') and '模板外置字段仍验证组数' in log('style-fields-statistics-final.log'),
    'editorialAllPagesSixThemesScreenshotCount': len(list((root/'artifacts/screenshots').glob('*.png'))),
    'editorialStatisticsRegressionPassed': 'All tests passed!' in log('style-fields-statistics-final.log') and '大量逐组节点完整保留并能横向浏览' in log('style-fields-statistics-final.log'),
    'editorialNativeIsolatedPackage': 'app.lianji.training.qa.design',
    'editorialNativeSyntheticEvidence': json.loads((root/'artifacts/style-refresh/native/report.json').read_text(encoding='utf-8')) if (root/'artifacts/style-refresh/native/report.json').exists() else None,
    'qaUserUpgradeBusinessDataPreserved': release_upgrade or (json.loads((root/'artifacts/style-refresh/user-upgrade-verification.json').read_text(encoding='utf-8')) if (root/'artifacts/style-refresh/user-upgrade-verification.json').exists() else None),
    'normalQaRequestedWebdavControlsVerified': json.loads((root/'artifacts/style-refresh/normal-qa-action-verification.json').read_text(encoding='utf-8')) if (root/'artifacts/style-refresh/normal-qa-action-verification.json').exists() else None,
    'pendingInputs': ['legacy website source and JSON', 'real WebDAV service'],
    'pendingValidation': ['Android 8/9/13 and shader fallback appearance', 'airplane mode and long-duration OEM power policy', 'lock-screen reminder delivery and native permission-denial flow', 'actual video player notification policy and user physical vibration perception', 'other native document pickers and on-device failed restore', 'cross-version schema migration', 'continuous native video and user instantaneous flicker retest'],
    'privateSigningFilesExcluded': True,
    'files': {},
}
for name in [stem+'.apk', stem+'-qa.apk', stem+'-source.zip', stem+'-evidence.zip']:
    path = out / name
    manifest['files'][name] = {'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
(out / 'delivery-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Signed APK hash and public signature evidence verified; manifest updated')
