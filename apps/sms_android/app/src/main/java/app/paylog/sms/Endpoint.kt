package app.paylog.sms
import java.net.URI
object Endpoint {
    fun valid(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme == "https" && uri.host == "script.google.com" && uri.port == -1 && uri.userInfo == null && uri.query == null && uri.fragment == null && Regex("/macros/s/[A-Za-z0-9_-]+/exec").matches(uri.path)
    }.getOrDefault(false)
    fun redirect(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme == "https" && uri.host == "script.googleusercontent.com" && uri.port == -1 && uri.userInfo == null
    }.getOrDefault(false)
}
