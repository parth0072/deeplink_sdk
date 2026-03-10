package com.deeplink.sample

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.deeplink.sdk.DeeplinkSDK
import kotlinx.coroutines.launch
import java.util.UUID

private val Purple = Color(0xFF6C63FF)
private val DarkBg = Color(0xFF1E1E1E)

data class LogEntry(val id: String = UUID.randomUUID().toString(), val text: String)

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Step 3: Handle App Link / intent ──────────────────────────────────
        DeeplinkSDK.handleIntent(intent) { link ->
            link?.let {
                android.util.Log.d("Deeplink", "Incoming link: ${it.uri}")
                android.util.Log.d("Deeplink", "  segments: ${it.pathSegments}")
                android.util.Log.d("Deeplink", "  params:   ${it.params}")
            }
        }

        setContent {
            MaterialTheme(
                colorScheme = MaterialTheme.colorScheme.copy(primary = Purple)
            ) {
                SampleScreen(
                    onCopyToClipboard = { text ->
                        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        cm.setPrimaryClip(ClipData.newPlainText("Deeplink URL", text))
                    }
                )
            }
        }
    }
}

@Composable
fun SampleScreen(onCopyToClipboard: (String) -> Unit) {
    val log = remember { mutableStateListOf(LogEntry(text = "SDK configured. Ready to test.")) }
    var createdUrl by remember { mutableStateOf("") }
    var isFetching by remember { mutableStateOf(false) }
    var isCreating by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    fun append(msg: String) {
        log.add(LogEntry(text = msg))
        scope.launch { listState.animateScrollToItem(log.size - 1) }
    }

    Column(Modifier.fillMaxSize()) {

        // ── Header ─────────────────────────────────────────────────────────
        Surface(color = Purple) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text("Deeplink SDK Sample", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
            }
        }

        Column(
            Modifier
                .weight(1f)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {

            // ── Deferred Deep Link ─────────────────────────────────────────
            SectionHeader("Deferred Deep Link")
            Card(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                ActionRow(Icons.Default.Wifi, if (isFetching) "Fetching…" else "Get Init Data (force)", !isFetching) {
                    append("Fetching init data…")
                    isFetching = true
                    DeeplinkSDK.getInitData(force = true) { data ->
                        isFetching = false
                        if (data != null) {
                            append("✅ Matched!")
                            append("   dest: ${data.destinationUrl}")
                            append("   androidUrl: ${data.androidUrl ?: "—"}")
                            append("   metadata: ${data.metadata}")
                        } else {
                            append("⚠️  No match (no click fingerprint found)")
                        }
                    }
                }
                HorizontalDivider()
                ActionRow(Icons.Default.Refresh, "Reset Init State") {
                    DeeplinkSDK.resetInitState()
                    append("🔄 Init state reset — next getInitData() will re-fetch")
                }
            }

            // ── Create Link ────────────────────────────────────────────────
            SectionHeader("Create Link")
            Card(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                ActionRow(Icons.Default.AddLink, if (isCreating) "Creating…" else "Create Deep Link", !isCreating) {
                    append("Creating link…")
                    isCreating = true
                    DeeplinkSDK.createLink(
                        destination = "https://yourapp.com/product/123",
                        params      = mapOf("product_id" to "123", "source" to "android-sample"),
                        iosUrl      = "myapp://product/123",
                        androidUrl  = "myapp://product/123",
                        title       = "Sample Product",
                        utmSource   = "sample",
                        utmMedium   = "android",
                        utmCampaign = "sdk-test",
                    ) { result ->
                        isCreating = false
                        if (result != null) {
                            createdUrl = result.url
                            append("✅ Link created: ${result.url}")
                            append("   alias: ${result.alias}")
                        } else {
                            append("❌ Error creating link")
                            append("   (Is the backend running and API key correct?)")
                        }
                    }
                }
                if (createdUrl.isNotEmpty()) {
                    HorizontalDivider()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onCopyToClipboard(createdUrl); append("📋 Copied to clipboard") }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.ContentCopy, null, tint = Purple, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            createdUrl,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                        )
                    }
                }
            }

            // ── Event Tracking ─────────────────────────────────────────────
            SectionHeader("Event Tracking")
            Card(Modifier.fillMaxWidth()) {
                ActionRow(Icons.Default.TouchApp, "Track: button_tapped") {
                    DeeplinkSDK.track("button_tapped", mapOf("screen" to "home", "button" to "cta"))
                    append("📊 Tracked: button_tapped {screen: home, button: cta}")
                }
                HorizontalDivider()
                ActionRow(Icons.Default.ShoppingCart, "Track: purchase") {
                    DeeplinkSDK.track("purchase", mapOf("amount" to 49.99, "currency" to "USD"))
                    append("📊 Tracked: purchase {amount: 49.99, currency: USD}")
                }
                HorizontalDivider()
                ActionRow(Icons.Default.PersonAdd, "Track: signup") {
                    DeeplinkSDK.track("signup", mapOf("method" to "email"))
                    append("📊 Tracked: signup {method: email}")
                }
            }
        }

        // ── Log ──────────────────────────────────────────────────────────────
        Divider()
        Column(
            Modifier
                .fillMaxWidth()
                .weight(0.55f)
                .background(DarkBg)
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("LOG", color = Color(0xFF86868B), fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.8.sp)
                Text("Clear", color = Color(0xFF555555), fontSize = 10.sp,
                    modifier = Modifier.clickable { log.clear() })
            }
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
                contentPadding = PaddingValues(bottom = 8.dp),
            ) {
                items(log, key = { it.id }) { entry ->
                    Text(
                        entry.text,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        lineHeight = 17.sp,
                        color = when {
                            entry.text.startsWith("❌") -> Color(0xFFFF3B30)
                            entry.text.startsWith("✅") -> Color(0xFF4CD964)
                            entry.text.startsWith("📊") -> Color(0xFF5AC8FA)
                            else -> Color(0xFF8E8E93)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title.uppercase(),
        color = Purple,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.6.sp,
        modifier = Modifier.padding(start = 4.dp, top = 12.dp, bottom = 4.dp),
    )
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = if (enabled) Purple else Color.Gray, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, color = if (enabled) MaterialTheme.colorScheme.onSurface else Color.Gray, fontSize = 14.sp)
    }
}
