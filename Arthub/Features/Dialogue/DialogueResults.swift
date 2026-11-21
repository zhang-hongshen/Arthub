import SwiftUI

struct DialogueResults: View {
    let groups: [DialogueGroup]
    let files: [LibraryFile]
    let play: (LibraryFile, TimeInterval) -> Void

    var body: some View {
        Section("Dialogue") {
            if groups.isEmpty {
                Text("No matching dialogue").foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                DialogueFilmResults(group: group, files: files, play: play)
            }
        }
    }
}

private struct DialogueFilmResults: View {
    let group: DialogueGroup
    let files: [LibraryFile]
    let play: (LibraryFile, TimeInterval) -> Void

    var body: some View {
        DisclosureGroup {
            ForEach(group.matches) { match in
                DialogueMatchRow(match: match, available: files.contains { $0.id == match.fileID && $0.isAvailable }) {
                    if let file = files.first(where: { $0.id == match.fileID && $0.isAvailable }) {
                        play(file, max(0, match.cue.start - 2))
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.file.title).font(.headline)
                Text("\(group.matches.count) matching lines")
                    .font(.caption).foregroundStyle(.secondary)
                if let first = group.matches.first {
                    HStack(alignment: .top) {
                        Text(first.cue.start.formatted()).monospacedDigit()
                        Text(first.cue.text).lineLimit(2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DialogueMatchRow: View {
    let match: DialogueMatch
    let available: Bool
    let play: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: play) {
                HStack(alignment: .top) {
                    Label(match.cue.start.formatted(), systemImage: "play.fill")
                        .monospacedDigit()
                    Text(match.cue.text).frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .disabled(!available)
            if !match.source.isEmpty {
                Text(match.source).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Context") {
                Text(match.context.map { "\($0.start.formatted())  \($0.text)" }.joined(separator: "\n"))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
