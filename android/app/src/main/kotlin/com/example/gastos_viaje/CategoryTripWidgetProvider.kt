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

class CategoryTripWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "CategoryTripWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
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

        val isPremium  = prefs.getBoolean("flutter.settings_premium", false)
        val tripName   = prefs.getString("flutter.widget_trip_name", null)
        val total      = prefs.getString("flutter.widget_total", "—") ?: "—"
        val categories = if (isPremium) prefs.getString("flutter.widget_categories", "") ?: "" else ""
        val updated    = prefs.getString("flutter.widget_updated", "") ?: ""

        val styleIdx  = prefs.safeInt("flutter.settings_style",  0).coerceIn(0, 3)
        val accentInt = prefs.safeInt("flutter.settings_accent", 0xFFC8592A.toInt())
        val langIdx   = prefs.safeInt("flutter.settings_lang",  0).coerceIn(0, 8)

        val displayName = tripName?.takeIf { it.isNotBlank() } ?: noTripLabel(langIdx)
        val catText     = buildCategoryText(categories, langIdx)
        val displayCats = when {
            !isPremium -> premiumLabel(langIdx)
            catText.isNotEmpty() -> catText
            else -> noDataLabel(langIdx)
        }

        val (bgColor, textPrimary, textMuted) = styleColors(styleIdx)
        val dividerColor = Color.argb(40,
            Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))

        val launchIntent = PendingIntent.getActivity(
            context, 2,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val views = RemoteViews(context.packageName, R.layout.trip_widget)
        views.setTextViewText(R.id.tv_trip_name, displayName)
        views.setTextViewText(R.id.tv_total,     total)
        views.setTextViewText(R.id.tv_balances,  displayCats)
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

    // Builds "Comida €45 · Transporte €30 · Hospedaje €20" from "food:45.00|transport:30.00|..."
    private fun buildCategoryText(raw: String, lang: Int): String {
        if (raw.isBlank()) return ""
        return raw.split("|").take(3).mapNotNull { part ->
            val colon = part.lastIndexOf(':')
            if (colon < 1) return@mapNotNull null
            val key    = part.substring(0, colon)
            val amount = part.substring(colon + 1).toDoubleOrNull()?.takeIf { it > 0 }
                ?: return@mapNotNull null
            val label  = catLabel(key, lang)
            "$label ${"%.0f".format(amount)}"
        }.joinToString(" · ")
    }

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

    private fun noTripLabel(lang: Int) = when (lang) {
        1 -> "No active trip"; 2 -> "Pas de voyage actif"; 3 -> "无活动行程"
        4 -> "旅行なし"; 5 -> "활성 여행 없음"; 6 -> "Нет поездки"
        7 -> "Keine Reise"; 8 -> "Nessun viaggio"
        else -> "Sin viaje activo"
    }

    private fun premiumLabel(lang: Int) = when (lang) {
        1 -> "Nivela Premium required"; 2 -> "Nivela Premium requis"; 3 -> "需要 Nivela Premium"
        4 -> "Nivela Premium が必要"; 5 -> "Nivela Premium 필요"; 6 -> "Требуется Nivela Premium"
        7 -> "Nivela Premium erforderlich"; 8 -> "Nivela Premium richiesto"
        else -> "Requiere Nivela Premium"
    }

    private fun noDataLabel(lang: Int) = when (lang) {
        1 -> "No expenses yet"; 2 -> "Pas de dépenses"; 3 -> "暂无支出"
        4 -> "支出なし"; 5 -> "지출 없음"; 6 -> "Нет расходов"
        7 -> "Keine Ausgaben"; 8 -> "Nessuna spesa"
        else -> "Sin gastos aún"
    }

    private fun catLabel(key: String, lang: Int): String = when (key) {
        "food"          -> when(lang){1->"Food";2->"Nourriture";3->"餐饮";4->"食事";5->"음식";6->"Еда";7->"Essen";8->"Cibo";else->"Comida"}
        "lodging"       -> when(lang){1->"Lodging";2->"Hébergement";3->"住宿";4->"宿泊";5->"숙박";6->"Жильё";7->"Unterkunft";8->"Alloggio";else->"Hospedaje"}
        "transport"     -> when(lang){1->"Transport";2->"Transport";3->"交通";4->"交通";5->"교통";6->"Транспорт";7->"Transport";8->"Trasporto";else->"Transporte"}
        "entertainment" -> when(lang){1->"Entertainment";2->"Divertissement";3->"娱乐";4->"エンタメ";5->"오락";6->"Развлечения";7->"Unterhaltung";8->"Intrattenimento";else->"Entretenimiento"}
        "shopping"      -> when(lang){1->"Shopping";2->"Shopping";3->"购物";4->"ショッピング";5->"쇼핑";6->"Покупки";7->"Einkaufen";8->"Shopping";else->"Compras"}
        "activities"    -> when(lang){1->"Activities";2->"Activités";3->"活动";4->"アクティビティ";5->"활동";6->"Активности";7->"Aktivitäten";8->"Attività";else->"Actividades"}
        "health"        -> when(lang){1->"Health";2->"Santé";3->"健康";4->"健康";5->"건강";6->"Здоровье";7->"Gesundheit";8->"Salute";else->"Salud"}
        "flight"        -> when(lang){1->"Flight";2->"Vol";3->"机票";4->"航空券";5->"항공편";6->"Перелёт";7->"Flug";8->"Volo";else->"Vuelo"}
        "drinks"        -> when(lang){1->"Drinks";2->"Boissons";3->"饮料";4->"飲み物";5->"음료";6->"Напитки";7->"Getränke";8->"Bevande";else->"Bebidas"}
        "fuel"          -> when(lang){1->"Fuel";2->"Carburant";3->"燃油";4->"燃料";5->"연료";6->"Топливо";7->"Kraftstoff";8->"Carburante";else->"Gasolina"}
        "tips"          -> when(lang){1->"Tips";2->"Pourboires";3->"小费";4->"チップ";5->"팁";6->"Чаевые";7->"Trinkgeld";8->"Mance";else->"Propinas"}
        "parking"       -> when(lang){1->"Parking";2->"Stationnement";3->"停车";4->"駐車場";5->"주차";6->"Парковка";7->"Parken";8->"Parcheggio";else->"Estacionamiento"}
        else            -> when(lang){1->"Other";2->"Autre";3->"其他";4->"その他";5->"기타";6->"Прочее";7->"Sonstiges";8->"Altro";else->"Otro"}
    }
}
