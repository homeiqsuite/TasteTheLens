import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Home Screen Widget (Last Recipe)

struct LastRecipeEntry: TimelineEntry {
    let date: Date
    let dishName: String
    let thumbnailData: Data?
    let createdAt: Date?
}

struct LastRecipeProvider: TimelineProvider {
    private static let suiteName = "group.com.eightgates.TasteTheLens"

    func placeholder(in context: Context) -> LastRecipeEntry {
        LastRecipeEntry(date: .now, dishName: "Syntax of Zest", thumbnailData: nil, createdAt: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastRecipeEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastRecipeEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadEntry() -> LastRecipeEntry {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else {
            return placeholder(in: .init())
        }

        let dishName = defaults.string(forKey: "lastRecipeDishName") ?? "No recipes yet"
        let thumbnailData = defaults.data(forKey: "lastRecipeThumbnail")
        let createdInterval = defaults.double(forKey: "lastRecipeCreatedAt")
        let createdAt = createdInterval > 0 ? Date(timeIntervalSince1970: createdInterval) : nil

        return LastRecipeEntry(date: .now, dishName: dishName, thumbnailData: thumbnailData, createdAt: createdAt)
    }
}

struct LastRecipeWidgetView: View {
    let entry: LastRecipeEntry

    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)
    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)

    var body: some View {
        ZStack {
            bg

            VStack(alignment: .leading, spacing: 6) {
                if let data = entry.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text(entry.dishName)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(gold)
                    .lineLimit(2)

                if let createdAt = entry.createdAt {
                    Text(createdAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

struct TasteTheLensWidget: Widget {
    let kind = "TasteTheLensWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastRecipeProvider()) { entry in
            LastRecipeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.051, green: 0.051, blue: 0.059)
                }
        }
        .configurationDisplayName("Last Recipe")
        .description("Shows your most recently generated recipe.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Live Activity UI

struct GenerationLiveActivityView: View {
    let context: ActivityViewContext<GenerationActivityAttributes>

    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 20))
                .foregroundStyle(gold)

            VStack(alignment: .leading, spacing: 4) {
                Text("Taste The Lens")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)

                Text(context.state.statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))

                ProgressView(value: context.state.progress)
                    .tint(gold)
            }

            Spacer()

            Text(context.state.phase)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(gold.opacity(0.8))
        }
        .padding(16)
    }
}

struct TasteTheLensWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasteTheLensWidget()

        if #available(iOSApplicationExtension 16.2, *) {
            GenerationActivityWidget()
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
struct GenerationActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenerationActivityAttributes.self) { context in
            GenerationLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.051, green: 0.051, blue: 0.059))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color(red: 0.788, green: 0.659, blue: 0.298))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.statusMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phase)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color(red: 0.788, green: 0.659, blue: 0.298))
            } compactTrailing: {
                ProgressView(value: context.state.progress)
                    .tint(Color(red: 0.788, green: 0.659, blue: 0.298))
                    .frame(width: 36)
            } minimal: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color(red: 0.788, green: 0.659, blue: 0.298))
            }
        }
    }
}
