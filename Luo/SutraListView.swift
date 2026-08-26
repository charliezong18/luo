import SwiftUI

/// 读经 — the 64 hexagrams as a table of contents. This is the app's reading
/// surface: the canonical 周易 text is reachable here without casting anything.
struct SutraListView: View {
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            List {
                ForEach(KingWenTable.allInKingWenOrder, id: \.number) { entry in
                    NavigationLink(value: entry.number) { row(entry) }
                        .listRowBackground(Theme.deskBackground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("六十四卦")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Int.self) { SutraDetailView(number: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.ink.opacity(0.8))
                }
            }
        }
    }

    private func row(_ entry: (number: Int, name: String, bits: Int)) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(entry.number)")
                .font(Theme.serif(13))
                .foregroundColor(Theme.ink.opacity(0.4))
                .frame(width: 26, alignment: .trailing)
            Text(entry.name)
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.ink)
            Text(ZhouYiCorpus.text(forNumber: entry.number)?.guaCi ?? "")
                .font(Theme.serif(14))
                .foregroundColor(Theme.ink.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
