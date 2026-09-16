import PassKit
import SwiftUI

struct IumrahAddToWalletButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

    final class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func tapped() {
            action()
        }
    }
}

struct IumrahAddPassesView: UIViewControllerRepresentable {
    let pass: PKPass
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            return UIViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            isPresented = false
        }
    }
}
