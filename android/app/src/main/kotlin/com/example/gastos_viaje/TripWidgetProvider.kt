package com.example.gastos_viaje

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews

class TripWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "TripWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            try {
                updateSingle(context, appWidgetManager, widgetId)
            } catch (t: Throwable) {
                Log.e(TAG, "Crash updating widget $widgetId", t)
                showFallback(context, appWidgetManager, widgetId)
            }
        }
    }

    private fun updateSingle(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val isPremium = prefs.getBoolean("flutter.settings_premium", false)
        val tripName = prefs.getString("flutter.widget_trip_name", null)
        val total    = prefs.getString("flutter.widget_total", "—") ?: "—"
        val balances = prefs.getString("flutter.widget_balances", null)
        val updated  = prefs.getString("flutter.widget_updated", "") ?: ""

        val styleIdx  = prefs.safeInt("flutter.settings_style",  0).coerceIn(0, 3)
        val accentInt = prefs.safeInt("flutter.settings_accent", 0xFFC8592A.toInt())
        val langIdx   = prefs.safeInt("flutter.settings_lang",  0).coerceIn(0, 8)

        Log.d(TAG, "style=$styleIdx accent=#${Integer.toHexString(accentInt)} lang=$langIdx")

        val displayName     = tripName?.takeIf { it.isNotBlank() } ?: noTripLabel(langIdx)
        val displayBalances = if (!isPremium) premiumLabel(langIdx)
                              else balances?.takeIf { it.isNotBlank() } ?: noDataLabel(langIdx)

        val (bgColor, textPrimary, textMuted) = styleColors(styleIdx)
        val dividerColor = Color.argb(40,
            Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))

        val launchIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val views = RemoteViews(context.packageName, R.layout.trip_widget)
        views.setTextViewText(R.id.tv_trip_name, displayName)
        views.setTextViewText(R.id.tv_total,     total)
        views.setTextViewText(R.id.tv_balances,  displayBalances)
        views.setTextViewText(R.id.tv_updated,   updated)
        views.setTextColor(R.id.tv_trip_name, textPrimary)
        views.setTextColor(R.id.tv_total,     accentInt)
        views.setTextColor(R.id.tv_balances,  textMuted)
        views.setTextColor(R.id.tv_updated,   textMuted)
        views.setInt(R.id.widget_root, "setBackgroundColor", bgColor)
        views.setInt(R.id.accent_bar,  "setBackgroundColor", accentInt)
        views.setInt(R.id.divider,     "setBackgroundColor", dividerColor)
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent)
        mgr.updateAppWidget(widgetId, views)
        Log.d(TAG, "Widget $widgetId updated OK")
    }

    private fun showFallback(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        try {
            val v = RemoteViews(context.packageName, R.layout.trip_widget)
            v.setTextViewText(R.id.tv_trip_name, "Nivela")
            v.setTextViewText(R.id.tv_total, "—")
            v.setTextViewText(R.id.tv_balances, "Abre la app primero")
            v.setTextViewText(R.id.tv_updated, "")
            mgr.updateAppWidget(widgetId, v)
        } catch (t: Throwable) {
            Log.e(TAG, "Fallback also failed", t)
        }
    }

    // Read a pref stored either as Long (Flutter default) or Int (older plugins)
    private fun SharedPreferences.safeInt(key: String, defValue: Int): Int {
        return try {
            getLong(key, defValue.toLong()).toInt()
        } catch (e: ClassCastException) {
            try { getInt(key, defValue) } catch (e2: Exception) { defValue }
        }
    }

    private fun styleColors(idx: Int): Triple<Int, Int, Int> {
        val textDark  = Color.argb(0xFF, 0xF5, 0xF3, 0xEF)
        val mutedDark = Color.argb(0xAA, 0xF5, 0xF3, 0xEF)
        return when (idx) {
            1    -> Triple(Color.argb(0xF2, 0x15, 0x15, 0x19), textDark, mutedDark)
            2    -> Triple(Color.argb(0xF2, 0x1C, 0x21, 0x30), textDark, mutedDark)
            3    -> Triple(Color.argb(0xF5,0xFF,0xFF,0xFF), Color.argb(0xFF,0x1A,0x18,0x16), Color.argb(0xAA,0x1A,0x18,0x16))
            else -> Triple(Color.argb(0xF2, 0x23, 0x23, 0x23), textDark, mutedDark)
        }
    }

    private fun premiumLabel(lang: Int) = when (lang) {
        1 -> "Nivela Premium required"; 2 -> "Nivela Premium requis"; 3 -> "需要 Nivela Premium"
        4 -> "Nivela Premium が必要"; 5 -> "Nivela Premium 필요"; 6 -> "Требуется Nivela Premium"
        7 -> "Nivela Premium erforderlich"; 8 -> "Nivela Premium richiesto"
        else -> "Requiere Nivela Premium"
    }

    private fun noTripLabel(lang: Int) = when (lang) {
        1 -> "No active trip"; 2 -> "Pas de voyage actif"; 3 -> "无活动行程"
        4 -> "旅行なし"; 5 -> "활성 여행 없음"; 6 -> "Нет поездки"
        7 -> "Keine Reise"; 8 -> "Nessun viaggio"
        else -> "Sin viaje activo"
    }

    private fun noDataLabel(lang: Int) = when (lang) {
        1 -> "Open app first"; 2 -> "Ouvrez l'app"; 3 -> "先打开应用"
        4 -> "アプリを開く"; 5 -> "앱 열기"; 6 -> "Откройте приложение"
        7 -> "App öffnen"; 8 -> "Apri l'app"
        else -> "Abre la app primero"
    }
}
