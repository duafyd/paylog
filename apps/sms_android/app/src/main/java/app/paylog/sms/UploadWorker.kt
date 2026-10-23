package app.paylog.sms
import android.content.Context
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class UploadWorker(context: Context, params: WorkerParameters) : Worker(context,params) {
    override fun doWork(): Result {
        val id = inputData.getString("queueId") ?: return Result.failure()
        val store = SecureStore(applicationContext)
        try {
            val config = store.config()
            if (!config.optBoolean("enabled")) return Result.success()
            val payload = store.read(id) ?: return Result.success()
            if (System.currentTimeMillis() - payload.optLong("queuedAt") > TimeUnit.DAYS.toMillis(7)) {
                store.delete(id); status("7일 보관기한 만료 · 수동 등록 필요"); return Result.failure()
            }
            val endpoint = config.optString("endpoint")
            if (!Endpoint.valid(endpoint)) { status("GAS 주소 설정 필요"); return Result.failure() }
            payload.remove("queuedAt")
            payload.put("deviceId",config.optString("deviceId")).put("ingestToken",config.optString("token"))
            var connection = URL(endpoint).openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15000; connection.readTimeout = 20000
            connection.requestMethod = "POST"; connection.doOutput = true
            connection.setRequestProperty("Content-Type","application/json; charset=utf-8")
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code in 300..399) {
                val redirect = connection.getHeaderField("Location") ?: return Result.retry()
                connection.disconnect()
                if (!Endpoint.redirect(redirect)) { status("허용하지 않은 리다이렉트"); return Result.failure() }
                // GAS ContentService redirects are GET-only; never resend credentials.
                connection = URL(redirect).openConnection() as HttpURLConnection
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 15000; connection.readTimeout = 20000
            }
            try {
                if (connection.responseCode !in 200..299) return Result.retry()
                val text = connection.inputStream.bufferedReader().use { reader ->
                    val buffer = CharArray(4097)
                    var count = 0
                    while (count < buffer.size) {
                        val got = reader.read(buffer,count,buffer.size-count)
                        if (got < 0) break
                        count += got
                    }
                    String(buffer,0,count)
                }
                if (text.length > 4096) return Result.retry()
                val response = JSONObject(text)
                when (response.optString("code")) {
                    "CREATED", "DUPLICATE", "IGNORED_CARD", "REVIEW_REQUIRED" -> {
                        if (!response.optBoolean("ok")) return Result.retry()
                        store.delete(id); status("전송 확인 · ${response.optString("code")}"); return Result.success()
                    }
                    "UNAUTHORIZED", "INVALID_FORMAT" -> { status("인증/형식 오류 · 설정 수정 후 재시도"); return Result.failure() }
                    else -> return Result.retry()
                }
            } finally { connection.disconnect() }
        } catch (_: Exception) { status("전송 대기 · 네트워크 재시도"); return Result.retry() }
    }
    private fun status(value: String) { applicationContext.getSharedPreferences("status",0).edit().putString("last",value).apply() }
    companion object {
        fun schedule(context: Context, id: String) {
            val work = OneTimeWorkRequestBuilder<UploadWorker>().setInputData(workDataOf("queueId" to id))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
            WorkManager.getInstance(context).enqueueUniqueWork("sms-$id", ExistingWorkPolicy.KEEP,work)
        }
    }
}
