import SwiftUI

/// Aisle-grouped, checkable grocery list for a meal plan. Check state is
/// ephemeral (view-local) — it resets when the view is dismissed.
struct GroceryListView: View {
    let plan: MealPlan
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var checked: Set<String> = []

    private var chefTheme: ChefTheme {
        ChefPersonality(rawValue: plan.chefPersonality ?? selectedChef)?.theme ?? ChefPersonality.defaultChef.theme
    }

    /// Items grouped by aisle, preserving a sensible aisle order.
    private var groupedByAisle: [(aisle: String, items: [GroceryItem])] {
        let grouped = Dictionary(grouping: plan.groceryList, by: { $0.aisle })
        return grouped.keys.sorted().map { aisle in
            (aisle, grouped[aisle]!.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(groupedByAisle, id: \.aisle) { group in
                    aisleSection(aisle: group.aisle, items: group.items)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .navigationTitle("Grocery List")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aisleSection(aisle: String, items: [GroceryItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(aisle)
                .font(.dsSection)
                .foregroundStyle(chefTheme.textPrimary)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item)
                    if item.id != items.last?.id {
                        Rectangle()
                            .fill(chefTheme.cardBorder.opacity(0.6))
                            .frame(height: DS.Stroke.hairline)
                            .padding(.leading, 34)
                    }
                }
            }
            .minimalCard(chefTheme, padding: EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        }
    }

    private func itemRow(_ item: GroceryItem) -> some View {
        let isChecked = checked.contains(item.id)
        return Button {
            HapticManager.light()
            if isChecked { checked.remove(item.id) } else { checked.insert(item.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isChecked ? chefTheme.accent : chefTheme.textQuaternary)
                Text(item.name)
                    .font(.dsBody)
                    .foregroundStyle(isChecked ? chefTheme.textTertiary : chefTheme.textPrimary)
                    .strikethrough(isChecked)
                Spacer()
                Text(item.quantity)
                    .font(.dsCaption)
                    .foregroundStyle(chefTheme.textTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
