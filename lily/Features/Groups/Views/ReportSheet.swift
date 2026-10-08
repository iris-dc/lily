import SwiftUI

/// Reports what the sheet was opened for (a tournament today): the reason as an inline list, an optional comment and
/// Send in the bar; once the report went out the sheet thanks the caller and Done closes it. Mounts its own popup,
/// since a sheet is drawn above the root's.
struct ReportSheet: View {
    @State private var viewModel: ReportViewModel
    private let errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Moderation

    init(viewModel: ReportViewModel, errorCenter: ErrorCenter) {
        _viewModel = State(initialValue: viewModel)
        self.errorCenter = errorCenter
    }

    var body: some View {
        NavigationStack {
            ContentScreen {
                if viewModel.isSubmitted {
                    EmptyStateView(symbolName: DesignTokens.Symbols.report, title: Copy.thanks, message: Copy.thanksMessage)
                } else {
                    form
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.medium, .large])
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSubmitting)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
    }

    private var form: some View {
        Form {
            Section(Copy.reasonTitle) {
                Picker(Copy.reasonTitle, selection: $viewModel.reason) {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Text(reason.displayName).tag(Optional(reason))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                TextField(Copy.commentPlaceholder, text: $viewModel.comment, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(DesignTokens.Layout.multilineFieldLines)
                    .accessibilityIdentifier(AccessibilityIdentifiers.reportComment)
            }
        }
        .scrollContentBackground(.hidden)
        .readableColumn()
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if viewModel.isSubmitted {
            ToolbarItem(placement: .confirmationAction) {
                Button(Copy.done) { dismiss() }
                    .accessibilityIdentifier(AccessibilityIdentifiers.reportDone)
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button(AppBranding.Events.Create.cancel, role: .cancel) { dismiss() }
                    .disabled(viewModel.isSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                DraftSubmitButton(title: Copy.send, isSubmitting: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                    await viewModel.submit()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.reportSubmit)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    ReportSheet(viewModel: dependencies.makeReportViewModel(for: .tournament(id: MockTournamentFixtures.tableTennisID),
                                                            title: AppBranding.Tournaments.report),
                errorCenter: dependencies.errorCenter)
}
