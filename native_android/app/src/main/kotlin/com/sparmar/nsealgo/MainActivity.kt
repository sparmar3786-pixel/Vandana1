package com.sparmar.nsealgo

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.text.InputType
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {
    private val prefs by lazy { getSharedPreferences("nse_native", Context.MODE_PRIVATE) }
    private val http = OkHttpClient.Builder().connectTimeout(10, TimeUnit.SECONDS).readTimeout(20, TimeUnit.SECONDS).build()
    private var socket: WebSocket? = null
    private lateinit var status: TextView
    private lateinit var backend: EditText
    private lateinit var appToken: EditText
    private lateinit var clientId: EditText
    private lateinit var pin: EditText
    private lateinit var totp: EditText
    private lateinit var apiKey: EditText
    private lateinit var snapshot: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        health()
    }

    private fun buildUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 20, 24, 20)
            setBackgroundColor(Color.rgb(9, 15, 29))
        }
        val scroll = ScrollView(this)
        val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(label("NSE ALGO • NATIVE LIVE TERMINAL", 22))
        content.addView(label("Kotlin Android • read-only • no order placement", 13))
        status = label("Backend: checking...", 15)
        content.addView(status)

        backend = field("Backend URL", prefs.getString("backend", "https://vandana1-angel-api.onrender.com") ?: "")
        appToken = field("Terminal App Token (optional)", prefs.getString("appToken", "") ?: "")
        content.addView(backend)
        content.addView(appToken)

        content.addView(label("ANGEL ONE SMARTAPI", 18))
        clientId = field("Client ID", prefs.getString("clientId", "") ?: "")
        pin = field("MPIN", "", true)
        totp = field("Current 6-digit TOTP", "", false, InputType.TYPE_CLASS_NUMBER)
        apiKey = field("SmartAPI API Key", "", true)
        content.addView(clientId); content.addView(pin); content.addView(totp); content.addView(apiKey)

        content.addView(Button(this).apply { text = "CONNECT ANGEL ONE LIVE"; setOnClickListener { saveAndConnect() } })
        content.addView(Button(this).apply { text = "REFRESH STATUS"; setOnClickListener { health() } })
        snapshot = label("Waiting for live terminal snapshot...", 13)
        content.addView(snapshot)
        content.addView(label("Security: Angel credentials are sent only to your configured HTTPS backend. The APK never calls Angel directly. API orders are not implemented.", 12))

        scroll.addView(content)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
    }

    private fun label(text: String, size: Int): TextView = TextView(this).apply {
        this.text = text
        textSize = size.toFloat()
        setTextColor(Color.WHITE)
        setPadding(0, 10, 0, 10)
    }

    private fun field(hint: String, value: String, password: Boolean = false, type: Int = InputType.TYPE_CLASS_TEXT): EditText = EditText(this).apply {
        this.hint = hint
        setText(value)
        setTextColor(Color.WHITE)
        setHintTextColor(Color.LTGRAY)
        inputType = if (password) type or InputType.TYPE_TEXT_VARIATION_PASSWORD else type
        setPadding(12, 10, 12, 10)
    }

    private fun baseUrl(): String = backend.text.toString().trim().trimEnd('/')

    private fun headers(): Headers {
        val token = appToken.text.toString().trim()
        return Headers.Builder().apply { if (token.isNotEmpty()) add("x-app-key", token) }.build()
    }

    private fun saveAndConnect() {
        prefs.edit().putString("backend", baseUrl()).putString("appToken", appToken.text.toString().trim()).putString("clientId", clientId.text.toString().trim()).apply()
        val body = JSONObject().put("clientId", clientId.text.toString().trim()).put("pin", pin.text.toString().trim()).put("totp", totp.text.toString().trim()).put("apiKey", apiKey.text.toString().trim()).toString()
        status.text = "Backend: connecting to Angel One..."
        val req = Request.Builder().url(baseUrl() + "/v1/angel/login").headers(headers()).post(body.toRequestBody("application/json".toMediaType())).build()
        http.newCall(req).enqueue(object : Callback {
            override fun onFailure(call: Call, ex: java.io.IOException) { runOnUiThread { status.text = "Backend: connection failed • " + (ex.message ?: "network error") } }
            override fun onResponse(call: Call, response: Response) {
                val raw = response.body?.string().orEmpty()
                runOnUiThread {
                    val json = runCatching { JSONObject(raw) }.getOrNull()
                    if (response.isSuccessful) {
                        status.text = "Backend: CONNECTED • Angel One: CONNECTED"
                        openSocket()
                    } else {
                        val detail = json?.optJSONObject("detail")
                        val msg = detail?.optString("message") ?: json?.optString("detail") ?: ("HTTP " + response.code)
                        status.text = "Angel: REJECTED • " + msg
                    }
                }
            }
        })
    }

    private fun health() {
        val req = Request.Builder().url(baseUrl() + "/health").headers(headers()).get().build()
        http.newCall(req).enqueue(object : Callback {
            override fun onFailure(call: Call, ex: java.io.IOException) { runOnUiThread { status.text = "Backend: NOT CONNECTED • " + (ex.message ?: "network error") } }
            override fun onResponse(call: Call, response: Response) {
                val raw = response.body?.string().orEmpty()
                runOnUiThread {
                    if (!response.isSuccessful) status.text = "Backend: HTTP " + response.code
                    else {
                        val j = runCatching { JSONObject(raw) }.getOrNull()
                        val angel = j?.optBoolean("angel_connected", false) == true
                        status.text = if (angel) "Backend: CONNECTED • Angel One: CONNECTED" else "Backend: CONNECTED • Angel One: NOT CONNECTED"
                        if (angel) openSocket()
                    }
                }
            }
        })
    }

    private fun openSocket() {
        socket?.close(1000, "reconnect")
        val scheme = if (baseUrl().startsWith("https://")) "wss://" else "ws://"
        val host = baseUrl().removePrefix("https://").removePrefix("http://")
        val token = appToken.text.toString().trim()
        val encoded = java.net.URLEncoder.encode(token, "UTF-8")
        val url = scheme + host + "/v1/ws" + if (token.isNotEmpty()) "?token=" + encoded else ""
        socket = http.newWebSocket(Request.Builder().url(url).build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) { runOnUiThread { status.text = "Backend: CONNECTED • Market stream: LIVE" } }
            override fun onMessage(webSocket: WebSocket, text: String) {
                runOnUiThread {
                    val j = runCatching { JSONObject(text) }.getOrNull()
                    val conn = j?.optJSONObject("connection")
                    val angel = conn?.optBoolean("angel", false) == true
                    val spot = j?.optJSONObject("market")?.opt("spot") ?: "--"
                    val state = j?.optJSONObject("engine_state")?.optString("trend", "--") ?: "--"
                    snapshot.text = "LIVE • Angel=" + angel + " • NIFTY=" + spot + " • Trend=" + state
                }
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                runOnUiThread { status.text = "Backend: connected • Market stream: reconnecting..." }
                webSocket.close(1000, null)
            }
        })
    }

    override fun onDestroy() {
        socket?.close(1000, "activity closed")
        http.dispatcher.executorService.shutdown()
        super.onDestroy()
    }
}
