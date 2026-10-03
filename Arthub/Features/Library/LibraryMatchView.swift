import SwiftUI
import TMDb

struct LibraryMatchView: View {
    let file: LibraryFile
    @Environment(\.dismiss) private var dismiss
    @State private var index = LibraryViewModel.shared
    @State private var query = ""
    @State private var year = ""
    @State private var isTV = false
    @State private var season = 1
    @State private var episode = 1
    @State private var sameShow = false
    @State private var movies: [TMDb.Movie] = []
    @State private var shows: [TVSeries] = []
    @State private var searching = false
    @State private var saving = false
    @State private var searched = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?

    init(file: LibraryFile, applyToShow: Bool = false) {
        self.file = file
        _sameShow = State(initialValue: applyToShow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Metadata").font(.title2.bold())
            Text(file.fileURL.lastPathComponent).foregroundStyle(.secondary).lineLimit(2)
            Picker("Media Type", selection: $isTV) {
                Text("Movie").tag(false)
                Text("TV Show").tag(true)
            }.pickerStyle(.segmented)
            HStack {
                TextField("Title", text: $query).onSubmit(search)
                TextField("Year (optional)", text: $year).frame(width: 120).onSubmit(search)
                Button("Search", action: search).disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }
            if isTV {
                Stepper("Season \(season)", value: $season, in: 0...999)
                Stepper("Episode \(episode)", value: $episode, in: 1...9999)
                Toggle("Apply show to all episodes in this show's folder", isOn: $sameShow)
                if sameShow {
                    Text("Other files keep the season and episode numbers from their names or Season folders.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if searching || saving { ProgressView() }
            if let error { Text(error).foregroundStyle(.red) }
            List {
                if isTV {
                    ForEach(shows) { show in
                        Button {
                            save {
                                try await index.match(fileID: file.id, seriesID: show.id,
                                                      season: season, episode: episode, sameShow: sameShow)
                            }
                        } label: {
                            MetadataMatchRow(title: show.name, date: show.firstAirDate, overview: show.overview)
                        }
                    }
                } else {
                    ForEach(movies) { movie in
                        Button {
                            save { try await index.match(fileID: file.id, movieID: movie.id) }
                        } label: {
                            MetadataMatchRow(title: movie.title, date: movie.releaseDate, overview: movie.overview)
                        }
                    }
                }
                if searched && !searching && movies.isEmpty && shows.isEmpty {
                    Text("No matches. Try another title or remove the year.").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(index.isScanning || index.isMatching)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        #if os(macOS)
        // A sheet sizes its window from the content. With only minimums, the wrapping file name and
        // overview rows feed width back into height and the window re-lays out forever, freezing the app.
        .frame(width: 520, height: 560)
        #else
        .frame(minWidth: 440, idealWidth: 520, minHeight: 480)
        #endif
        .disabled(saving)
        .interactiveDismissDisabled(saving)
        .onChange(of: isTV) { _, _ in
            searchTask?.cancel(); searching = false; movies = []; shows = []; searched = false
        }
        .task {
            let parsed = MediaNaming.parseVideo(file.fileURL, library: index.folderURL(for: file.library))
            if case .episode(let parsed) = parsed {
                isTV = file.movie == nil
                query = file.series?.name ?? parsed.show
                if file.series == nil { year = parsed.year.map(String.init) ?? "" }
                season = file.episode?.seasonNumber ?? parsed.season
                episode = file.episode?.episodeNumber ?? parsed.episode
            } else {
                isTV = file.series != nil
                query = file.movie?.title ?? file.series?.name ?? file.fileURL.fileName
                if file.movie == nil, file.series == nil, case .movie(let parsed) = parsed {
                    query = parsed.title
                    year = parsed.year.map(String.init) ?? ""
                }
                season = file.episode?.seasonNumber ?? 1
                episode = file.episode?.episodeNumber ?? 1
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func search() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard year.isEmpty || Int(year) != nil else {
            error = String(localized: "Enter a valid year or leave it empty.")
            return
        }
        searchTask?.cancel()
        searching = true
        error = nil
        movies = []; shows = []
        let title = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let releaseYear = Int(year)
        let searchTV = isTV
        searchTask = Task {
            do {
                if searchTV {
                    let results = try await SearchService.shared.searchTVSeries(query: title, firstAirDateYear: releaseYear).results
                    try Task.checkCancellation()
                    shows = results
                } else {
                    let results = try await SearchService.shared.searchMovies(query: title, year: releaseYear).results
                    try Task.checkCancellation()
                    movies = results
                }
            } catch {
                if Task.isCancelled { return }
                self.error = error.localizedDescription
            }
            guard !Task.isCancelled else { return }
            searched = true
            searching = false
        }
    }

    private func save(_ action: @escaping @MainActor () async throws -> Void) {
        saving = true
        error = nil
        Task {
            do {
                try await action()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

private struct MetadataMatchRow: View {
    let title: String
    let date: Date?
    let overview: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                if let date { Text(date, format: .dateTime.year()).foregroundStyle(.secondary) }
            }
            if let overview { Text(overview).font(.caption).lineLimit(3) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
