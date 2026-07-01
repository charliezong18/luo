import SwiftUI
import SwiftData

/// One saved Cast: the 本卦→变卦 + 释文 rendering, its timestamp, and an editable
/// 提问 + 笔记 (edits autosave through the SwiftData context).
struct CastLogDetailView: View {
    @Bindable var record: CastRecord
    @State private var showText = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HexagramPairView(hexagram: record.hexagram, showText: $showText)
                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.serif(13))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("提问（可选）", text: Binding(
                            get: { record.question ?? "" },
                            set: { record.question = $0.isEmpty ? nil : $0 }))
                        TextField("笔记（可选）", text: Binding(
                            get: { record.note ?? "" },
                            set: { record.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    }
                    .font(Theme.serif(15))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .navigationTitle("卦记")
        .navigationBarTitleDisplayMode(.inline)
    }
}
