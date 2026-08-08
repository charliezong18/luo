import SwiftUI
import SceneKit
import SwiftData

/// 六爻 三钱法 Ritual screen. Scene (3 coins) fills the top; the cast Yao stack
/// grows bottom-up as each Throw settles; one cinnabar 掷 button advances. On the
/// 6th Yao the 本卦 (卦号 + 卦名 + 6-Yao glyph, 动爻 marked) fades in. 再占 resets.
struct IChingRitualView: View {
    @StateObject private var vm = IChingRitualViewModel()
    @State private var showText = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            // .rendersContinuously: SceneKit physics steps with the render loop;
            // a paused loop swallows shake impulses until a tap wakes the view.
            SceneView(scene: vm.scene.scene, options: [.rendersContinuously], delegate: vm.scene)
                .ignoresSafeArea()
                .opacity(sceneOpacity)

            VStack(spacing: 0) {
                hint
                latestThrowReadout
                if case .complete(let hex) = vm.state {
                    // Scroll the (now long) 卦辞/爻辞/白话 so it can't push 再占
                    // off-screen; the button stays pinned at the bottom.
                    ScrollView(showsIndicators: false) {
                        hexagramResult(hex)
                            .padding(.vertical, 16)
                    }
                } else {
                    tallyRow
                    Spacer()
                }
                castButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.state)
        .animation(.easeInOut(duration: 0.35), value: vm.castYao.count)
        .onChange(of: vm.state) { _, newState in
            if case .complete(let hex) = newState {
                modelContext.insert(CastRecord(from: hex, at: Date()))
            }
        }
        .onAppear { vm.startMotion() }
        .onDisappear { vm.stopMotion() }
    }

    /// Dim the 3D desk once the 本卦 lands so the 卦辞/爻辞 reads as the focus,
    /// not the coins behind it. Animated by the ZStack's `.animation(value:)`.
    private var sceneOpacity: Double {
        if case .complete = vm.state { return 0.22 }
        return 1
    }

    private var hint: some View {
        Text(hintText)
            .font(Theme.serif(17))
            .foregroundColor(Theme.ink.opacity(vm.castYao.isEmpty ? 0.6 : 0.3))
    }

    private var hintText: String {
        switch vm.state {
        case .complete: return " "
        default:        return vm.castYao.isEmpty ? "心中默念所问" : "第 \(vm.castYao.count + 1) 爻"
        }
    }

    /// The just-settled Throw's 3 coin faces spelled out (e.g. 阳 阳 阴), under the
    /// hint — the reading comes to the user instead of squinting at the 钱文.
    /// Hidden while coins fly and once the 本卦 takes over the screen.
    private var latestThrowReadout: some View {
        Group {
            if vm.state == .idle, let faces = vm.castFaces.last {
                HStack(spacing: 8) {
                    ForEach(Array(faces.enumerated()), id: \.offset) { _, face in
                        Text(Yinyang(face).glyph)
                            .font(Theme.serif(15))
                            .foregroundColor(Theme.ink.opacity(0.7))
                    }
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
    }

    /// In-progress tally: a compact horizontal row read left→right in cast order
    /// (throw 1 … throw 6), small and dim, sitting just under the hint at the top
    /// so it never overlaps the coins in the center. 动爻 tinted cinnabar; each
    /// Yao carries its Throw's 3 coin faces as a tiny 阳/阴 caption.
    private var tallyRow: some View {
        HStack(spacing: 14) {
            ForEach(Array(vm.castYao.enumerated()), id: \.offset) { i, yao in
                VStack(spacing: 2) {
                    Text(yao.glyph)
                        .font(Theme.serif(28))
                        .foregroundColor((yao.isChanging ? Theme.cinnabar : Theme.ink).opacity(0.7))
                    if i < vm.castFaces.count {
                        Text(vm.castFaces[i].map { Yinyang($0).glyph }.joined())
                            .font(Theme.serif(10))
                            .foregroundColor(Theme.ink.opacity(0.45))
                    }
                }
            }
        }
        .frame(height: 52)
        .padding(.top, 6)
    }

    private func hexagramResult(_ hex: Hexagram) -> some View {
        HexagramPairView(hexagram: hex, showText: $showText)
            .transition(.opacity)
    }

    private var castButton: some View {
        Button(action: buttonAction) {
            Text(buttonLabel)
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.deskBackground)
                .frame(width: 120, height: 52)
                .background(Theme.cinnabar)
                .clipShape(Capsule())
                .opacity(vm.state == .casting ? 0.4 : 1)
        }
        .disabled(vm.state == .casting)
    }

    private var buttonLabel: String {
        if vm.isComplete { return "再占" }
        return "掷"
    }

    private func buttonAction() {
        if vm.isComplete {
            showText = false   // each new Cast starts with 释文 collapsed
            vm.reset()
        } else {
            vm.cast()
        }
    }
}

#Preview {
    IChingRitualView()
}
