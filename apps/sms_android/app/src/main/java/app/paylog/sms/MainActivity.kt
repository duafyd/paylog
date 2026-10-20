package app.paylog.sms
import android.Manifest
import android.app.Activity
import android.os.Bundle
import android.text.InputType
import android.widget.*
import org.json.JSONObject

class MainActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val store = SecureStore(this)
        val config = runCatching { store.config() }.getOrDefault(JSONObject())
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32,48,32,32) }
        fun label(text: String) { layout.addView(TextView(this).apply { this.text = text; textSize = 16f }) }
        fun field(hint: String, key: String, secret: Boolean = false): EditText {
            val edit = EditText(this).apply { this.hint = hint; setText(config.optString(key)); if (secret) { inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD; isSaveEnabled = false } }
            layout.addView(edit); return edit
        }
        label("paylog 문자 수집\n허용 발신자의 새 SMS만 수집합니다. 기존 문자는 읽지 않습니다.")
        val endpoint = field("GAS /exec HTTPS 주소","endpoint")
        val device = field("기기 UUID","deviceId")
        val token = field("기기 전송 토큰","token",true)
        val senders = field("실제 허용 발신번호 (쉼표 구분)","senders")
        val enabled = Switch(this).apply { text = "문자 수집 사용"; isChecked = config.optBoolean("enabled") };layout.addView(enabled)
        fun toast(text: String) { Toast.makeText(this,text,Toast.LENGTH_LONG).show() }
        layout.addView(Button(this).apply { text = "설정 저장";setOnClickListener {
            if (!Endpoint.valid(endpoint.text.toString()) || !device.text.toString().matches(Regex("[a-fA-F0-9-]{36}")) || token.text.length < 32 || senders.text.isBlank()) { toast("주소·기기 ID·토큰·발신번호를 확인하세요");return@setOnClickListener }
            runCatching { store.write("config",JSONObject().put("endpoint",endpoint.text.toString()).put("deviceId",device.text.toString()).put("token",token.text.toString()).put("senders",senders.text.toString()).put("enabled",enabled.isChecked)) }.onSuccess { toast("암호화 저장 완료") }.onFailure { toast("저장 실패") }
        } })
        layout.addView(Button(this).apply { text = getString(R.string.request_sms_permission);setOnClickListener { requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS),1) } })
        layout.addView(Button(this).apply { text = "대기 전송 재시도";setOnClickListener { store.pending().forEach { UploadWorker.schedule(this@MainActivity,it) };toast("대기 항목 재시도 예약") } })
        layout.addView(Button(this).apply { text = "대기 문자 삭제";setOnClickListener { android.app.AlertDialog.Builder(this@MainActivity).setMessage("미전송 문자를 모두 삭제할까요?").setNegativeButton("취소",null).setPositiveButton("삭제") { _,_ -> store.pending().forEach { store.delete(it) };toast("삭제 완료") }.show() } })
        label(getSharedPreferences("status",0).getString("last","아직 전송 기록 없음") ?: "")
        label("대기 ${store.pending().size}건 · 7일 보관 · 민감정보 로그 없음\n백그라운드 즉시 전송은 보장되지 않습니다.")
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
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
