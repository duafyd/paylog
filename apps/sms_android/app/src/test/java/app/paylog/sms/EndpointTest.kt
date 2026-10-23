package app.paylog.sms
import org.junit.Assert.*
import org.junit.Test
class EndpointTest {
    @Test fun restrictEndpointAndRedirects() {
        assertTrue(Endpoint.valid("https://script.google.com/macros/s/test-deployment/exec"))
        for (url in listOf("http://script.google.com/macros/s/x/exec", "https://evil.example/macros/s/x/exec", "https://script.google.com.evil.example/macros/s/x/exec", "https://user@script.google.com/macros/s/x/exec", "https://script.google.com/macros/s/x/exec?token=secret", "https://script.google.com:8443/macros/s/x/exec")) assertFalse(url, Endpoint.valid(url))
        assertTrue(Endpoint.redirect("https://script.googleusercontent.com/macros/echo?user_content_key=test"))
        assertFalse(Endpoint.redirect("https://evil.example/"))
        assertFalse(Endpoint.redirect("http://script.googleusercontent.com/"))
    }
}
