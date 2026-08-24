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

class DonutWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "DonutWidget"
        // Must stay in sync with AppTheme.avatarPalette accent colors (index 1 of each pair)
        private val PALETTE = intArrayOf(
            0xFFD45A5A.toInt(), // 0 Red
            0xFFC8592A.toInt(), // 1 Orange
            0xFFD4A017.toInt(), // 2 Gold
            0xFF7ED44F.toInt(), // 3 Lime
            0xFF4CAF7D.toInt(), // 4 Green
            0xFF4CBFBF.toInt(), // 5 Teal
            0xFF4FA3D4.toInt(), // 6 Blue
            0xFF9B82D4.toInt(), // 7 Purple
            0xFFB05AD4.toInt(), // 8 Violet
            0xFFD4679C.toInt(), // 9 Pink
        )
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
        Log.d(TAG, "onUpdate for ${appWidgetIds.size} widgets")
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

        val isPremium   = prefs.getBoolean("flutter.settings_premium", false)
        val tripName    = prefs.getString("flutter.widget_trip_name", null)
        val total       = prefs.getString("flutter.widget_total", "—") ?: "—"
        val consumption = if (isPremium) prefs.getString("flutter.widget_consumption", "") ?: "" else ""

        val styleIdx  = prefs.safeInt("flutter.settings_style",  0).coerceIn(0, 3)
        val accentInt = prefs.safeInt("flutter.settings_accent", 0xFFC8592A.toInt())
        val langIdx   = prefs.safeInt("flutter.settings_lang",  0).coerceIn(0, 8)

        Log.d(TAG, "style=$styleIdx accent=#${Integer.toHexString(accentInt)} total=$total")

        val displayName   = tripName?.takeIf { it.isNotBlank() } ?: noTripLabel(langIdx)
        if (!isPremium) {
            showLockedMessage(context, mgr, widgetId, langIdx, accentInt, styleColors(styleIdx))
            return
        }
        val slices        = parseSlices(consumption)
        val totalConsumed = slices.sumOf { it.amount }
        val currency      = total.trim().split(" ").firstOrNull()?.takeIf { it != "—" } ?: ""

        val (bgColor, textPrimary, textMuted) = styleColors(styleIdx)
        val dividerColor = Color.argb(40, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))
        val nameColor    = Color.argb(0xCC, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary))

        val density = context.resources.displayMetrics.density
        val donutPx = (72 * density).roundToInt().coerceIn(48, 256)
        Log.d(TAG, "Rendering donut ${donutPx}x${donutPx}px, ${slices.size} slices")

        val bitmap = renderDonut(donutPx, slices, totalConsumed, total, textPrimary, textMuted)

        val intent = PendingIntent.getActivity(
            context, 1,
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
        Log.d(TAG, "Widget $widgetId updated OK")
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
        val cx      = px / 2f
        val cy      = px / 2f
        val outerR  = px / 2f * 0.88f
        val innerR  = outerR * 0.56f  // matches Flutter: innerR = outerR * 0.56
        val arcR    = (outerR + innerR) / 2f
        val strokeW = (outerR - innerR).coerceAtLeast(2f)
        val rect    = RectF(cx - arcR, cy - arcR, cx + arcR, cy + arcR)

        val ring = Paint().apply {
            isAntiAlias  = true
            style        = Paint.Style.STROKE
            strokeWidth  = strokeW
        }

        // ── Background track (matches Flutter: 0.18 opacity = 46/255) ──
        ring.strokeCap = Paint.Cap.BUTT
        ring.color = Color.argb(
            46,
            Color.red(textMuted), Color.green(textMuted), Color.blue(textMuted)
        )
        canvas.drawCircle(cx, cy, arcR, ring)

        if (slices.isNotEmpty() && total > 0.0) {
            // 0.022 radians converted to degrees ≈ 1.26°
            val gapDeg = if (slices.size > 1) 1.26f else 0f
            ring.strokeCap = Paint.Cap.ROUND  // smooth rounded arc ends
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

        // ── Center text ──
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

    private fun parseSlices(raw: String): List<Slice> {
        if (raw.isBlank()) return emptyList()
        return raw.split("|").mapIndexedNotNull { i, part ->
            val segments = part.split(":")
            when {
                segments.size >= 3 -> {
                    // Format: "name:amount:colorIdx" (name may itself contain ':')
                    val colorIdx = segments.last().toIntOrNull() ?: i
                    val amount   = segments[segments.size - 2].toDoubleOrNull()
                        ?.takeIf { it > 0 } ?: return@mapIndexedNotNull null
                    val name     = segments.dropLast(2).joinToString(":")
                    Slice(name, amount, PALETTE[colorIdx % PALETTE.size])
                }
                segments.size == 2 -> {
                    // Legacy format: "name:amount"
                    val amount = segments[1].toDoubleOrNull()
                        ?.takeIf { it > 0 } ?: return@mapIndexedNotNull null
                    Slice(segments[0], amount, PALETTE[i % PALETTE.size])
                }
                else -> return@mapIndexedNotNull null
            }
        }
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
        val (bgColor, textPrimary, textMuted) = colors
        val v = RemoteViews(context.packageName, R.layout.donut_widget)
        v.setImageViewBitmap(R.id.iv_donut, renderLockedDonut((72 * context.resources.displayMetrics.density).roundToInt().coerceIn(48,256), accentInt))
        v.setTextViewText(R.id.tv_donut_name, "Nivela")
        v.setTextViewText(R.id.tv_donut_total, "Premium")
        v.setTextColor(R.id.tv_donut_name, textPrimary)
        v.setTextColor(R.id.tv_donut_total, accentInt)
        v.setInt(R.id.donut_root, "setBackgroundColor", bgColor)
        v.setInt(R.id.donut_accent_bar, "setBackgroundColor", accentInt)
        v.setInt(R.id.donut_divider, "setBackgroundColor", Color.argb(40, Color.red(textPrimary), Color.green(textPrimary), Color.blue(textPrimary)))
        val r = rows[0]
        v.setViewVisibility(r.row, View.VISIBLE)
        v.setImageViewBitmap(r.dot, transparentDot(context.resources.displayMetrics.density))
        v.setTextViewText(r.name, premiumLabel(lang))
        v.setTextColor(r.name, accentInt)
        v.setTextViewText(r.amt, "")
        rows.drop(1).forEach { lr ->
            v.setViewVisibility(lr.row, View.GONE)
            lr.sep?.let { v.setViewVisibility(it, View.GONE) }
        }
        mgr.updateAppWidget(widgetId, v)
    }

    private fun renderLockedDonut(px: Int, accentInt: Int): Bitmap {
        val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = px / 2f; val cy = px / 2f
        val outerR = px / 2f * 0.88f; val innerR = outerR * 0.56f
        val arcR = (outerR + innerR) / 2f; val strokeW = (outerR - innerR).coerceAtLeast(2f)
        val ring = Paint().apply { isAntiAlias = true; style = Paint.Style.STROKE; strokeWidth = strokeW; strokeCap = Paint.Cap.BUTT }
        ring.color = Color.argb(46, Color.red(accentInt), Color.green(accentInt), Color.blue(accentInt))
        canvas.drawCircle(cx, cy, arcR, ring)
        ring.strokeCap = Paint.Cap.ROUND; ring.color = accentInt
        val rect = RectF(cx - arcR, cy - arcR, cx + arcR, cy + arcR)
        canvas.drawArc(rect, -90f, 360f, false, ring)
        return bmp
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
        1 -> "Open app first"; 2 -> "Ouvrez l'app"; 3 -> "先打开应用"
        4 -> "アプリを開く"; 5 -> "앱 열기"; 6 -> "Откройте приложение"
        7 -> "App öffnen"; 8 -> "Apri l'app"; else -> "Abre la app primero"
    }
}
