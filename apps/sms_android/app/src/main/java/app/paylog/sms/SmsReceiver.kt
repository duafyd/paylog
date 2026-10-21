package app.paylog.sms
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.time.Instant

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val result = goAsync()
        Thread {
            try {
                val store = SecureStore(context)
                val config = store.config()
                if (!config.optBoolean("enabled")) return@Thread
                val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (parts.isEmpty()) return@Thread
                val sender = parts.first().originatingAddress.orEmpty().replace(Regex("[\\s()-]"), "")
                val allowed = config.optString("senders").split(',').map { it.trim().replace(Regex("[\\s()-]"), "") }.filter { it.isNotEmpty() }
                if (!allowed.contains(sender) || parts.any { it.originatingAddress?.replace(Regex("[\\s()-]"), "") != sender }) return@Thread
                val body = parts.joinToString("") { it.messageBody.orEmpty() }
                if (body.isEmpty() || body.length > 4096) return@Thread
                val messageId = SmsIdentity.of(sender, parts.map { it.timestampMillis to it.messageBody.orEmpty() })
                val payload = org.json.JSONObject().put("action","sms.ingest").put("messageId",messageId).put("sender",sender).put("body",body).put("receivedAt",Instant.now().toString())
                val id = store.enqueue(payload)
                UploadWorker.schedule(context,id)
            } catch (_: Exception) {
                // Do not log SMS, tokens, or exception bodies.
                context.getSharedPreferences("status",0).edit().putString("last","수신 저장 실패 · 저장공간/키 상태를 확인하세요").apply()
            } finally { result.finish() }
        }.start()
    }
}
