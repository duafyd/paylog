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
        layout.addView(Button(this).apply { text = "사용 방법 보기"; setOnClickListener {
            android.app.AlertDialog.Builder(this@MainActivity).setTitle("Android 문자 수집 사용 방법").setMessage(
                "1. 먼저 소유자가 GAS 수집 서버와 카드·기기 등록을 준비합니다.\n\n" +
                "2. GAS /exec 주소, 기기 UUID, 원본 토큰, 실제 허용 발신번호를 입력합니다. 토큰은 채팅이나 스크린샷으로 공유하지 마세요.\n\n" +
                "3. 문자 수집 사용을 켜고 설정을 저장한 뒤 SMS 수신 권한을 허용합니다. 이후 수신한 허용 발신자의 SMS만 처리하며 기존 문자는 읽지 않습니다.\n\n" +
                "4. 전송 상태와 웹 가계부의 달력·검토함을 확인합니다. 전송이 밀리면 네트워크·배터리 제한을 확인하고 대기 전송 재시도를 누릅니다. 즉시 전송은 보장되지 않습니다.\n\n" +
                "5. 앱 삭제 시 설정과 대기 문자가 사라집니다. 기기 분실 시 웹 관리에서 기기를 비활성화하세요.\n\n" +
                "iPhone과 홈 화면 설치 안내는 paylog 웹앱 → 설정 → Android · iPhone 사용 가이드에서 볼 수 있습니다. 실제 SMS 수신은 아직 실기기 검증 전입니다."
            ).setPositiveButton("확인", null).show()
        } })
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
