import SwiftUI

/// 读经 — the 64 hexagrams as a table of contents. This is the app's reading
/// surface: the canonical 周易 text is reachable here without casting anything.
/// Two views of the same 64: by 名称 (King Wen order, with the 卦辞 opening) or
/// by 卦象 (the printed 查卦表, upper trigram across, lower trigram down), plus
/// 查卦 for entering six lines by hand. Pushed from the home stack, so the
/// system back button / edge swipe handle leaving.
struct SutraListView: View {
    enum Mode: String { case names, shapes }
    @AppStorage("sutra.viewMode") private var modeRaw = Mode.names.rawValue
    private var mode: Mode { Mode(rawValue: modeRaw) ?? .names }

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            switch mode {
            case .names:  nameList
            case .shapes: HexagramGridView()
            }
        }
        .navigationTitle("六十四卦")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("视图", selection: $modeRaw) {
                    Text("名称").tag(Mode.names.rawValue)
                    Text("卦象").tag(Mode.shapes.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: RootView.Route.lookup) {
                    Text("查卦").font(Theme.serif(16))
                }
            }
        }
    }

    private var nameList: some View {
        List {
            ForEach(KingWenTable.allInKingWenOrder, id: \.number) { entry in
                NavigationLink(value: entry.number) { row(entry) }
                    .listRowBackground(Theme.deskBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
