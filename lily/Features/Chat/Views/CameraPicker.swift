import SwiftUI
import UIKit

/// The system camera (`UIImagePickerController`) for the attach menu; `isAvailable` is false on the simulator and on
/// a device without one, and the menu hides the item then. The usage text is `INFOPLIST_KEY_NSCameraUsageDescription`.
struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick) { dismiss() }
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (UIImage) -> Void
        private let dismiss: () -> Void

        init(onPick: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onPick(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
