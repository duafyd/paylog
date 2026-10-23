import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify', Path(__file__).parents[1] / 'verify-release.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyReleaseTest(unittest.TestCase):
    def web(self):
        return {'/': b'<script src="flutter_bootstrap.js"></script>',
                '/privacy.html': '<h1>개인정보처리방침</h1><a href="mailto:duafyd@gmail.com">문의</a>'.encode(),
                '/terms.html': '<h1>서비스 이용약관</h1><a href="mailto:duafyd@gmail.com">문의</a>'.encode(),
                '/manifest.json': b'{"display":"standalone","icons":[{"src":"icon.png"}]}'}

    def test_spa_fallback_is_not_a_privacy_policy(self):
        pages = self.web()
        pages['/privacy.html'] = pages['/']
        with self.assertRaisesRegex(RuntimeError, '실제 정책 문서'):
            verify.verify_web('', get=pages.__getitem__)

    def test_real_documents_and_manifest_pass(self):
        verify.verify_web('', get=self.web().__getitem__)

    def test_stale_javascript_cannot_pass_exact_build_check(self):
        pages = self.web()
        pages.update({'/index.html': pages['/'], '/main.dart.js': b'old',
                      '/flutter_bootstrap.js': b'bootstrap', '/legal.css': b'css'})
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, data in pages.items():
                if name != '/': (root / name[1:]).write_bytes(data)
            (root / 'main.dart.js').write_bytes(b'new')
            with self.assertRaisesRegex(RuntimeError, '해시가 다릅니다'):
                verify.verify_web('', root, pages.__getitem__)

    def android(self):
        apk = b'PKtest-public-apk'
        metadata = {'versionName': verify.release.VERSION, 'versionCode': verify.release.VERSION_CODE,
                    'url': verify.release.APK_URL, 'sha256': hashlib.sha256(apk).hexdigest(),
                    'size': len(apk), 'certificateSha256': 'a' * 64}
        return apk, metadata

    def test_old_version_is_rejected_before_download(self):
        apk, metadata = self.android()
        metadata['versionCode'] -= 1
        with self.assertRaisesRegex(RuntimeError, '최신 버전'):
            verify.verify_android('', get=lambda url: json.dumps(metadata).encode())

    def test_changed_apk_and_unexpected_download_url_are_rejected(self):
        apk, metadata = self.android()
        get = lambda url: json.dumps(metadata).encode() if url.endswith('.json') else apk
        verify.verify_android('', get=get)
        apk = b'PKdifferent-file'
        with self.assertRaisesRegex(RuntimeError, '무결성'):
            verify.verify_android('', get=get)
        metadata['url'] = 'https://unexpected.example/app.apk'
        with self.assertRaisesRegex(RuntimeError, '다운로드 주소'):
            verify.verify_android('', get=get)


if __name__ == '__main__':
    unittest.main()
