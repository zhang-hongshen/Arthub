import SwiftUI

struct MovieMetadataSearchView: View {
    @Bindable var movie: Movie
    @State private var index = LibraryViewModel.shared

    var body: some View {
        if let file = index.files.first(where: { $0.id == movie.id }) {
            LibraryMatchView(file: file)
        } else {
            MissingFileSheet()
        }
    }
}

/// Fallback for a metadata sheet whose file left the library; it still needs a way out of the sheet.
struct MissingFileSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            ContentUnavailableView("File Missing", systemImage: "questionmark.folder")
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 360, height: 240)
        #endif
    }
}
