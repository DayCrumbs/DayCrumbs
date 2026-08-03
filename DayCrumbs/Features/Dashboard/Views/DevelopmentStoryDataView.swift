#if DEBUG
import SwiftData
import SwiftUI

struct DevelopmentStoryDataView: View {
    @State private var viewModel: DevelopmentStoryDataViewModel
    @State private var rowPendingDeletion: DevelopmentStoryDataRow?

    @MainActor
    init(repository: any DevelopmentStoryDataRepositoryProtocol) {
        _viewModel = State(
            initialValue: DevelopmentStoryDataViewModel(
                repository: repository
            )
        )
    }

    @MainActor
    init() {
        self.init(repository: ShowcaseDevelopmentStoryDataRepository())
    }

    @MainActor
    init(modelContext: ModelContext) {
        self.init(repository: ShowcaseDevelopmentStoryDataRepository())
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading story data…")

            case .loaded where viewModel.rows.isEmpty:
                ContentUnavailableView(
                    "No Story Data",
                    systemImage: "tablecells",
                    description: Text("StoryEntry does not contain any rows.")
                )

            case .loaded:
                storyTable

            case .failed(let message):
                ContentUnavailableView(
                    "Could Not Load Story Data",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .background(AppColour.bgPutih.ignoresSafeArea())
        .navigationTitle("StoryEntry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            "Delete Story Entry?",
            isPresented: deletionConfirmationIsPresented,
            titleVisibility: .visible,
            presenting: rowPendingDeletion
        ) { row in
            Button("Delete", role: .destructive) {
                viewModel.deleteRow(id: row.id)
                rowPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                rowPendingDeletion = nil
            }
        } message: { row in
            Text("This permanently deletes the \(row.session) entry recorded at \(row.recordedAt).")
        }
        .alert(
            "Could Not Delete Story Entry",
            isPresented: deletionErrorIsPresented
        ) {
            Button("OK") {
                viewModel.clearDeletionError()
            }
        } message: {
            Text(viewModel.deletionErrorMessage ?? "An unknown error occurred.")
        }
    }

    private var storyTable: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    tableRow(
                        values: [
                            "recordedAt",
                            "session",
                            "place",
                            "activity",
                            "mood",
                            "afterActivityNote",
                            "endOfDayReflection"
                        ],
                        isHeader: true
                    )

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                                tableRow(
                                    values: [
                                        row.recordedAt,
                                        row.session,
                                        row.place,
                                        row.activity,
                                        row.mood,
                                        row.afterActivityNote,
                                        row.endOfDayReflection
                                    ],
                                    isHeader: false,
                                    row: row
                                )
                                .background(
                                    index.isMultiple(of: 2)
                                    ? Color.clear
                                    : Color.primary.opacity(0.04)
                                )
                            }
                        }
                    }
                    .frame(height: max(0, geometry.size.height - 44))
                }
                .overlay {
                    Rectangle()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        .accessibilityHidden(true)
                }
                .padding(16)
            }
        }
        .accessibilityLabel("StoryEntry development data table")
    }

    private func tableRow(
        values: [String],
        isHeader: Bool,
        row: DevelopmentStoryDataRow? = nil
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(
                        isHeader
                        ? .system(.caption, design: .monospaced).bold()
                        : .system(.caption, design: .monospaced)
                    )
                    .foregroundStyle(isHeader ? AppColour.txtCoklat : .primary)
                    .lineLimit(isHeader ? 1 : 3)
                    .frame(width: columnWidth(at: index), alignment: .leading)
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 8)
                    .overlay(alignment: .trailing) {
                        Divider()
                            .accessibilityHidden(true)
                    }
            }

            Group {
                if isHeader {
                    Text("actions")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(AppColour.txtCoklat)
                } else if let row {
                    Button(role: .destructive) {
                        rowPendingDeletion = row
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(viewModel.deletingRowID != nil)
                    .accessibilityLabel("Delete \(row.session) story entry")
                    .accessibilityHint("Asks for confirmation before deleting this row.")
                }
            }
            .frame(width: 88)
            .frame(minHeight: 44)
        }
        .background(isHeader ? AppColour.btnKuning.opacity(0.45) : Color.clear)
        .overlay(alignment: .bottom) {
            Divider()
                .accessibilityHidden(true)
        }
    }

    private var deletionConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { rowPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    rowPendingDeletion = nil
                }
            }
        )
    }

    private var deletionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.deletionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearDeletionError()
                }
            }
        )
    }

    private func columnWidth(at index: Int) -> CGFloat {
        switch index {
        case 0:
            180
        case 5, 6:
            260
        default:
            130
        }
    }
}
#endif
