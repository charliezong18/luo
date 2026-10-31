import SwiftUI

/// Home: the four entries. Each is a real NavigationStack push, so every screen
/// gets the system back button and the left-edge swipe-back gesture for free.
/// (The old @State switcher swapped views in place — there was no navigation
/// transition at all, so the edge swipe had nothing to pop.)
struct RootView: View {
    enum Route: Hashable { case sutra, iching, coin, castLog, lookup }

    var body: some View {
        NavigationStack {
            picker
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .sutra:   SutraListView()
                    case .lookup:  HexagramLookupView()
                    case .castLog: CastLogListView()
                    case .iching:  RitualScreen { IChingRitualView() }
                    case .coin:    RitualScreen { CoinRitualView() }
                    }
                }
                // One registration for the whole stack: the 读经 list, the 卦象
                // grid and the 按卦象查 screen all push a King Wen number.
                .navigationDestination(for: Int.self) { SutraDetailView(number: $0) }
        }
        .tint(Theme.ink)
        // Dusk Desk is dark-only; this keeps system chrome (back buttons, bar
        // titles, dialogs) legible on the desk regardless of the device setting.
        .preferredColorScheme(.dark)
    }

    private var picker: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("落")
                    .font(Theme.serif(64, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .padding(.bottom, 12)
                entryLink("读经", to: .sutra)
                entryLink("六爻", to: .iching)
                entryLink("掷币", to: .coin)
                entryLink("卦例记录", to: .castLog)
                // Frames the app plainly as classical-text reading, not prediction.
                Text("古经原文与白话对照，仅供阅读与自省")
                    .font(Theme.serif(13))
                    .foregroundColor(Theme.ink.opacity(0.35))
                    .padding(.top, 20)
            }
        }
    }

    private func entryLink(_ title: String, to route: Route) -> some View {
        NavigationLink(value: route) {
            Text(title)
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)
                .frame(width: 200, height: 64)
                .overlay(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1))
        }
    }
}

/// Full-screen Ritual wrapper: the 3D desk owns the whole screen, so the
/// navigation bar stays hidden and the quiet chevron the Rituals always had
/// pops the stack instead. Hiding the bar makes UIKit switch the edge-swipe
/// gesture off; `InteractivePopGestureEnabler` switches it back on.
private struct RitualScreen<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.ink.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Theme.deskBackground.opacity(0.6), in: Circle())
                    .overlay(Circle().stroke(Theme.ink.opacity(0.18), lineWidth: 1))
            }
            .accessibilityLabel("返回")
            .padding(.top, 8)
            .padding(.leading, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(InteractivePopGestureEnabler())
    }
}

#Preview {
    RootView()
}
