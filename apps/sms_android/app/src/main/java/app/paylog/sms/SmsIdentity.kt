package app.paylog.sms

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.security.MessageDigest

/** Same SMS broadcast yields the same ID; queue/network retry time is excluded. */
object SmsIdentity {
    fun of(sender: String, parts: List<Pair<Long, String>>): String {
        require(parts.isNotEmpty() && parts.all { it.first > 0 })
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { out ->
            out.writeUTF("paylog-sms-v1")
            out.writeUTF(sender)
            out.writeInt(parts.size)
            for ((timestamp, body) in parts) {
                out.writeLong(timestamp)
                val text = body.toByteArray(Charsets.UTF_8)
                out.writeInt(text.size)
                out.write(text)
            }
        }
        return MessageDigest.getInstance("SHA-256").digest(bytes.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }
}
