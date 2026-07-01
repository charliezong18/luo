import SwiftUI

/// Minimal Ritual switcher — the two v1 Rituals reachable from one screen.
/// A real home is a later concern; this just makes both entries exist.
struct RootView: View {
    private enum Ritual { case coin, iching }
    @State private var ritual: Ritual?

    var body: some View {
        switch ritual {
        case .coin:
            ritualContainer { CoinRitualView() }
        case .iching:
            ritualContainer { IChingRitualView() }
        case nil:
            picker
        }
    }

    private var picker: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("落")
                    .font(Theme.serif(64, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .padding(.bottom, 12)
                entryButton("六爻") { ritual = .iching }
                entryButton("掷币") { ritual = .coin }
            }
        }
    }

    private func entryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)
                .frame(width: 200, height: 64)
                .overlay(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func ritualContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            content()
            Button(action: { ritual = nil }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.ink.opacity(0.7))
                    .padding(12)
            }
            .padding(.top, 8)
            .padding(.leading, 8)
        }
    }
}

#Preview {
    RootView()
}
