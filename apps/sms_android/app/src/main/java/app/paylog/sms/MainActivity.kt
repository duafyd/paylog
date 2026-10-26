package app.paylog.sms

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import android.widget.*
import android.text.InputType
import org.json.JSONObject

class MainActivity : Activity() {
    private fun toast(text: String) = Toast.makeText(this, text, Toast.LENGTH_LONG).show()

    @Deprecated("Platform document picker supports API 26")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 20 || resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        val store = SecureStore(this)
        val candidate = runCatching {
            val bytes = contentResolver.openInputStream(uri)!!.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(1024)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= ConnectionFile.MAX_BYTES)
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            ConnectionFile.parse(String(bytes, Charsets.UTF_8))
        }.getOrElse { toast("올바른 Paylog 연결 파일이 아니에요. 웹에서 다시 만들어 주세요"); return }
        AlertDialog.Builder(this).setTitle("이 휴대폰을 연결할까요?")
            .setMessage("기존 연결이 있다면 교체돼요. 본인 가계부에서 만든 파일인지 확인해 주세요. 연결 후 다운로드한 파일은 삭제해 주세요.")
            .setNegativeButton("취소", null).setPositiveButton("연결") { _, _ ->
                runCatching {
                    check(store.pending().isEmpty())
                    store.write("config", candidate)
                }.onSuccess { toast("연결 설정 완료 · 문자 권한을 허용해 주세요"); recreate() }
                    .onFailure { toast("대기 문자를 먼저 전송하거나 삭제한 뒤 연결해 주세요") }
            }.show()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1) return
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            toast("문자 권한을 허용해야 자동 수집할 수 있어요"); return
        }
        val store = SecureStore(this)
        runCatching {
            val config = store.config()
            check(FirestoreCapture.valid(config) || (Endpoint.valid(config.optString("endpoint")) && config.optString("token").length >= 32))
            store.write("config", config.put("enabled", true))
        }.onSuccess { toast("문자 자동 수집을 시작했어요"); recreate() }
            .onFailure { toast("연결 파일을 먼저 선택해 주세요") }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        val store = SecureStore(this)
        val config = runCatching { store.config() }.getOrDefault(JSONObject())
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32,48,32,32) }
        fun label(text: String) { layout.addView(TextView(this).apply { this.text = text; textSize = 16f; setPadding(0,12,0,12) }) }
        fun button(text: String, action: () -> Unit) {
            layout.addView(Button(this).apply { this.text = text; setOnClickListener { action() } })
        }
        label("paylog 문자 자동 기록")
        label(if (config.optBoolean("enabled") && checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED)
            "자동 수집 켜짐 · 등록한 발신자의 새 문자만 처리해요" else "연결 파일을 선택하고 문자 권한을 허용하면 준비가 끝나요")
        label("웹 가계부 → 설정 → 문자 자동 기록 · 기기 연결에서 Android 연결 파일을 만드세요. 기존 Sheets 연결 파일도 계속 사용할 수 있어요.")
        button("웹 가계부 열기") {
            runCatching { startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://paylog-c5c2d.web.app"))) }
                .onFailure { toast("브라우저에서 paylog-c5c2d.web.app을 열어 주세요") }
        }
        button("1. 연결 파일 선택") {
            runCatching { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE); type = "*/*"
            }, 20) }.onFailure { toast("파일 앱을 열 수 없어요") }
        }
        button("2. 문자 권한 허용하고 시작") {
            if (!FirestoreCapture.valid(config) && (!Endpoint.valid(config.optString("endpoint")) || config.optString("token").length < 32)) {
                toast("연결 파일을 먼저 선택해 주세요")
            } else requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), 1)
        }
        if (config.optBoolean("enabled")) button("문자 수집 끄기") {
            runCatching { store.write("config", config.put("enabled", false)) }
                .onSuccess { recreate() }.onFailure { toast("설정을 저장하지 못했어요") }
        }
        label("연결 파일에는 비밀 연결 키가 들어 있어요. 연결 후 파일을 삭제하고, 다른 사람에게 공유하지 마세요. 기존 문자는 읽지 않아요.")
        val advanced = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; visibility = View.GONE }
        button("수동 설정 · 고급") { advanced.visibility = if (advanced.visibility == View.VISIBLE) View.GONE else View.VISIBLE }
        layout.addView(advanced)
        fun field(hint: String, key: String, secret: Boolean = false): EditText {
            return EditText(this).apply {
                this.hint = hint; setText(config.optString(key)); isSaveEnabled = false
                if (secret) inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                advanced.addView(this)
            }
        }
        val endpoint = field("GAS /exec HTTPS 주소", "endpoint")
        val device = field("기기 UUID", "deviceId")
        val token = field("기기 전송 토큰", "token", true)
        val senders = field("허용 발신번호 (쉼표 구분)", "senders")
        advanced.addView(Button(this).apply { text = "수동 설정 저장"; setOnClickListener {
            if (!Endpoint.valid(endpoint.text.toString()) || !device.text.toString().matches(Regex("[a-fA-F0-9-]{36}")) || token.text.length !in 32..256 || senders.text.isBlank()) {
                toast("주소·기기 ID·토큰·발신번호를 확인하세요"); return@setOnClickListener
            }
            if (store.pending().isNotEmpty()) { toast("대기 문자를 먼저 전송하거나 삭제해 주세요"); return@setOnClickListener }
            runCatching { store.write("config", JSONObject().put("endpoint",endpoint.text.toString()).put("deviceId",device.text.toString()).put("token",token.text.toString()).put("senders",senders.text.toString()).put("enabled",false)) }
                .onSuccess { toast("저장 완료 · 문자 권한을 허용하고 시작해 주세요"); recreate() }.onFailure { toast("저장 실패") }
        } })
        button("대기 전송 재시도") { store.pending().forEach { UploadWorker.schedule(this,it) }; toast("대기 항목 재시도 예약") }
        button("대기 문자 삭제") {
            AlertDialog.Builder(this).setMessage("미전송 문자를 모두 삭제할까요?").setNegativeButton("취소",null)
                .setPositiveButton("삭제") { _,_ -> store.pending().forEach { store.delete(it) }; recreate() }.show()
        }
        label(getSharedPreferences("status",0).getString("last","아직 전송 기록 없음") ?: "")
        label("대기 ${store.pending().size}건 · 7일 보관\n백그라운드 즉시 전송은 보장되지 않습니다.")
        val scroll = ScrollView(this).apply { addView(layout) }
        scroll.setOnApplyWindowInsetsListener { _, insets ->
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(android.view.WindowInsets.Type.systemBars())
                layout.setPadding(32,bars.top+24,32,bars.bottom+24)
            } else {
                @Suppress("DEPRECATION")
                layout.setPadding(32,insets.systemWindowInsetTop+24,32,insets.systemWindowInsetBottom+24)
            }
            insets
        }
        setContentView(scroll)
    }
}
