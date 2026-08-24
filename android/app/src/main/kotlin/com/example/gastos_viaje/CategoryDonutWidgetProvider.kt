package com.example.gastos_viaje

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import kotlin.math.*

class CategoryDonutWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "CategoryDonutWidget"

        // Fixed color per category key — stable regardless of order
        private val CAT_COLORS = mapOf(
            "food"          to 0xFFC8592A.toInt(), // Orange (app accent)
            "lodging"       to 0xFF4FA3D4.toInt(), // Blue
            "transport"     to 0xFF4CBFBF.toInt(), // Teal
            "entertainment" to 0xFFB05AD4.toInt(), // Violet
            "shopping"      to 0xFFD4679C.toInt(), // Pink
            "activities"    to 0xFF4CAF7D.toInt(), // Green
            "health"        to 0xFFD45A5A.toInt(), // Red
            "flight"        to 0xFF5AC4D4.toInt(), // Cyan
            "drinks"        to 0xFFD4A017.toInt(), // Amber
            "fuel"          to 0xFF9B82D4.toInt(), // Purple
            "tips"          to 0xFFD4C317.toInt(), // Yellow
            "parking"       to 0xFF7ED44F.toInt(), // Lime
            "other"         to 0xFF8A8278.toInt(), // Gray
        )
        private val DEFAULT_COLOR = 0xFF8A8278.toInt()
    }

    data class Slice(val name: String, val amount: Double, val color: Int)
    data class Row(val row: Int, val sep: Int?, val dot: Int, val name: Int, val amt: Int)

    private val rows = listOf(
        Row(R.id.legend_row_1, null,       R.id.dot_1, R.id.name_1, R.id.amt_1),
        Row(R.id.legend_row_2, R.id.sep_1, R.id.dot_2, R.id.name_2, R.id.amt_2),
        Row(R.id.legend_row_3, R.id.sep_2, R.id.dot_3, R.id.name_3, R.id.amt_3),
        Row(R.id.legend_row_4, R.id.sep_3, R.id.dot_4, R.id.name_4, R.id.amt_4),
    )

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

        val styleIdx  = prefs.safeInt("flutter.settings_style",  0).coerceIn(0, 3)
        val accentInt = prefs.safeInt("flutter.settings_accent", 0xFFC8592A.toInt())
        val langIdx   = prefs.safeInt("flutter.settings_lang",  0).coerceIn(0, 8)

        val displayName  = tripName?.takeIf { it.isNotBlank() } ?: noTripLabel(langIdx)
        if (!isPremium) {
            showLockedMessage(context, mgr, widgetId, langIdx, accentInt, styleColors(styleIdx))
            return
        }
        val slices       = parseSlices(categories, langIdx)
        val totalSlices  = slices.sumOf { it.amount }
        val currency     = total.trim().split(" ").firstOrNull()?.takeIf { it != "—" } ?: ""

        val (bgColor, textPrimary, textMuted) = styleColors(styleIdx)
        val dividerColor = Color.argb(40, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))
        val nameColor    = Color.argb(0xCC, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))

        val density = context.resources.displayMetrics.density
        val donutPx = (72 * density).roundToInt().coerceIn(48, 256)
        val bitmap  = renderDonut(donutPx, slices, totalSlices, total, textPrimary, textMuted)

        val intent = PendingIntent.getActivity(
            context, 3,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val v = RemoteViews(context.packageName, R.layout.donut_widget)
        v.setImageViewBitmap(R.id.iv_donut, bitmap)
        v.setTextViewText(R.id.tv_donut_name,  displayName)
        v.setTextViewText(R.id.tv_donut_total, total)
        v.setTextColor(R.id.tv_donut_name,  textPrimary)
        v.setTextColor(R.id.tv_donut_total, accentInt)
        v.setInt(R.id.donut_root,       "setBackgroundColor", bgColor)
        v.setInt(R.id.donut_accent_bar, "setBackgroundColor", accentInt)
        v.setInt(R.id.donut_divider,    "setBackgroundColor", dividerColor)

        if (slices.isEmpty()) {
            val r = rows[0]
            v.setViewVisibility(r.row, View.VISIBLE)
            v.setImageViewBitmap(r.dot, transparentDot(density))
            v.setTextViewText(r.name, noDataLabel(langIdx))
            v.setTextColor(r.name, textMuted)
            v.setTextViewText(r.amt, "")
            rows.drop(1).forEach { lr ->
                v.setViewVisibility(lr.row, View.GONE)
                lr.sep?.let { v.setViewVisibility(it, View.GONE) }
            }
        } else {
            rows.forEachIndexed { i, lr ->
                val show = i < slices.size
                v.setViewVisibility(lr.row, if (show) View.VISIBLE else View.GONE)
                lr.sep?.let { v.setViewVisibility(it, if (show) View.VISIBLE else View.GONE) }
                if (show) {
                    val sl  = slices[i]
                    val amt = if (currency.isNotEmpty()) "$currency ${sl.amount.fmt()}" else sl.amount.fmt()
                    v.setImageViewBitmap(lr.dot, colorDot(sl.color, density))
                    v.setTextViewText(lr.name, sl.name)
                    v.setTextColor(lr.name, nameColor)
                    v.setTextViewText(lr.amt, amt)
                    v.setTextColor(lr.amt, textPrimary)
                }
            }
        }

        v.setOnClickPendingIntent(R.id.donut_root, intent)
        mgr.updateAppWidget(widgetId, v)
    }

    private fun showFallback(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        try {
            val v = RemoteViews(context.packageName, R.layout.donut_widget)
            v.setTextViewText(R.id.tv_donut_name, "Nivela")
            v.setTextViewText(R.id.tv_donut_total, "—")
            mgr.updateAppWidget(widgetId, v)
        } catch (t: Throwable) {
            Log.e(TAG, "Fallback also failed", t)
        }
    }

    // Parses "food:120.50|transport:80.00|..." into slices with per-category colors
    private fun parseSlices(raw: String, lang: Int): List<Slice> {
        if (raw.isBlank()) return emptyList()
        return raw.split("|").take(4).mapNotNull { part ->
            val colon  = part.lastIndexOf(':')
            if (colon < 1) return@mapNotNull null
            val key    = part.substring(0, colon)
            val amount = part.substring(colon + 1).toDoubleOrNull()?.takeIf { it > 0 }
                ?: return@mapNotNull null
            Slice(catLabel(key, lang), amount, CAT_COLORS[key] ?: DEFAULT_COLOR)
        }
    }

    private fun SharedPreferences.safeInt(key: String, defValue: Int): Int {
        return try {
            getLong(key, defValue.toLong()).toInt()
        } catch (e: ClassCastException) {
            try { getInt(key, defValue) } catch (e2: Exception) { defValue }
        }
    }

    private fun transparentDot(density: Float): Bitmap {
        val px = (8f * density).roundToInt().coerceAtLeast(1)
        return Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    }

    private fun colorDot(color: Int, density: Float): Bitmap {
        val px  = (8f * density).roundToInt().coerceAtLeast(1)
        val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        Canvas(bmp).drawCircle(px / 2f, px / 2f, px / 2f,
            Paint().apply { isAntiAlias = true; this.color = color })
        return bmp
    }

    private fun renderDonut(
        px: Int, slices: List<Slice>, total: Double,
        totalLabel: String, textPrimary: Int, textMuted: Int
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx     = px / 2f; val cy = px / 2f
        val outerR = px / 2f * 0.88f
        val innerR = outerR * 0.56f
        val arcR   = (outerR + innerR) / 2f
        val strokeW = (outerR - innerR).coerceAtLeast(2f)
        val rect   = RectF(cx - arcR, cy - arcR, cx + arcR, cy + arcR)

        val ring = Paint().apply { isAntiAlias = true; style = Paint.Style.STROKE; strokeWidth = strokeW }

        ring.strokeCap = Paint.Cap.BUTT
        ring.color = Color.argb(46, Color.red(textMuted), Color.green(textMuted), Color.blue(textMuted))
        canvas.drawCircle(cx, cy, arcR, ring)

        if (slices.isNotEmpty() && total > 0.0) {
            val gapDeg = if (slices.size > 1) 1.26f else 0f
            ring.strokeCap = Paint.Cap.ROUND
            var angle = -90f
            for (sl in slices) {
                val sweep = (sl.amount / total * 360f).toFloat()
                val draw  = sweep - gapDeg
                if (draw > 0.5f) {
                    ring.color = sl.color
                    canvas.drawArc(rect, angle + gapDeg / 2f, draw, false, ring)
                }
                angle += sweep
            }
        }

        val parts = totalLabel.trim().split(" ", limit = 2)
        val cur   = if (parts.size == 2) parts[0] else ""
        val amt   = if (parts.size == 2) parts[1] else totalLabel
        val tp    = Paint().apply { isAntiAlias = true; textAlign = Paint.Align.CENTER }

        if (cur.isNotEmpty() && cur != "—") {
            tp.textSize = (innerR * 0.30f).coerceAtLeast(6f); tp.color = textMuted
            canvas.drawText(cur, cx, cy - innerR * 0.06f, tp)
            tp.textSize = (innerR * 0.40f).coerceAtLeast(8f); tp.color = textPrimary
            canvas.drawText(amt, cx, cy + innerR * 0.40f, tp)
        } else {
            tp.textSize = (innerR * 0.40f).coerceAtLeast(8f); tp.color = textPrimary
            canvas.drawText(amt, cx, cy + innerR * 0.15f, tp)
        }
        return bmp
    }

    private fun Double.fmt(): String {
        val s = "%.2f".format(this)
        return if (s.endsWith(".00")) s.dropLast(3) else s
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

    private fun showLockedMessage(
        context: Context, mgr: AppWidgetManager, widgetId: Int,
        lang: Int, accentInt: Int, colors: Triple<Int,Int,Int>
    ) {
        val (bgColor, textPrimary, _) = colors
        val v = RemoteViews(context.packageName, R.layout.donut_widget)
        val px = (72 * context.resources.displayMetrics.density).roundToInt().coerceIn(48, 256)
        val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = px / 2f; val cy = px / 2f
        val outerR = px / 2f * 0.88f; val innerR = outerR * 0.56f
        val arcR = (outerR + innerR) / 2f; val strokeW = (outerR - innerR).coerceAtLeast(2f)
        val ring = Paint().apply { isAntiAlias = true; style = Paint.Style.STROKE; strokeWidth = strokeW; strokeCap = Paint.Cap.ROUND }
        ring.color = Color.argb(46, Color.red(accentInt), Color.green(accentInt), Color.blue(accentInt))
        canvas.drawCircle(cx, cy, arcR, ring)
        ring.color = accentInt
        canvas.drawArc(RectF(cx - arcR, cy - arcR, cx + arcR, cy + arcR), -90f, 360f, false, ring)
        v.setImageViewBitmap(R.id.iv_donut, bmp)
        v.setTextViewText(R.id.tv_donut_name, "Nivela")
        v.setTextViewText(R.id.tv_donut_total, "Premium")
        v.setTextColor(R.id.tv_donut_name, textPrimary)
        v.setTextColor(R.id.tv_donut_total, accentInt)
        v.setInt(R.id.donut_root, "setBackgroundColor", bgColor)
        v.setInt(R.id.donut_accent_bar, "setBackgroundColor", accentInt)
        v.setInt(R.id.donut_divider, "setBackgroundColor", Color.argb(40, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary)))
        val r = rows[0]
        v.setViewVisibility(r.row, View.VISIBLE)
        v.setImageViewBitmap(r.dot, Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))
        v.setTextViewText(r.name, premiumLabel(lang))
        v.setTextColor(r.name, accentInt)
        v.setTextViewText(r.amt, "")
        rows.drop(1).forEach { lr ->
            v.setViewVisibility(lr.row, View.GONE)
            lr.sep?.let { v.setViewVisibility(it, View.GONE) }
        }
        mgr.updateAppWidget(widgetId, v)
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
        7 -> "Keine Reise"; 8 -> "Nessun viaggio"; else -> "Sin viaje activo"
    }

    private fun noDataLabel(lang: Int) = when (lang) {
        1 -> "No expenses yet"; 2 -> "Pas de dépenses"; 3 -> "暂无支出"
        4 -> "支出なし"; 5 -> "지출 없음"; 6 -> "Нет расходов"
        7 -> "Keine Ausgaben"; 8 -> "Nessuna spesa"; else -> "Sin gastos aún"
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
