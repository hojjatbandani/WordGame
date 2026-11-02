package com.huruf.huruf

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * ودجة الشاشة الرئيسية — **طبقة عرض بحتة**.
 *
 * لا تحسب مكافأة ولا تُطالب بها ولا تلمس الألماس أو السلسلة أو التقدّم:
 * كل ما تفعله هو قراءة لقطة JSON كتبها التطبيق ورسمُها، ثم فتح التطبيق
 * على شاشة الجوائز عند النقر. المفتاح الوحيد الذي تكتبه هو
 * [INSTALLED_KEY] وهو إشارة وجود لا حالة لعب — يقرأها التطبيق مرة واحدة
 * ليمنح مكافأة التفعيل (راجع lib/data/widget/widget_activation.dart).
 *
 * حتى النصوص العربية لا تُؤلَّف هنا: تصل جاهزة من Flutter
 * (lib/data/widget/widget_text.dart)، فصياغة واحدة تخدم أندرويد وiOS
 * والاختبارات معا، ولا تتباعد صيغ المثنى والجمع بين ثلاث لغات برمجة.
 */
class HurufWidgetProvider : HomeWidgetProvider() {

    companion object {
        /** يطابق HomeWidgetService.dataKey في Flutter */
        private const val DATA_KEY = "huruf_widget_data"

        /** يطابق HomeWidgetService.installedKey في Flutter */
        private const val INSTALLED_KEY = "huruf_widget_installed"

        /** يطابق kWidgetDataSchemaVersion في widget_data.dart */
        private const val SCHEMA_VERSION = 1

        /** عتبات اختيار التخطيط بالـdp — الودجة تُمدَّد بحرّية فلا يكفي حجم واحد */
        private const val MEDIUM_MIN_WIDTH_DP = 180
        private const val LARGE_MIN_HEIGHT_DP = 220

        /** أطول دورة تُرسَم نقاطا. الشهرية (30) تُعرض رقما لا ثلاثين نقطة. */
        private const val MAX_DOTS = 10
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // وجود نسخة واحدة على الأقل — التطبيق يقرؤه ليمنح مكافأة التفعيل
        markInstalled(context, true)
        appWidgetIds.forEach { id ->
            render(context, appWidgetManager, id, widgetData)
        }
    }

    /** تغيير الحجم يستدعي هذه لا onUpdate، فبلاها يبقى تخطيط الحجم القديم */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        markInstalled(context, true)
    }

    /** آخر نسخة أُزيلت من الشاشة */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        markInstalled(context, false)
    }

    /**
     * يكتب «توجد ودجة الآن» في نفس ملف التفضيلات الذي تقرأه Flutter.
     *
     * لا يمنح شيئا ولا يلغي منحا: علَم المكافأة نفسه يعيش في تخزين
     * التطبيق ولا يُخفَض أبدا، فإزالة الودجة وإعادتها لا تعيد المكافأة.
     */
    private fun markInstalled(context: Context, installed: Boolean) {
        HomeWidgetPlugin.getData(context).edit()
            .putBoolean(INSTALLED_KEY, installed)
            .apply()
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val data = parse(widgetData.getString(DATA_KEY, null))

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // أندرويد 12+: النظام يختار التخطيط المناسب لكل مقاس بنفسه،
            // فلا وميض عند تغيير الحجم ولا حسابات dp يدوية
            RemoteViews(
                mapOf(
                    SizeF(140f, 110f) to build(context, R.layout.huruf_widget_small, data),
                    SizeF(180f, 110f) to build(context, R.layout.huruf_widget_medium, data),
                    SizeF(180f, 220f) to build(context, R.layout.huruf_widget_large, data),
                )
            )
        } else {
            build(context, layoutForSize(manager, widgetId), data)
        }

        manager.updateAppWidget(widgetId, views)
    }

    /** اختيار يدوي للتخطيط على ما قبل أندرويد 12 */
    private fun layoutForSize(manager: AppWidgetManager, widgetId: Int): Int {
        val options = manager.getAppWidgetOptions(widgetId)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return when {
            height >= LARGE_MIN_HEIGHT_DP && width >= MEDIUM_MIN_WIDTH_DP ->
                R.layout.huruf_widget_large
            width >= MEDIUM_MIN_WIDTH_DP -> R.layout.huruf_widget_medium
            else -> R.layout.huruf_widget_small
        }
    }

    private fun build(context: Context, layoutId: Int, data: WidgetSnapshot?): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)

        // النقرة العامة على كامل الودجة — تفتح الطبقة المُبرَزة
        views.setOnClickPendingIntent(
            R.id.widget_root,
            launchIntent(context, data?.deepLink),
        )

        if (data == null) {
            // لا بيانات بعد (تثبيت جديد، أو لقطة تالفة، أو نسخة عقد لا
            // نعرفها): حالة محايدة تفتح اللعبة — لا أرقام مخترَعة
            renderEmpty(context, views, layoutId)
            return views
        }

        applyDirection(views, layoutId, data.rtl)

        when (layoutId) {
            R.layout.huruf_widget_small -> renderSmall(views, data)
            R.layout.huruf_widget_medium -> renderMedium(context, views, data)
            else -> renderLarge(context, views, data)
        }
        return views
    }

    /**
     * اتجاه التخطيط يتبع **لغة اللعبة** لا لغة النظام: لاعب اختار
     * العربية داخل اللعبة على هاتف إنجليزي يجب أن يرى ودجته عربية
     * يمينا-إلى-يسار. `setLayoutDirection` على الجذر يكفي — كل
     * المحاذاة في التخطيطات بـstart/end فترث الاتجاه.
     */
    private fun applyDirection(views: RemoteViews, layoutId: Int, rtl: Boolean) {
        val direction = if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        views.setInt(R.id.widget_root, "setLayoutDirection", direction)
        if (layoutId == R.layout.huruf_widget_large) {
            listOf(R.id.widget_tier_0, R.id.widget_tier_1, R.id.widget_tier_2)
                .forEach { views.setInt(it, "setLayoutDirection", direction) }
        }
    }

    private fun renderEmpty(context: Context, views: RemoteViews, layoutId: Int) {
        val name = context.getString(R.string.huruf_widget_name)
        views.setTextViewText(R.id.widget_title, name)
        views.setTextViewText(R.id.widget_amount, "")
        views.setTextViewText(R.id.widget_status, "")
        views.setTextViewText(R.id.widget_streak, "")
        if (layoutId != R.layout.huruf_widget_small) {
            views.setTextViewText(R.id.widget_diamonds, "")
            views.setTextViewText(R.id.widget_cta, name)
            views.setViewVisibility(R.id.widget_cta, View.VISIBLE)
        }
    }

    private fun renderSmall(views: RemoteViews, data: WidgetSnapshot) {
        views.setTextViewText(R.id.widget_title, data.text("focusTitle"))
        views.setTextViewText(R.id.widget_amount, data.text("focusAmount"))
        views.setTextViewText(R.id.widget_status, data.text("focusStatus"))
        views.setTextViewText(R.id.widget_streak, data.text("streak"))
    }

    private fun renderMedium(context: Context, views: RemoteViews, data: WidgetSnapshot) {
        views.setTextViewText(R.id.widget_title, data.text("focusTitle"))
        views.setTextViewText(R.id.widget_amount, data.text("focusAmount"))
        views.setTextViewText(R.id.widget_status, data.text("focusStatus"))
        views.setTextViewText(R.id.widget_streak, data.text("streak"))
        views.setTextViewText(R.id.widget_diamonds, "💎 ${data.diamonds}")

        val progress = data.text("focusProgress")
        views.setTextViewText(R.id.widget_progress, progress)
        views.setViewVisibility(
            R.id.widget_progress,
            if (progress.isEmpty()) View.GONE else View.VISIBLE,
        )

        val focus = data.focusTier()
        renderDots(context, views, R.id.widget_dots, focus)

        views.setTextViewText(R.id.widget_cta, data.text("cta"))
        // الزرّ ذهبي مصمت حين توجد جائزة جاهزة، وباهت حين لا يوجد إلا
        // «افتح اللعبة» — الودجة لا تصرخ بلا سبب
        views.setInt(
            R.id.widget_cta,
            "setBackgroundResource",
            if (data.hasClaimable) R.drawable.huruf_widget_cta
            else R.drawable.huruf_widget_cta_muted,
        )
        views.setTextColor(
            R.id.widget_cta,
            context.getColor(
                if (data.hasClaimable) R.color.huruf_bg_top
                else R.color.huruf_text_primary
            ),
        )
    }

    private fun renderLarge(context: Context, views: RemoteViews, data: WidgetSnapshot) {
        views.setTextViewText(R.id.widget_title, data.text("allTitle"))
        views.setTextViewText(R.id.widget_diamonds, "💎 ${data.diamonds}")
        views.setTextViewText(R.id.widget_streak, data.text("streak"))
        views.setTextViewText(R.id.widget_stats, data.text("stats"))
        views.setTextViewText(R.id.widget_cta, data.text("cta"))
        views.setInt(
            R.id.widget_cta,
            "setBackgroundResource",
            if (data.hasClaimable) R.drawable.huruf_widget_cta
            else R.drawable.huruf_widget_cta_muted,
        )
        views.setTextColor(
            R.id.widget_cta,
            context.getColor(
                if (data.hasClaimable) R.color.huruf_bg_top
                else R.color.huruf_text_primary
            ),
        )

        val rows = listOf(
            Triple(R.id.widget_tier_0, R.id.widget_tier_0_title, R.id.widget_tier_0_status),
            Triple(R.id.widget_tier_1, R.id.widget_tier_1_title, R.id.widget_tier_1_status),
            Triple(R.id.widget_tier_2, R.id.widget_tier_2_title, R.id.widget_tier_2_status),
        )
        val amounts = listOf(
            R.id.widget_tier_0_amount, R.id.widget_tier_1_amount, R.id.widget_tier_2_amount,
        )
        val dotRows = listOf(
            R.id.widget_tier_0_dots, R.id.widget_tier_1_dots, R.id.widget_tier_2_dots,
        )

        val titles = data.textList("tierTitles")
        val statuses = data.textList("tierStatuses")

        rows.forEachIndexed { index, (rowId, titleId, statusId) ->
            val tier = data.tier(index)
            if (tier == null) {
                views.setViewVisibility(rowId, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(titleId, titles.getOrElse(index) { "" })
            views.setTextViewText(statusId, statuses.getOrElse(index) { "" })
            views.setTextViewText(
                amounts[index],
                if (tier.done) "" else "+${tier.coins} 💎",
            )
            renderDots(context, views, dotRows[index], tier)
            // كل صفّ يفتح بطاقته هو بعينها داخل شاشة الجوائز
            views.setOnClickPendingIntent(rowId, launchIntent(context, tier.deepLink))
        }
    }

    /**
     * نقاط التقدّم (● ● ● ● ○ ○ ○) لدورة الطبقة الحالية.
     *
     * تُخفى للطبقة اليومية (دورتها يوم واحد فلا تقدّم يُرسم) وللشهرية
     * (ثلاثون نقطة في ودجة عرضها 4 خلايا تصير خطّا لا معلومة) —
     * وكلتاهما تعرضان السطر النصّي «12 / 30 يوم» بدلا منها.
     */
    private fun renderDots(
        context: Context,
        views: RemoteViews,
        containerId: Int,
        tier: TierSnapshot?,
    ) {
        views.removeAllViews(containerId)
        if (tier == null || tier.done || tier.cycleLen <= 1 || tier.cycleLen > MAX_DOTS) {
            views.setViewVisibility(containerId, View.GONE)
            return
        }
        views.setViewVisibility(containerId, View.VISIBLE)
        for (index in 0 until tier.cycleLen) {
            val dot = RemoteViews(context.packageName, R.layout.huruf_widget_dot)
            dot.setImageViewResource(
                R.id.widget_dot,
                if (index < tier.cycleDone) R.drawable.huruf_widget_dot_on
                else R.drawable.huruf_widget_dot_off,
            )
            views.addView(containerId, dot)
        }
    }

    private fun launchIntent(context: Context, deepLink: String?): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            deepLink?.let { Uri.parse(it) },
        )

    // ─────────────────────── قراءة اللقطة ───────────────────────

    /**
     * يفكّ اللقطة، ويعيد null لأي شكل لا يفهمه — نصّ غائب أو تالف أو
     * نسخة عقد مختلفة. الودجة تعرض حينها حالة محايدة تفتح اللعبة، ولا
     * تنهار ولا ترسم أرقاما قديمة على أنها حالية.
     */
    private fun parse(raw: String?): WidgetSnapshot? {
        if (raw.isNullOrEmpty()) return null
        return try {
            val json = JSONObject(raw)
            if (json.optInt("v", -1) != SCHEMA_VERSION) return null
            val tiersJson = json.optJSONArray("tiers") ?: return null
            val links = json.optJSONArray("tierDeepLinks")
            val tiers = (0 until tiersJson.length()).map { index ->
                val tier = tiersJson.getJSONObject(index)
                TierSnapshot(
                    coins = tier.optInt("coins"),
                    ready = tier.optBoolean("ready"),
                    done = tier.optBoolean("done"),
                    cycleDone = tier.optInt("cycleDone"),
                    cycleLen = tier.optInt("cycleLen", 1),
                    deepLink = links?.optString(index),
                )
            }
            if (tiers.isEmpty()) return null
            WidgetSnapshot(
                json = json,
                tiers = tiers,
                diamonds = json.optInt("diamonds"),
                rtl = json.optBoolean("rtl", true),
                hasClaimable = json.optBoolean("hasClaimable"),
                focusIndex = json.optInt("focusIndex", -1),
                deepLink = json.optString("deepLink", null),
            )
        } catch (e: Exception) {
            null
        }
    }

    private data class TierSnapshot(
        val coins: Int,
        val ready: Boolean,
        val done: Boolean,
        val cycleDone: Int,
        val cycleLen: Int,
        val deepLink: String?,
    )

    private class WidgetSnapshot(
        private val json: JSONObject,
        val tiers: List<TierSnapshot>,
        val diamonds: Int,
        val rtl: Boolean,
        val hasClaimable: Boolean,
        val focusIndex: Int,
        val deepLink: String?,
    ) {
        private val texts: JSONObject? = json.optJSONObject("text")

        fun text(key: String): String = texts?.optString(key, "") ?: ""

        fun textList(key: String): List<String> {
            val array = texts?.optJSONArray(key) ?: return emptyList()
            return (0 until array.length()).map { array.optString(it, "") }
        }

        fun tier(index: Int): TierSnapshot? = tiers.getOrNull(index)

        fun focusTier(): TierSnapshot? = tier(focusIndex)
    }
}
