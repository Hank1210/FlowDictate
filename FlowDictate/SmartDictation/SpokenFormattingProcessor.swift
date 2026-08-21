import Foundation

nonisolated struct SpokenFormattingProcessor: Sendable {
    private struct Command: Sendable {
        let phrases: [String]
        let output: String
    }

    func process(_ text: String, language: String?) -> TextTransformationResult {
        guard !text.isEmpty else { return TextTransformationResult(text: text, replacementCount: 0) }

        var protected: [String: String] = [:]
        var working = protectURLsAndEmails(in: text, protected: &protected)
        working = protectLiteralCommands(in: working, language: language, protected: &protected)
        var count = 0

        for command in commands(language: language).sorted(by: longestPhraseFirst) {
            for phrase in command.phrases.sorted(by: { $0.count > $1.count }) {
                let pattern = "(?<![\\p{L}\\p{N}_])\(NSRegularExpression.escapedPattern(for: phrase))(?![\\p{L}\\p{N}_])"
                guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let range = NSRange(working.startIndex..., in: working)
                let matches = expression.matches(in: working, range: range)
                guard !matches.isEmpty else { continue }
                count += matches.count
                working = expression.stringByReplacingMatches(
                    in: working,
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: command.output)
                )
            }
        }

        working = normalizeSpacing(in: working)
        for (placeholder, value) in protected {
            working = working.replacingOccurrences(of: placeholder, with: value)
        }
        return TextTransformationResult(text: working.trimmingCharacters(in: .whitespaces), replacementCount: count)
    }

    private func commands(language: String?) -> [Command] {
        let german = language == "de"
        let english = language == "en"
        func phrases(_ de: String, _ en: String) -> [String] {
            if german { return [de] }
            if english { return [en] }
            return [de, en]
        }
        return [
            Command(phrases: phrases("neuer Absatz", "new paragraph"), output: "\n\n"),
            Command(phrases: phrases("neue Zeile", "new line"), output: "\n"),
            Command(phrases: phrases("Aufzählung", "bullet point"), output: "\n•"),
            Command(phrases: phrases("Klammer auf", "open parenthesis"), output: "("),
            Command(phrases: phrases("Klammer zu", "close parenthesis"), output: ")"),
            Command(phrases: phrases("Fragezeichen", "question mark"), output: "?"),
            Command(phrases: phrases("Ausrufezeichen", "exclamation mark"), output: "!"),
            Command(phrases: phrases("Komma", "comma"), output: ","),
            Command(phrases: phrases("Punkt", "period"), output: ".")
        ]
    }

    private func longestPhraseFirst(_ lhs: Command, _ rhs: Command) -> Bool {
        lhs.phrases.map(\.count).max() ?? 0 > rhs.phrases.map(\.count).max() ?? 0
    }

    private func protectURLsAndEmails(in text: String, protected: inout [String: String]) -> String {
        protect(pattern: #"https?://\S+|\b[^\s@]+@[^\s@]+\.[^\s@]+\b"#, in: text, protected: &protected) { $0 }
    }

    private func protectLiteralCommands(
        in text: String,
        language: String?,
        protected: inout [String: String]
    ) -> String {
        let phrases = commands(language: language).flatMap(\.phrases)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
        guard !phrases.isEmpty else { return text }
        let escape = language == "de" ? "wörtlich" : language == "en" ? "literal" : "(?:wörtlich|literal)"
        return protect(
            pattern: "(?i)(?<![\\p{L}\\p{N}_])\(escape)\\s+(\(phrases))(?![\\p{L}\\p{N}_])",
            in: text,
            protected: &protected
        ) { match in
            guard let space = match.firstIndex(of: " ") else { return match }
            return String(match[match.index(after: space)...])
        }
    }

    private func protect(
        pattern: String,
        in text: String,
        protected: inout [String: String],
        transform: (String) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let range = Range(match.range, in: result) else { continue }
            let placeholder = "\u{E000}\(protected.count)\u{E001}"
            protected[placeholder] = transform(String(result[range]))
            result.replaceSubrange(range, with: placeholder)
        }
        return result
    }

    private func normalizeSpacing(in text: String) -> String {
        var result = text
        let replacements = [
            (#"[ \t]+([,.!?])"#, "$1"),
            (#"([,.!?])(?=[\p{L}\p{N}])"#, "$1 "),
            (#"\(\s+"#, "("),
            (#"\s+\)"#, ")"),
            (#"[ \t]+\n"#, "\n"),
            (#"\n[ \t]+"#, "\n"),
            (#"\n{3,}"#, "\n\n")
        ]
        for (pattern, replacement) in replacements {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            result = expression.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }
        return result
    }
}
