package com.l4ne.training.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.l4ne.training.core.L4NECoreNative

/**
 * Multi-Theme Palette for Android Jetpack Compose (matching iOS SwiftUI `L4NEPalette`).
 */
enum class L4NEAndroidTheme(
    val id: String,
    val title: String,
    val bgCanvas: Color,
    val surface1: Color,
    val surface2: Color,
    val borderTop: Color,
    val borderBottom: Color,
    val primaryAccent: Color,
    val prGold: Color,
    val signalGreen: Color,
    val textPrimary: Color,
    val textSecondary: Color
) {
    GRAPHITE_BEVEL(
        id = "graphite_bevel",
        title = "Graphite Bevel",
        bgCanvas = Color(0xFF101216),
        surface1 = Color(0xFF171A21),
        surface2 = Color(0xFF1F242D),
        borderTop = Color(0x29FFFFFF),
        borderBottom = Color(0x14FFFFFF),
        primaryAccent = Color(0xFFCCFF00),
        prGold = Color(0xFFFACC15),
        signalGreen = Color(0xFF34D399),
        textPrimary = Color(0xFFF8FAFC),
        textSecondary = Color(0xFF94A3B8)
    ),
    STRAVA_OBSIDIAN(
        id = "strava_obsidian",
        title = "Strava Obsidian",
        bgCanvas = Color(0xFF0D0F12),
        surface1 = Color(0xFF15181E),
        surface2 = Color(0xFF1D212A),
        borderTop = Color(0x26FFFFFF),
        borderBottom = Color(0x14FFFFFF),
        primaryAccent = Color(0xFFFC4C02),
        prGold = Color(0xFFFACC15),
        signalGreen = Color(0xFF10B981),
        textPrimary = Color(0xFFF8FAFC),
        textSecondary = Color(0xFF9CA3AF)
    ),
    BEVEL_NAVY(
        id = "bevel_navy",
        title = "Bevel Navy",
        bgCanvas = Color(0xFF0F172A),
        surface1 = Color(0xFF16213A),
        surface2 = Color(0xFF1C2A48),
        borderTop = Color(0x29FFFFFF),
        borderBottom = Color(0x16FFFFFF),
        primaryAccent = Color(0xFF38BDF8),
        prGold = Color(0xFFEAB308),
        signalGreen = Color(0xFF7FC791),
        textPrimary = Color(0xFFF1F5F9),
        textSecondary = Color(0xFFA9B8CE)
    ),
    LANE4_CARBON(
        id = "lane4_carbon",
        title = "Lane 4 Carbon",
        bgCanvas = Color(0xFF060709),
        surface1 = Color(0xFF0F1217),
        surface2 = Color(0xFF171C24),
        borderTop = Color(0x2EFFFFFF),
        borderBottom = Color(0x18FFFFFF),
        primaryAccent = Color(0xFFD4FF00),
        prGold = Color(0xFFFDE047),
        signalGreen = Color(0xFF22C55E),
        textPrimary = Color(0xFFFFFFFF),
        textSecondary = Color(0xFF94A3B8)
    ),
    MINIMAL_ALABASTER(
        id = "minimal_alabaster",
        title = "Minimalist Lab",
        bgCanvas = Color(0xFFF3F4F6),
        surface1 = Color(0xFFFFFFFF),
        surface2 = Color(0xFFE5E7EB),
        borderTop = Color(0xE6FFFFFF),
        borderBottom = Color(0x14000000),
        primaryAccent = Color(0xFF111827),
        prGold = Color(0xFFD97706),
        signalGreen = Color(0xFF059669),
        textPrimary = Color(0xFF111827),
        textSecondary = Color(0xFF4B5563)
    )
}

@Composable
fun L4NEAndroidRootScreen(databasePath: String) {
    var activeTheme by remember { mutableStateOf(L4NEAndroidTheme.GRAPHITE_BEVEL) }
    var statsJson by remember { mutableStateOf("") }
    var healthSummaryJson by remember { mutableStateOf("") }

    LaunchedEffect(databasePath) {
        L4NECoreNative.initDatabaseJson(databasePath, true)
        statsJson = L4NECoreNative.executeJson(databasePath, """{"action":"database_stats"}""")
        healthSummaryJson = L4NECoreNative.executeJson(databasePath, """{"action":"health_context_summary"}""")
    }

    val bevelBorderBrush = Brush.verticalGradient(
        colors = listOf(activeTheme.borderTop, activeTheme.borderBottom)
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(activeTheme.bgCanvas)
            .padding(16.dp)
    ) {
        // Stylized L4NE Wordmark + Multi-Theme Strip
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("L", color = activeTheme.textPrimary, fontSize = 24.sp, fontWeight = FontWeight.Black)
            Text("4", color = activeTheme.primaryAccent, fontSize = 24.sp, fontWeight = FontWeight.Black)
            Text("NE TRAINING · v1.3", color = activeTheme.textPrimary, fontSize = 24.sp, fontWeight = FontWeight.Black)
        }
        Text(
            "BEVEL GRAPHITE · STRAVA ANALYTICS · MULTI-THEME RUST CORE",
            color = activeTheme.textSecondary,
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Multi-Theme Selector Pills (persisted into SQLite via JNI)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(L4NEAndroidTheme.entries) { preset ->
                val isSelected = preset == activeTheme
                Box(
                    modifier = Modifier
                        .background(
                            if (isSelected) activeTheme.primaryAccent else activeTheme.surface2,
                            CircleShape
                        )
                        .clickable {
                            activeTheme = preset
                            L4NECoreNative.executeJson(
                                databasePath,
                                """{"action":"update_app_settings","payload":{"active_theme":"${preset.id}","default_pool_length_m":50,"preferred_sport":"finswimming","haptics_enabled":true,"auto_advance_sendoff":true,"updated_at_ms":1795600000000}}"""
                            )
                        }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        preset.title,
                        color = if (isSelected) Color.Black else activeTheme.textPrimary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(activeTheme.surface1, RoundedCornerShape(16.dp))
                        .border(1.dp, bevelBorderBrush, RoundedCornerShape(16.dp))
                        .padding(16.dp)
                ) {
                    Text(
                        "BEVEL RECOVERY & HEALTH CONTEXT BASELINES",
                        color = activeTheme.primaryAccent,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(healthSummaryJson, color = activeTheme.textPrimary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }

            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(activeTheme.surface1, RoundedCornerShape(16.dp))
                        .border(1.dp, bevelBorderBrush, RoundedCornerShape(16.dp))
                        .padding(16.dp)
                ) {
                    Text(
                        "RUST CORE v1.3.0 SCHEMA v4 DIAGNOSTICS (JNI)",
                        color = activeTheme.signalGreen,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(statsJson, color = activeTheme.textPrimary, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}
