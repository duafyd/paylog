import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('deploy', Path(__file__).parents[1] / 'deploy-hosting.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
VALID = {'FIREBASE_PROJECT_ID': 'paylog-test-project', 'GOOGLE_WEB_CLIENT_ID': '123456789-test.apps.googleusercontent.com'}


class DeploymentPreflightTest(unittest.TestCase):
    def test_missing_or_sample_settings_prevent_any_cli_call(self):
        for env in [{}, {**VALID, 'GOOGLE_WEB_CLIENT_ID': 'browser-test.apps.googleusercontent.com'}, {**VALID, 'FIREBASE_PROJECT_ID': 'invalid/project'}]:
            with patch.object(deploy, 'firebase') as cli:
                with self.assertRaises(RuntimeError):
                    deploy.preflight(env)
                cli.assert_not_called()

    def test_platform_adc_cannot_substitute_for_user_login(self):
        env = {**VALID, 'GOOGLE_APPLICATION_CREDENTIALS': '/platform/credential-file'}
        def no_accounts(args, clean_env):
            self.assertNotIn('GOOGLE_APPLICATION_CREDENTIALS', clean_env)
            self.assertEqual(args, ['login:list'])
            return []
        with patch.object(deploy, 'firebase', side_effect=no_accounts):
            with self.assertRaisesRegex(RuntimeError, 'Firebase 인증이 없습니다'):
                deploy.preflight(env)

    def test_incomplete_cli_session_cannot_fall_back_to_adc(self):
        with patch.object(deploy, 'firebase', return_value=[{'user': {'email': 'test@example.com'}, 'tokens': {}}]) as cli:
            with self.assertRaisesRegex(RuntimeError, 'Firebase 인증이 없습니다'):
                deploy.preflight(VALID)
            self.assertEqual(cli.call_count, 1)

    def test_project_must_be_accessible_to_explicit_user_identity(self):
        env = {**VALID, 'FIREBASE_TOKEN': 'test-placeholder-only'}
        with patch.object(deploy, 'firebase', return_value=[{'projectId': 'another-project'}]):
            with self.assertRaisesRegex(RuntimeError, '프로젝트를 찾지 못했습니다'):
                deploy.preflight(env)
        with patch.object(deploy, 'firebase', return_value=[{'projectId': VALID['FIREBASE_PROJECT_ID']}]):
            self.assertEqual(deploy.preflight(env)[:2], (VALID['FIREBASE_PROJECT_ID'], VALID['GOOGLE_WEB_CLIENT_ID']))

    def test_cli_errors_do_not_echo_credential_bearing_output(self):
        class Response:
            returncode = 1
            stdout = '{"status":"error","error":"PRIVATE_TOKEN_DO_NOT_PRINT"}'
        with patch.object(deploy.subprocess, 'run', return_value=Response()):
            with self.assertRaises(RuntimeError) as caught:
                deploy.firebase(['projects:list'], {})
            self.assertNotIn('PRIVATE_TOKEN', str(caught.exception))


if __name__ == '__main__':
    unittest.main()
