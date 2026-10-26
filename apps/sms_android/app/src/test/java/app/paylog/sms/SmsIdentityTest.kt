package app.paylog.sms

import org.junit.Assert.*
import org.junit.Test

class SmsIdentityTest {
    @Test(expected = IllegalArgumentException::class) fun missingOriginalTimestampIsNotCollapsedIntoAnIdentity() {
        SmsIdentity.of("15880000", listOf(0L to "승인 12000"))
    }
    @Test fun redeliveryKeepsIdentityAndDoesNotExposeMessage() {
        val text = "하나카드 승인 12,000원 테스트가맹점"
        val parts = listOf(1700000000000L to text)
        val id = SmsIdentity.of("15880000", parts)
        assertEquals(id, SmsIdentity.of("15880000", parts.toList()))
        assertTrue(id.matches(Regex("[a-f0-9]{64}")))
        assertFalse(id.contains(text))
    }
    @Test fun separateIdenticalPaymentsAndCancellationsRemainDistinct() {
        val first = SmsIdentity.of("15880000", listOf(1000L to "승인 12000"))
        assertNotEquals(first, SmsIdentity.of("15880000", listOf(1001L to "승인 12000")))
        assertNotEquals(first, SmsIdentity.of("15880000", listOf(1000L to "취소 12000")))
        assertNotEquals(first, SmsIdentity.of("15889999", listOf(1000L to "승인 12000")))
    }
    @Test fun multipartBoundariesAreUnambiguous() {
        val parts = listOf(1000L to "ab", 1000L to "c")
        assertEquals(SmsIdentity.of("1", parts), SmsIdentity.of("1", parts))
        assertNotEquals(SmsIdentity.of("1", parts), SmsIdentity.of("1", listOf(1000L to "a", 1000L to "bc")))
    }
}
