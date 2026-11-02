import SwiftUI
import WidgetKit

// ودجة الشاشة الرئيسية على iOS — **طبقة عرض بحتة**.
//
// لا تحسب مكافأة ولا تُطالب بها ولا تلمس الألماس أو السلسلة أو التقدّم:
// تقرأ لقطة JSON كتبها تطبيق Flutter في UserDefaults المشتركة (App
// Group)، ترسمها، وتفتح التطبيق عند النقر. كل تغيير في حالة اللعبة
// يبقى بيد التطبيق وحده.
//
// وحتى النصوص العربية لا تُؤلَّف هنا: تصل جاهزة من
// lib/data/widget/widget_text.dart، فصياغة واحدة تخدم أندرويد وiOS
// والاختبارات معا (صيغ المثنى والجمع العربية خصوصا).

// MARK: - العقد المشترك

/// يطابق HomeWidgetService.appGroupId في Flutter و.entitlements في الطرفين
private let appGroupId = "group.com.huruf.huruf.widget"

/// يطابق HomeWidgetService.dataKey
private let dataKey = "huruf_widget_data"

/// يطابق kWidgetDataSchemaVersion في widget_data.dart
private let schemaVersion = 1

/// أطول دورة تُرسَم نقاطا — الشهرية (30) تُعرض رقما لا ثلاثين نقطة
private let maxDots = 10

struct TierSnapshot {
    let coins: Int
    let ready: Bool
    let done: Bool
    let cycleDone: Int
    let cycleLen: Int
    let deepLink: String?
}

struct WidgetSnapshot {
    let diamonds: Int
    let rtl: Bool
    let hasClaimable: Bool
    let focusIndex: Int
    let deepLink: String?
    let tiers: [TierSnapshot]
    let text: [String: Any]

    var focus: TierSnapshot? {
        guard focusIndex >= 0, focusIndex < tiers.count else { return nil }
        return tiers[focusIndex]
    }

    func str(_ key: String) -> String { text[key] as? String ?? "" }

    func strings(_ key: String) -> [String] { text[key] as? [String] ?? [] }

    /// يفكّ اللقطة، ويعيد nil لأي شكل لا يفهمه — نصّ غائب أو تالف أو
    /// نسخة عقد مختلفة. الودجة تعرض حينها حالة محايدة تفتح اللعبة، ولا
    /// ترسم أرقاما قديمة على أنها حالية.
    static func load() -> WidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: dataKey),
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (json["v"] as? Int) == schemaVersion,
            let tiersJson = json["tiers"] as? [[String: Any]],
            !tiersJson.isEmpty
        else { return nil }

        let links = json["tierDeepLinks"] as? [String]
        let tiers = tiersJson.enumerated().map { index, tier in
            TierSnapshot(
                coins: tier["coins"] as? Int ?? 0,
                ready: tier["ready"] as? Bool ?? false,
                done: tier["done"] as? Bool ?? false,
                cycleDone: tier["cycleDone"] as? Int ?? 0,
                cycleLen: tier["cycleLen"] as? Int ?? 1,
                deepLink: links?.indices.contains(index) == true ? links?[index] : nil
            )
        }

        return WidgetSnapshot(
            diamonds: json["diamonds"] as? Int ?? 0,
            rtl: json["rtl"] as? Bool ?? true,
            hasClaimable: json["hasClaimable"] as? Bool ?? false,
            focusIndex: json["focusIndex"] as? Int ?? -1,
            deepLink: json["deepLink"] as? String,
            tiers: tiers,
            text: json["text"] as? [String: Any] ?? [:]
        )
    }
}

// MARK: - هوية اللعبة البصرية
//
// منقولة حرفيا من HurufTheme في lib/core/theme.dart — الودجة جزء من
// اللعبة، فلا ألوان خاصة بها.

private enum Huruf {
    static let bgTop = Color(red: 0x0A / 255, green: 0x0E / 255, blue: 0x27 / 255)
    static let bgBottom = Color(red: 0x1A / 255, green: 0x1F / 255, blue: 0x3A / 255)
    static let gold = Color(red: 0xF4 / 255, green: 0xC4 / 255, blue: 0x30 / 255)
    static let surface = Color(red: 0x17 / 255, green: 0x1C / 255, blue: 0x36 / 255)
    static let tileEmpty = Color(red: 0x23 / 255, green: 0x2A / 255, blue: 0x4D / 255)
    static let textPrimary = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xEC / 255)
    static let textSecondary = Color(red: 0x9A / 255, green: 0xA0 / 255, blue: 0xBE / 255)

    static let background = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - الخطّ الزمني

struct HurufEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct HurufProvider: TimelineProvider {
    func placeholder(in context: Context) -> HurufEntry {
        HurufEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (HurufEntry) -> Void) {
        completion(HurufEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    /// مدخل واحد يُعاد تقييمه عند أول منتصف ليل قادم.
    ///
    /// لماذا لا جدول أكثف: كل ما يتغيّر خلال اليوم يأتي من التطبيق نفسه
    /// (`HomeWidget.updateWidget` ← `WidgetCenter.reloadAllTimelines`)
    /// لحظة وقوعه، والشيء الوحيد الذي يتغيّر بلا فعل من اللاعب هو
    /// **تغيّر اليوم**. جدول أكثف يستهلك ميزانية التحديث التي يوزّعها
    /// النظام بلا فائدة.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HurufEntry>) -> Void) {
        let now = Date()
        let entry = HurufEntry(date: now, snapshot: WidgetSnapshot.load())
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - أجزاء مشتركة

/// خلفية الودجة. `containerBackground` مطلوبة منذ iOS 17 وإلا رُسمت
/// الودجة بلا خلفية أصلا؛ وما قبلها يحتاج الخلفية مرسومة يدويا.
private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { Huruf.background }
        } else {
            content
                .padding(12)
                .background(Huruf.background)
        }
    }
}

private extension View {
    func hurufBackground() -> some View { modifier(WidgetBackground()) }
}

/// نقاط التقدّم (● ● ● ● ○ ○ ○) لدورة الطبقة.
///
/// تُخفى للطبقة اليومية (دورتها يوم واحد) وللشهرية (ثلاثون نقطة في
/// ودجة صغيرة تصير خطّا لا معلومة) — وكلتاهما تعرضان السطر النصّي
/// «12 / 30 يوم» بدلا منها.
private struct ProgressDots: View {
    let tier: TierSnapshot?

    var body: some View {
        if let tier, !tier.done, tier.cycleLen > 1, tier.cycleLen <= maxDots {
            HStack(spacing: 5) {
                ForEach(0..<tier.cycleLen, id: \.self) { index in
                    Circle()
                        .fill(index < tier.cycleDone ? Huruf.gold : Huruf.tileEmpty)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

private struct CtaLabel: View {
    let title: String
    let highlighted: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(highlighted ? Huruf.bgTop : Huruf.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(highlighted ? Huruf.gold : Huruf.tileEmpty)
            )
    }
}

/// ما يُعرض قبل أول تشغيل للعبة، أو حين تتلف اللقطة
private struct EmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("حروف")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Huruf.textPrimary)
            Text("افتح اللعبة لتبدأ")
                .font(.system(size: 12))
                .foregroundColor(Huruf.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - الأحجام

private struct SmallView: View {
    let data: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(data.str("focusTitle"))
                .font(.system(size: 11))
                .foregroundColor(Huruf.textSecondary)
                .lineLimit(1)
            Text(data.str("focusAmount"))
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Huruf.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(data.str("focusStatus"))
                .font(.system(size: 12))
                .foregroundColor(Huruf.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(data.str("streak"))
                .font(.system(size: 11))
                .foregroundColor(Huruf.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let data: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(data.str("focusTitle"))
                    .font(.system(size: 12))
                    .foregroundColor(Huruf.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("💎 \(data.diamonds)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Huruf.gold)
            }
            Text(data.str("focusAmount"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Huruf.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(data.str("focusStatus"))
                .font(.system(size: 13))
                .foregroundColor(Huruf.textPrimary)
                .lineLimit(1)
            ProgressDots(tier: data.focus)
            if !data.str("focusProgress").isEmpty {
                Text(data.str("focusProgress"))
                    .font(.system(size: 11))
                    .foregroundColor(Huruf.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack {
                Text(data.str("streak"))
                    .font(.system(size: 11))
                    .foregroundColor(Huruf.textSecondary)
                    .lineLimit(1)
                Spacer()
                CtaLabel(title: data.str("cta"), highlighted: data.hasClaimable)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct TierRow: View {
    let title: String
    let status: String
    let tier: TierSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Huruf.textPrimary)
                    .lineLimit(1)
                Spacer()
                if !tier.done {
                    Text("+\(tier.coins) 💎")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Huruf.gold)
                }
            }
            ProgressDots(tier: tier)
            Text(status)
                .font(.system(size: 11))
                .foregroundColor(Huruf.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Huruf.surface))
    }
}

private struct LargeView: View {
    let data: WidgetSnapshot

    var body: some View {
        let titles = data.strings("tierTitles")
        let statuses = data.strings("tierStatuses")

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(data.str("allTitle"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Huruf.textPrimary)
                Spacer()
                Text("💎 \(data.diamonds)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Huruf.gold)
            }
            ForEach(Array(data.tiers.enumerated()), id: \.offset) { index, tier in
                // كل صفّ يفتح بطاقته هو بعينها داخل شاشة الجوائز
                let row = TierRow(
                    title: titles.indices.contains(index) ? titles[index] : "",
                    status: statuses.indices.contains(index) ? statuses[index] : "",
                    tier: tier
                )
                if let link = tier.deepLink, let url = URL(string: link) {
                    Link(destination: url) { row }
                } else {
                    row
                }
            }
            Text(data.str("stats"))
                .font(.system(size: 11))
                .foregroundColor(Huruf.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack {
                Text(data.str("streak"))
                    .font(.system(size: 11))
                    .foregroundColor(Huruf.textSecondary)
                    .lineLimit(1)
                Spacer()
                CtaLabel(title: data.str("cta"), highlighted: data.hasClaimable)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - الودجة

struct HurufWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HurufProvider.Entry

    var body: some View {
        Group {
            if let data = entry.snapshot {
                content(data)
                    // اتجاه التخطيط يتبع **لغة اللعبة** لا لغة النظام:
                    // لاعب اختار العربية على هاتف إنجليزي يجب أن يرى
                    // ودجته عربية يمينا-إلى-يسار
                    .environment(\.layoutDirection, data.rtl ? .rightToLeft : .leftToRight)
                    .widgetURL(data.deepLink.flatMap(URL.init(string:)))
            } else {
                EmptyState()
                    .environment(\.layoutDirection, .rightToLeft)
                    .widgetURL(URL(string: "huruf://rewards"))
            }
        }
        .hurufBackground()
    }

    @ViewBuilder
    private func content(_ data: WidgetSnapshot) -> some View {
        switch family {
        case .systemSmall: SmallView(data: data)
        case .systemLarge, .systemExtraLarge: LargeView(data: data)
        default: MediumView(data: data)
        }
    }
}

struct HurufWidget: Widget {
    let kind = "HurufWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HurufProvider()) { entry in
            HurufWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("حروف — المكافآت")
        .description("تابع مكافآتك اليومية والأسبوعية والشهرية وسلسلتك من شاشتك الرئيسية.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct HurufWidgetBundle: WidgetBundle {
    var body: some Widget { HurufWidget() }
}
