import SwiftUI
import UIKit

/// UIKit disables `interactivePopGestureRecognizer` on any screen that hides
/// its navigation bar. The Ritual screens hide the bar (the SceneKit desk owns
/// the whole screen), so without this the standard left-edge swipe-back dies
/// there. Dropping this view into a screen's `.background` finds the enclosing
/// UINavigationController and hands the recognizer a delegate that allows the
/// swipe exactly when there is something to pop — the one rule the stock
/// delegate adds on top of the bar-visibility check we want to drop.
struct InteractivePopGestureEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let nav = next as? UINavigationController {
                    PopGestureDelegate.install(on: nav)
                    return
                }
                responder = next
            }
        }
    }
}

/// Long-lived delegate (never deallocated, so the recognizer can never be left
/// with a nil delegate — a nil delegate lets a swipe begin on the root screen,
/// which wedges UINavigationController in a half-popped state).
final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureDelegate()

    static func install(on nav: UINavigationController) {
        guard let pop = nav.interactivePopGestureRecognizer, pop.delegate !== shared else { return }
        pop.delegate = shared
        pop.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = gestureRecognizer.view
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
            }
            responder = next
        }
        return false
    }
}
