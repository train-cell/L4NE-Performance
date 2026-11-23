package com.l4ne.training.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.l4ne.training.core.L4NECoreNative

// L4NE Performance Brand Colors (Carbon Black + Electric Lime #CCFF00)
val L4NEBackground = Color(0xFF0A0C0E)
val L4NECardSurface = Color(0xFF12161B)
val L4NEBorder = Color(0xFF262E38)
val L4NEElectricLime = Color(0xFFCCFF00)
val L4NESignalGreen = Color(0xFF22C55E)
val L4NETextPrimary = Color(0xFFF8FAFC)
val L4NETextSecondary = Color(0xFF94A3B8)

@Composable
fun L4NEAndroidRootScreen(databasePath: String) {
    var statsJson by remember { mutableStateOf("") }
    var numpadPreview by remember { mutableStateOf("") }

    LaunchedEffect(databasePath) {
        L4NECoreNative.initDatabaseJson(databasePath, true)
        statsJson = L4NECoreNative.executeJson(databasePath, """{"action":"database_stats"}""")
        numpadPreview = L4NECoreNative.executeJson(databasePath, """{"action":"parse_numpad","digits":"1820"}""")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(L4NEBackground)
            .padding(16.dp)
    ) {
        // Stylized L4NE Wordmark
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("L", color = L4NETextPrimary, fontSize = 24.sp, fontWeight = FontWeight.Black)
            Text("4", color = L4NEElectricLime, fontSize = 24.sp, fontWeight = FontWeight.Black)
            Text("NE TRAINING · v1.1", color = L4NETextPrimary, fontSize = 24.sp, fontWeight = FontWeight.Black)
        }
        Text(
            "LOCAL-FIRST · 100% DETERMINISTIC · RUST CORE + JETPACK COMPOSE",
            color = L4NETextSecondary,
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace
        )

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(L4NECardSurface, RoundedCornerShape(12.dp))
                        .border(1.dp, L4NEBorder, RoundedCornerShape(12.dp))
                        .padding(14.dp)
                ) {
                    Text(
                        "RUST CORE ENGINE DIAGNOSTICS (JNI)",
                        color = L4NEElectricLime,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(statsJson, color = L4NETextPrimary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                }
            }

            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(L4NECardSurface, RoundedCornerShape(12.dp))
                        .border(1.dp, L4NEBorder, RoundedCornerShape(12.dp))
                        .padding(14.dp)
                ) {
                    Text(
                        "ATHLETIC CENTISECOND NUMPAD + LIVE TIMER ENGINE",
                        color = L4NESignalGreen,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(numpadPreview, color = L4NETextPrimary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}
