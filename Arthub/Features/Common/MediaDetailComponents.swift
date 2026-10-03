//
//  MediaDetailComponents.swift
//  Arthub
//
//  Building blocks for the Apple TV style movie / TV show detail pages:
//  a full-bleed hero, horizontal shelves, round cast cards, an About card
//  and an Information grid.
//

import SwiftUI

enum MediaDetail {
    static let horizontalPadding: CGFloat = 40
    static let sectionSpacing: CGFloat = 36
    static let stillAspectRatio: CGFloat = 16 / 9
    /// Apple TV detail pages are always dark.
    static let background = Color(white: 0.07)

    static func heroHeight(for size: CGSize) -> CGFloat {
        max(min(size.height * 0.82, size.width / MediaDetail.stillAspectRatio * 1.15), 380)
    }

    /// "2 hr 10 min" style, dropping seconds.
    static func runtime(_ interval: TimeInterval) -> String {
        let minutes = (interval / 60).rounded() * 60
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: minutes) ?? ""
    }

    static func languageName(_ code: String?) -> String? {
        guard let code else { return nil }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    static func regionName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

// MARK: Page

/// Scroll container shared by detail pages: hero on top, sections below, dark background.
struct MediaDetailPage<Hero: View, Content: View>: View {

    @ViewBuilder var hero: (CGSize) -> Hero
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: MediaDetail.sectionSpacing) {
                    hero(proxy.size)
                    content()
                }
                .padding(.bottom, MediaDetail.sectionSpacing)
            }
            .scrollIndicators(.hidden)
        }
        .background(MediaDetail.background)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: Hero

struct MediaHeroView<Title: View, Actions: View>: View {

    var backdropURL: URL?
    var size: CGSize
    var metadata: [String] = []
    var badges: [String] = []
    var overview: String?
    var credits: [(label: LocalizedStringKey, value: String)] = []
    @ViewBuilder var title: () -> Title
    @ViewBuilder var actions: () -> Actions

    private var isWide: Bool { size.width >= 720 }

    var body: some View {
        let height = MediaDetail.heroHeight(for: size)
        ArtworkImage(url: backdropURL, aspectRatio: MediaDetail.stillAspectRatio) {
            MediaDetail.background
        }
        .frame(width: size.width, height: height)
        .clipped()
        .overlay {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.25),
                .init(color: MediaDetail.background.opacity(0.75), location: 0.65),
                .init(color: MediaDetail.background, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .overlay {
            if isWide {
                LinearGradient(colors: [MediaDetail.background.opacity(0.6), .clear],
                               startPoint: .leading, endPoint: .center)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Group {
                if isWide {
                    HStack(alignment: .bottom, spacing: 48) {
                        LeadingColumn()
                            .frame(width: size.width * 0.42, alignment: .leading)
                        TrailingColumn()
                            .frame(maxWidth: 520, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        LeadingColumn()
                        TrailingColumn()
                    }
                }
            }
            .padding(.horizontal, MediaDetail.horizontalPadding)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func LeadingColumn() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            title()
            MediaMetadataLine(items: metadata, badges: badges)
            HStack(spacing: 12) { actions() }
        }
    }

    @ViewBuilder
    private func TrailingColumn() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let overview, !overview.isEmpty {
                Text(verbatim: overview)
                    .font(.body)
                    .lineLimit(isWide ? 5 : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(credits.indices, id: \.self) { index in
                let credit = credits[index]
                Text("\(Text(credit.label).foregroundStyle(.primary)) \(credit.value)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// "Drama · 2023 · 2 hr 10 min  [★ 7.8] [18+]"
struct MediaMetadataLine: View {
    var items: [String]
    var badges: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: items.filter { !$0.isEmpty }.joined(separator: " · "))
                .lineLimit(1)
            ForEach(badges, id: \.self) { badge in
                Text(verbatim: badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary, lineWidth: 1))
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

/// Title text used when a logo is missing.
struct MediaTitleText: View {
    var title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 44, weight: .heavy))
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .shadow(radius: 8)
    }
}

/// Small bar with "42 min left" shown under the play button.
struct MediaRemainingView: View {
    var progress: Double
    var duration: TimeInterval

    var body: some View {
        if progress > 0, progress < 1 {
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.primary)
                    .frame(width: 80)
                Text("\(MediaDetail.runtime(duration * (1 - progress))) left")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Buttons

/// Big light rounded button, the "Play" button on Apple TV.
struct MediaPlayButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .frame(minWidth: 160)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Round translucent button next to the play button.
struct MediaCircleButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: Shelf

/// A titled, horizontally scrolling row.
struct MediaShelf<Header: View, Content: View>: View {

    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header()
                .padding(.horizontal, MediaDetail.horizontalPadding)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 20) {
                    content()
                }
                .padding(.horizontal, MediaDetail.horizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
    }
}

extension MediaShelf where Header == MediaSectionHeader {
    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.header = { MediaSectionHeader(title: title) }
        self.content = content
    }
}

struct MediaSectionHeader: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title).font(.title2.bold())
    }
}

// MARK: Cast & Crew

struct MediaPersonCard: View {
    var name: String
    var role: String
    var profilePath: URL?

    var body: some View {
        VStack(spacing: 6) {
            ArtworkImage(url: profilePath, aspectRatio: Portrait.aspectRatio) {
                DefaultAvatarView()
            }
            .frame(width: 110, height: 110)
            .clipShape(Circle())
            .padding(.bottom, 4)

            Text(verbatim: name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(verbatim: role)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
        .frame(width: 120)
        .contentShape(Rectangle())
    }
}

// MARK: About

struct MediaAboutCard: View {
    var title: String
    var subtitle: String?
    var tagline: String?
    var overview: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.title3.bold())
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            if let tagline, !tagline.isEmpty {
                Text(verbatim: tagline)
                    .font(.callout.italic())
            }
            if let overview, !overview.isEmpty {
                Text(verbatim: overview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, MediaDetail.horizontalPadding)
    }
}

// MARK: Information

struct MediaInfoItem: Identifiable {
    let id = UUID()
    var label: LocalizedStringKey
    var value: String
}

struct MediaInfoSection: View {
    var title: LocalizedStringKey = "Information"
    var items: [MediaInfoItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                MediaSectionHeader(title: title)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 320),
                                             spacing: 24, alignment: .topLeading)],
                          alignment: .leading, spacing: 18) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: item.value)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, MediaDetail.horizontalPadding)
        }
    }
}

extension Array where Element == MediaInfoItem {
    /// Appends only when there is something to show.
    mutating func append(_ label: LocalizedStringKey, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        append(MediaInfoItem(label: label, value: value))
    }
}
