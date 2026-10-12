//
//  String+.swift
//  Arthub
//
//  Created by 张鸿燊 on 14/2/2024.
//
import Foundation

// MARK: Matching Names

extension String {

    /// For comparing titles regardless of case, width, spacing, punctuation, or traditional and simplified characters.
    var matchKey: String {
        String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// Whether two artist fields name the same artist, the words of one all being in the other:
    /// `周杰倫 Jay Chou` is 周杰伦, Jay Chou and `Jay Chou (周杰倫)`.
    func isSameArtist(as other: String) -> Bool {
        let words = artistWords, otherWords = other.artistWords
        return !words.isEmpty && !otherWords.isEmpty && (words.isSubset(of: otherWords) || otherWords.isSubset(of: words))
    }

    private var folded: String {
        (applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? self)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Chinese characters apart from the letters next to them, as in `周杰倫Jay`.
    private var artistWords: Set<String> {
        Set(folded.matches(of: /\p{Han}+|[^\p{Han}\W_]+/).map { String($0.output) })
    }
}
