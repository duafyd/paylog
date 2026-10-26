package app.paylog.sms

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** Capture-only Firebase account: never stores the human's login credentials. */
object FirestoreCapture {
    const val PROJECT = "paylog-c5c2d"
    const val API_KEY = "AIzaSyD4buMldb4jQebj_schvKwxEeKinR4OmwY"
    class Failure(val permanent: Boolean) : Exception()
    fun valid(config: JSONObject): Boolean = runCatching {
        require(config.getString("backend") == "firestore")
        require(config.getString("projectId") == PROJECT && config.getString("apiKey") == API_KEY)
        require(config.getString("householdId").matches(Regex("[A-Za-z0-9]{20}")))
        require(config.getString("deviceId").matches(Regex("[A-Za-z0-9_-]{1,128}")))
        require(config.getString("email").matches(Regex("device_[a-f0-9]{32}@devices\\.paylog\\.invalid")))
        require(config.getString("password").matches(Regex("[a-f0-9]{64}")))
        require(config.getString("platform") == "android")
    }.isSuccess
    fun eligible(body: String): Boolean = body.length in 1..4096 &&
        Regex("하나[0-9*]{4,12}").containsMatchIn(body) &&
        (body.contains("승인") || body.contains("취소")) &&
        !body.contains("인증번호") && !body.contains("비밀번호") && !body.contains("OTP", ignoreCase = true)
    fun hash(body: String): String = MessageDigest.getInstance("SHA-256")
        .digest(body.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    private fun string(value: String) = JSONObject().put("stringValue", value)
    fun fields(config: JSONObject, payload: JSONObject): JSONObject {
        val body = payload.getString("body")
        require(eligible(body))
        val id = payload.getString("messageId")
        require(id.matches(Regex("[a-f0-9]{64}")))
        val sender = payload.getString("sender")
        require(config.getString("senders").split(',').contains(sender))
        return JSONObject().put("deviceId", string(config.getString("deviceId")))
            .put("messageId", string(id)).put("sender", string(sender))
            .put("body", string(body)).put("bodyHash", string(hash(body)))
            .put("receivedAt", JSONObject().put("timestampValue", payload.getString("receivedAt")))
            .put("status", string("pending")).put("transactionId", string(""))
            .put("handledAt", JSONObject().put("nullValue", JSONObject.NULL))
    }
    fun commit(config: JSONObject, payload: JSONObject): JSONObject {
        val name = "projects/$PROJECT/databases/(default)/documents/households/${config.getString("householdId")}/smsInbox/${config.getString("deviceId")}_${payload.getString("messageId")}"
        return JSONObject().put("writes", JSONArray().put(JSONObject()
            .put("update", JSONObject().put("name", name).put("fields", fields(config,payload)))
            .put("currentDocument", JSONObject().put("exists", false))
            .put("updateTransforms", JSONArray().put(JSONObject().put("fieldPath", "createdAt").put("setToServerValue", "REQUEST_TIME")))))
    }
    private fun request(url: String, body: JSONObject?, token: String? = null): Pair<Int, JSONObject> {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 15000; connection.readTimeout = 20000
        try {
            connection.requestMethod = if (body == null) "GET" else "POST"
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            if (token != null) connection.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val bytes = stream?.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(1024)
                while (output.size() < 32769) {
                    val count = input.read(buffer,0,minOf(buffer.size,32769-output.size()))
                    if (count < 0) break
                    output.write(buffer,0,count)
                }
                output.toByteArray()
            } ?: byteArrayOf()
            if (bytes.size > 32768) throw Failure(false)
            return code to (runCatching { JSONObject(String(bytes, Charsets.UTF_8)) }.getOrNull() ?: JSONObject())
        } finally { connection.disconnect() }
    }
    fun upload(config: JSONObject, payload: JSONObject, save: (JSONObject) -> Unit) {
        if (!valid(config)) throw Failure(true)
        if (config.optString("idToken").isBlank() || config.optLong("expiresAt") <= System.currentTimeMillis()) {
            val (status, auth) = request("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$API_KEY",
                JSONObject().put("email", config.getString("email")).put("password",config.getString("password")).put("returnSecureToken",true))
            if (status != 200) throw Failure(status in 400..499 && status != 429)
            if (auth.optString("localId") != config.getString("deviceId") || auth.optString("email") != config.getString("email")) throw Failure(true)
            config.put("idToken", auth.getString("idToken")).put("expiresAt", System.currentTimeMillis() + 3300000L)
            save(config)
        }
        val token = config.getString("idToken")
        val base = "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/(default)/documents"
        val (status, response) = request("$base:commit", commit(config,payload), token)
        if (status == 200) return
        if (status == 401) { config.remove("idToken"); config.remove("expiresAt"); save(config); throw Failure(false) }
        val error = response.optJSONObject("error")?.optString("status")
        if (status == 409 || error == "ALREADY_EXISTS" || error == "FAILED_PRECONDITION") {
            val (code, previous) = request("$base/households/${config.getString("householdId")}/smsInbox/${config.getString("deviceId")}_${payload.getString("messageId")}", null, token)
            val fields = previous.optJSONObject("fields")
            if (code == 200 && fields?.optJSONObject("bodyHash")?.optString("stringValue") == hash(payload.getString("body")) &&
                fields.optJSONObject("deviceId")?.optString("stringValue") == config.getString("deviceId") &&
                fields.optJSONObject("messageId")?.optString("stringValue") == payload.getString("messageId") &&
                fields.optJSONObject("sender")?.optString("stringValue") == payload.getString("sender")) return
            throw Failure(code != 429 && code < 500)
        }
        throw Failure(status in 400..499 && status != 429)
    }
}
