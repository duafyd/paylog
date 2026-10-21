package app.paylog.sms

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class ConnectionFileTest {
    private fun fixture() = JSONObject().put("format", "paylog-android-connection").put("version", 1)
        .put("endpoint", "https://script.google.com/macros/s/test/exec")
        .put("deviceId", "11111111-1111-4111-8111-111111111111")
        .put("token", "a".repeat(64)).put("senders", "15880000,15880000,+821012345678")
    @Test fun importsOnlyValidatedFieldsAndRequiresExplicitEnable() {
        val value = ConnectionFile.parse(fixture().put("enabled", true).put("arbitrary", "value").toString())
        assertFalse(value.getBoolean("enabled"))
        assertFalse(value.has("arbitrary"))
        assertEquals("15880000,+821012345678", value.getString("senders"))
    }
    @Test fun rejectsHostSpoofingMalformedCredentialsAndWildcardSenders() {
        for ((key, value) in listOf(
            "endpoint" to "https://script.google.com.evil.example/macros/s/test/exec",
            "endpoint" to "https://script.google.com/macros/s/test/exec?token=x",
            "deviceId" to "-".repeat(36), "token" to "short", "senders" to "*",
            "senders" to "", "format" to "other", "version" to 2
        )) {
            assertTrue("must reject $key", runCatching { ConnectionFile.parse(fixture().put(key, value).toString()) }.isFailure)
        }
    }
    @Test fun rejectsOversizedAndNonJsonFiles() {
        assertTrue(runCatching { ConnectionFile.parse("x".repeat(ConnectionFile.MAX_BYTES + 1)) }.isFailure)
        assertTrue(runCatching { ConnectionFile.parse("<html>Not a connection file</html>") }.isFailure)
    }
}
