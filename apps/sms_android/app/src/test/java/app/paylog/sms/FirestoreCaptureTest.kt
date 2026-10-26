package app.paylog.sms
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
class FirestoreCaptureTest {
    private fun config() = JSONObject().put("format","paylog-android-connection").put("version",2)
        .put("backend","firestore").put("projectId",FirestoreCapture.PROJECT).put("apiKey",FirestoreCapture.API_KEY)
        .put("householdId","a".repeat(20)).put("deviceId","captureAccount")
        .put("email","device_${"a".repeat(32)}@devices.paylog.invalid").put("password","b".repeat(64))
        .put("platform","android").put("senders","18001111")
    private fun payload() = JSONObject().put("messageId","a".repeat(64)).put("sender","18001111")
        .put("body","하나1234승인\n12,000원\n10/26 12:00 테스트 가게").put("receivedAt","2026-10-26T03:00:00Z")
    @Test fun importsCaptureOnlyCredentialsAndDiscardsInjectedTokensAndEnableFlag() {
        val imported=ConnectionFile.parse(config().put("enabled",true).put("idToken","injected").put("expiresAt",Long.MAX_VALUE).toString())
        assertTrue(FirestoreCapture.valid(imported));assertFalse(imported.getBoolean("enabled"));assertFalse(imported.has("idToken"))
        for ((key,value) in listOf("projectId" to "evil-project", "apiKey" to "other-key", "platform" to "ios", "senders" to "*", "email" to "owner@accounts.paylog.invalid", "password" to "short")) {
            assertTrue(runCatching { ConnectionFile.parse(config().put(key,value).toString()) }.isFailure)
        }
    }
    @Test fun commitUsesCreatePreconditionAndServerTimeWithNoAuthenticationSecrets() {
        val commit=FirestoreCapture.commit(config(),payload())
        val write=commit.getJSONArray("writes").getJSONObject(0)
        assertFalse(write.getJSONObject("currentDocument").getBoolean("exists"))
        assertEquals("REQUEST_TIME",write.getJSONArray("updateTransforms").getJSONObject(0).getString("setToServerValue"))
        assertTrue(write.getJSONObject("update").getString("name").endsWith("captureAccount_${"a".repeat(64)}"))
        assertFalse(commit.toString().contains("password"));assertFalse(commit.toString().contains("idToken"))
        assertEquals(64,write.getJSONObject("update").getJSONObject("fields").getJSONObject("bodyHash").getString("stringValue").length)
    }
    @Test fun excludesOtpUnrelatedMessagesAndUnregisteredSenders() {
        assertFalse(FirestoreCapture.eligible("하나1234승인 인증번호 123456"))
        assertFalse(FirestoreCapture.eligible("하나1234승인 OTP 123456"))
        assertFalse(FirestoreCapture.eligible("로그인 알림"))
        assertTrue(runCatching { FirestoreCapture.commit(config(),payload().put("sender","unregistered")) }.isFailure)
    }
}
