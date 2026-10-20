package app.paylog.sms

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SecureStore(private val context: Context) {
    private val root = File(context.noBackupFilesDir, "sms-queue").apply { mkdirs() }
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "paylog.sms.v1"
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun write(id: String, value: JSONObject) {
        require(id.matches(Regex("[a-zA-Z0-9-]{1,80}")))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val bytes = cipher.iv + cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        val tmp = File(root, "$id.tmp")
        tmp.outputStream().use { it.write(bytes) }
        check(tmp.renameTo(File(root, id)))
    }
    @Synchronized fun read(id: String): JSONObject? {
        val file = File(root, id)
        if (!file.exists()) return null
        val bytes = file.readBytes()
        require(bytes.size >= 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0,12))) }
        return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)), Charsets.UTF_8))
    }
    fun config(): JSONObject = read("config") ?: JSONObject()
    fun pending(): List<String> = root.listFiles().orEmpty().filter { it.name != "config" && !it.name.endsWith(".tmp") }.map { it.name }
    fun delete(id: String) { File(root,id).delete() }
    fun enqueue(payload: JSONObject): String {
        require(pending().size < 100)
        val id = UUID.randomUUID().toString()
        payload.put("messageId",id).put("queuedAt", System.currentTimeMillis())
        write(id,payload); return id
    }
}
