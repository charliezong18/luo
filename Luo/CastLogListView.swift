import SwiftUI
import SwiftData

/// The Cast Log: past I Ching Casts, newest first. Rows push to detail; swipe to
/// delete one; 清空 (confirmed) deletes all.
struct CastLogListView: View {
    var onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CastRecord.timestamp, order: .reverse) private var records: [CastRecord]
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            if records.isEmpty {
                Text("尚无卦记")
                    .font(Theme.serif(18))
                    .foregroundColor(Theme.ink.opacity(0.5))
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink(value: record) { row(record) }
                            .listRowBackground(Theme.deskBackground)
                    }
                    .onDelete { offsets in
                        offsets.map { records[$0] }.forEach(modelContext.delete)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("占卜记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CastRecord.self) { CastLogDetailView(record: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .tint(Theme.cinnabar)
            }
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") { confirmClear = true }.tint(Theme.cinnabar)
                }
            }
        }
        .confirmationDialog("清空全部卦记？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清空", role: .destructive) { records.forEach(modelContext.delete) }
            Button("取消", role: .cancel) {}
        }
    }

    private func row(_ record: CastRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.hexagram.name)
                .font(Theme.serif(20))
                .foregroundColor(Theme.ink)
            Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(Theme.serif(12))
                .foregroundColor(Theme.ink.opacity(0.5))
            if let q = record.question, !q.isEmpty {
                Text(q)
                    .font(Theme.serif(13))
                    .foregroundColor(Theme.ink.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}
