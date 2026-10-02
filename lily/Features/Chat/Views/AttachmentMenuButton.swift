import PhotosUI
import SwiftUI

/// The "+" leading the composer's field: a menu with Photo library (the system picker for pictures and videos, which
/// needs no permission), Camera (hidden where there is none, the simulator included) and File (the files importer,
/// any type, several at once). Under `-mock-attachment-picker` the items add the bundled photo, clip and document at
/// once, because XCUITest cannot drive the out-of-process pickers; Camera then shows without a camera. Disabled once
/// the message holds `maxPerMessage` items; the composer hides it altogether while the backend takes no attachments.
struct AttachmentMenuButton: View {
    let attachments: AttachmentComposerModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsPhotoPicker = false
    @State private var showsCamera = false
    @State private var showsFileImporter = false

    private typealias Copy = AppBranding.Chat.Attachments

    var body: some View {
        Menu {
            Button(Copy.photoLibrary, systemImage: DesignTokens.Symbols.photoLibrary, action: pickPhotos)
            if CameraPicker.isAvailable || attachments.picksWithoutPicker {
                Button(Copy.camera, systemImage: DesignTokens.Symbols.camera, action: openCamera)
            }
            Button(Copy.file, systemImage: DesignTokens.Symbols.file, action: pickFiles)
        } label: {
            Image(systemName: DesignTokens.Symbols.attach)
        }
        .menuStyle(.button)
        .lilyGlassIconButton()
        .disabled(attachments.isFull)
        .accessibilityLabel(Copy.attach)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatAttach)
        .photosPicker(isPresented: $showsPhotoPicker,
                      selection: $pickerItems,
                      maxSelectionCount: max(attachments.remainingSlots, 1),
                      matching: .any(of: [.images, .videos]))
        .onChange(of: pickerItems) { takePickedItems() }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { attachments.add(cameraImage: $0) }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) {
            takePickedFiles($0)
        }
    }

    private func pickPhotos() {
        if attachments.picksWithoutPicker {
            attachments.addPhotoWithoutPicker()
        } else {
            showsPhotoPicker = true
        }
    }

    private func openCamera() {
        if attachments.picksWithoutPicker {
            attachments.addVideoWithoutPicker()
        } else {
            showsCamera = true
        }
    }

    private func pickFiles() {
        if attachments.picksWithoutPicker {
            attachments.addFileWithoutPicker()
        } else {
            showsFileImporter = true
        }
    }

    /// The picker's selection is taken once and cleared, so the next pick starts empty.
    private func takePickedItems() {
        guard !pickerItems.isEmpty else { return }
        let items = pickerItems
        pickerItems = []
        Task { await attachments.add(pickerItems: items) }
    }

    private func takePickedFiles(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls): attachments.add(fileURLs: urls)
        case .failure(let error): attachments.noteFileImportFailure(error)
        }
    }
}
