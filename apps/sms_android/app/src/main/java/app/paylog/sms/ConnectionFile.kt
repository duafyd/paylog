package app.paylog.sms

import org.json.JSONObject

object ConnectionFile {
    const val MAX_BYTES = 16384
    fun parse(text: String): JSONObject {
        require(text.toByteArray(Charsets.UTF_8).size <= MAX_BYTES)
        val value = JSONObject(text)
        require(value.getString("format") == "paylog-android-connection")
        if (value.getInt("version") == 2) {
            require(FirestoreCapture.valid(value))
            val senders = value.getString("senders").split(',').map { it.trim() }.distinct()
            require(senders.size in 1..10 && senders.all { it.matches(Regex("\\+?[0-9]{3,20}")) })
            val config = JSONObject()
            for (key in listOf("backend", "projectId", "apiKey", "householdId", "deviceId", "email", "password", "platform")) config.put(key, value.getString(key))
            return config.put("senders",senders.joinToString(",")).put("enabled",false)
        }
        require(value.getInt("version") == 1)
        val endpoint = value.getString("endpoint")
        val device = value.getString("deviceId")
        val token = value.getString("token")
        val senders = value.getString("senders").split(',').map { it.trim() }
        require(Endpoint.valid(endpoint))
        require(device.matches(Regex("[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}")))
        require(token.matches(Regex("[a-f0-9]{64}")))
        require(senders.size in 1..50 && senders.all { it.matches(Regex("\\+?[0-9]{3,20}")) })
        return JSONObject().put("endpoint", endpoint).put("deviceId", device)
            .put("token", token).put("senders", senders.distinct().joinToString(","))
            .put("enabled", false)
    }
}
