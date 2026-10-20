import importlib.util
import json
import os
from types import SimpleNamespace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).parents[1] / 'release-android.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class AndroidReleaseTest(unittest.TestCase):
    def test_resume_rejects_missing_or_stale_apk(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'APK가 없습니다'):
                release.validate_existing_apk(root)
            apk = root / 'apps/sms_android/app/build/outputs/apk/release/app-release.apk'
            apk.parent.mkdir(parents=True)
            apk.write_bytes(b'test-apk')
            source = root / 'apps/sms_android/app/src/main/test.kt'
            source.parent.mkdir(parents=True)
            source.write_text('source')
            os.utime(source, (10, 10))
            os.utime(apk, (20, 20))
            with patch.object(release.subprocess, 'run', return_value=SimpleNamespace(stdout=str(source.relative_to(root)) + '\n')):
                self.assertEqual(release.validate_existing_apk(root), apk)
                os.utime(source, (30, 30))
                with self.assertRaisesRegex(RuntimeError, '소스가 기존 APK보다'):
                    release.validate_existing_apk(root)

    def test_partial_identity_never_generates_a_replacement_key(self):
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root)
            (directory / 'paylog-release.p12').write_bytes(b'original-key')
            with patch.object(release.subprocess, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, '백업을 복원'):
                    release.signing_material(directory, Path('/unused'))
                run.assert_not_called()
                self.assertEqual((directory / 'paylog-release.p12').read_bytes(), b'original-key')

    def test_existing_identity_is_reused_without_prompting(self):
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root)
            (directory / 'paylog-release.p12').write_bytes(b'original-key')
            (directory / 'signing.keypass').write_text('test-only-password')
            def unexpected_prompt(message):
                raise AssertionError('Existing key must not prompt for a new identity')
            store, password = release.signing_material(directory, Path('/unused'), unexpected_prompt)
            self.assertEqual(store.read_bytes(), b'original-key')
            self.assertEqual(password.stat().st_mode & 0o777, 0o600)

    def test_bad_or_mismatched_password_does_not_create_a_key(self):
        for passwords in [['short'], ['test-password-a', 'test-password-b']]:
            with tempfile.TemporaryDirectory() as root:
                directory = Path(root)
                with patch.object(release.subprocess, 'run') as run:
                    with self.assertRaises(RuntimeError):
                        release.signing_material(directory, Path('/unused'), lambda message: passwords.pop(0))
                    run.assert_not_called()
                    self.assertFalse((directory / 'signing.keypass').exists())

    def test_publish_whitelists_public_files_and_rejects_unsigned_apk(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            apk = root / 'app-release-unsigned.apk'
            apk.write_bytes(b'test-apk-bytes')
            with self.assertRaisesRegex(RuntimeError, '서명되지 않은'):
                release.stage_download(apk, root / 'web', {})
            signed = root / 'app-release.apk'
            signed.write_bytes(b'test-apk-bytes')
            metadata = release.stage_download(signed, root / 'web', {'certificateSha256':'a'*64, 'password':'PRIVATE_DO_NOT_PUBLISH'})
            self.assertEqual(metadata['sha256'], release.hashlib.sha256(signed.read_bytes()).hexdigest())
            files = list((root / 'web/downloads').iterdir())
            self.assertEqual(len(files), 4)
            self.assertFalse(any(b'PRIVATE_DO_NOT_PUBLISH' in f.read_bytes() for f in files))
            self.assertEqual(json.loads((root / 'web/downloads/android-release.json').read_text())['versionCode'], 2)

    def test_download_site_has_no_spa_fallback_and_forces_apk_download(self):
        config = release.hosting_config('paylog-c5c2d-android')['hosting']
        self.assertEqual(config['site'], 'paylog-c5c2d-android')
        self.assertNotIn('rewrites', config)
        headers = next(h['headers'] for h in config['headers'] if h['source'] == '/paylog-sms.apk')
        self.assertIn({'key':'Content-Type','value':'application/vnd.android.package-archive'}, headers)
        with self.assertRaises(RuntimeError):
            release.hosting_config('https://other.example/site')


if __name__ == '__main__':
    unittest.main()
