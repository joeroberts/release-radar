import Foundation

/// A bounded destination scanner, not a Markdown renderer. Each scan advances
/// monotonically; labels and destinations permit at most 128 nested delimiters.
/// Code, comments, and unused reference definitions never provide navigation.
enum RepositoryDocumentMarkdown {
    struct Link {
        let destination: String
        let isNavigation: Bool
        let isHistoricalCitation: Bool
    }

    static func links(in text: String) throws -> [Link] {
        var scanner = Scanner(bytes: Array(text.utf8))
        return try scanner.scan()
    }

    private struct Scanner {
        let bytes: [UInt8]
        var position = 0
        var lineStart = 0
        var labels: [Int] = []
        var links: [Link] = []
        var definitions: [String: String] = [:]
        var references: [(label: String, image: Bool)] = []
        var fence: (byte: UInt8, length: Int)?
        var codeClosers: [Int: (end: Int, length: Int)] = [:]
        var lastClosingAngle = -1
        var htmlScanBytes = 0

        mutating func scan() throws -> [Link] {
            // Index code delimiters once. Searching afresh from every unmatched
            // backtick would repeat the same pathological suffix scan as a regex.
            var runs: [(start: Int, length: Int)] = []
            var cursor = 0
            while cursor < bytes.count {
                if bytes[cursor] == 62 { lastClosingAngle = cursor }
                if bytes[cursor] == 96 {
                    let start = cursor
                    while cursor < bytes.count && bytes[cursor] == 96 { cursor += 1 }
                    runs.append((start, cursor - start))
                } else { cursor += 1 }
            }
            var nextRun: [Int: Int] = [:]
            for run in runs.reversed() {
                if let next = nextRun[run.length] { codeClosers[run.start] = (next + run.length, run.length) }
                nextRun[run.length] = run.start
            }
            while position < bytes.count {
                if position == lineStart, skipFenceLine() { continue }
                if matches("<!--", at: position) {
                    var end = position + 4
                    while end < bytes.count && !matches("-->", at: end) { end += 1 }
                    advance(to: min(bytes.count, end + 3))
                    continue
                }
                let byte = bytes[position]
                if byte == 92 { advance(to: min(bytes.count, position + 2)); continue }
                if byte == 96 {
                    if let closer = codeClosers[position] { advance(to: closer.end) }
                    else {
                        var end = position + 1
                        while end < bytes.count && bytes[end] == 96 { end += 1 }
                        advance(to: end)
                    }
                    continue
                }
                if byte == 60 { try scanHTML(); continue }
                if byte == 91 {
                    guard labels.count < 128 else { throw RepositoryDocumentError(.limitExceeded) }
                    labels.append(position)
                } else if byte == 93, let opening = labels.popLast() {
                    let closing = position
                    let image = opening > 0 && bytes[opening - 1] == 33
                    if closing + 1 < bytes.count && bytes[closing + 1] == 40 {
                        let parsed = try destination(at: closing + 2, inline: true)
                        if let value = parsed.value {
                            links.append(.init(destination: value, isNavigation: !image,
                                               isHistoricalCitation: !image && matches("Historical ", at: opening + 1)
                                                && closing - opening > "Historical ".utf8.count))
                        }
                        advance(to: parsed.end)
                        continue
                    }
                    if closing + 1 < bytes.count && bytes[closing + 1] == 58 && definitionStarts(at: opening) {
                        let parsed = try destination(at: closing + 2, inline: false)
                        if let value = parsed.value, let key = referenceKey(opening + 1, closing) {
                            if definitions[key] == nil { definitions[key] = value }
                            links.append(.init(destination: value, isNavigation: false, isHistoricalCitation: false))
                        }
                        var end = parsed.end
                        while end < bytes.count && bytes[end] != 10 { end += 1 }
                        advance(to: end)
                        continue
                    }
                    if closing + 1 < bytes.count && bytes[closing + 1] == 91 {
                        var end = closing + 2
                        while end < bytes.count && bytes[end] != 93 && bytes[end] != 10 && end - closing <= 1_001 { end += 1 }
                        if end < bytes.count && bytes[end] == 93 {
                            let key = end == closing + 2 ? referenceKey(opening + 1, closing) : referenceKey(closing + 2, end)
                            if let key { references.append((key, image)) }
                            advance(to: end + 1)
                            continue
                        }
                    }
                    if let key = referenceKey(opening + 1, closing) { references.append((key, image)) }
                }
                advance(to: position + 1)
            }
            for reference in references {
                if let value = definitions[reference.label] {
                    links.append(.init(destination: value, isNavigation: !reference.image, isHistoricalCitation: false))
                }
            }
            return links
        }

        mutating func advance(to end: Int) {
            for index in position..<end where bytes[index] == 10 { lineStart = index + 1 }
            position = end
        }

        mutating func skipFenceLine() -> Bool {
            var first = position
            while first < bytes.count && bytes[first] == 32 && first - position < 4 { first += 1 }
            var end = first
            let marker = first < bytes.count ? bytes[first] : 0
            if first - position <= 3 && (marker == 96 || marker == 126) {
                while end < bytes.count && bytes[end] == marker { end += 1 }
            }
            let length = end - first
            if let current = fence {
                if marker == current.byte && length >= current.length {
                    var tail = end
                    while tail < bytes.count && (bytes[tail] == 32 || bytes[tail] == 9 || bytes[tail] == 13) { tail += 1 }
                    if tail == bytes.count || bytes[tail] == 10 { fence = nil }
                }
            } else if length >= 3 {
                fence = (marker, length)
            } else { return false }
            while end < bytes.count && bytes[end] != 10 { end += 1 }
            advance(to: min(bytes.count, end + 1))
            return true
        }

        func matches(_ value: String, at index: Int) -> Bool {
            let target = Array(value.utf8)
            return index + target.count <= bytes.count && bytes[index..<(index + target.count)].elementsEqual(target)
        }

        func definitionStarts(at index: Int) -> Bool {
            var cursor = index
            for _ in 0...3 {
                if cursor == 0 || bytes[cursor - 1] == 10 { return true }
                guard bytes[cursor - 1] == 32 else { return false }
                cursor -= 1
            }
            return false
        }

        func referenceKey(_ start: Int, _ end: Int) -> String? {
            guard end > start, end - start <= 999 else { return nil }
            return String(decoding: bytes[start..<end], as: UTF8.self)
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
        }

        func destination(at start: Int, inline: Bool) throws -> (value: String?, end: Int) {
            var cursor = start
            while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
            var value: [UInt8] = []
            var depth = 0
            if cursor < bytes.count && bytes[cursor] == 60 {
                cursor += 1
                while cursor < bytes.count && bytes[cursor] != 62 && bytes[cursor] != 10 {
                    if bytes[cursor] == 92 && cursor + 1 < bytes.count { cursor += 1 }
                    value.append(bytes[cursor]); cursor += 1
                }
                guard cursor < bytes.count && bytes[cursor] == 62 else { return (nil, cursor) }
                cursor += 1
            } else {
                while cursor < bytes.count {
                    let byte = bytes[cursor]
                    if byte == 92 && cursor + 1 < bytes.count {
                        cursor += 1; value.append(bytes[cursor]); cursor += 1; continue
                    }
                    if whitespace(byte) || (byte == 41 && depth == 0) { break }
                    if byte == 40 {
                        depth += 1
                        guard depth <= 128 else { throw RepositoryDocumentError(.limitExceeded) }
                    } else if byte == 41 { depth -= 1 }
                    value.append(byte); cursor += 1
                }
                guard depth == 0 else { return (nil, cursor) }
            }
            guard inline else { return (String(decoding: value, as: UTF8.self), cursor) }
            while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
            if cursor < bytes.count && (bytes[cursor] == 34 || bytes[cursor] == 39 || bytes[cursor] == 40) {
                let ending: UInt8 = bytes[cursor] == 40 ? 41 : bytes[cursor]
                cursor += 1
                while cursor < bytes.count && bytes[cursor] != ending {
                    if bytes[cursor] == 92 && cursor + 1 < bytes.count { cursor += 1 }
                    cursor += 1
                }
                guard cursor < bytes.count else { return (nil, cursor) }
                cursor += 1
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
            }
            guard cursor < bytes.count && bytes[cursor] == 41 else { return (nil, cursor) }
            return (String(decoding: value, as: UTF8.self), cursor + 1)
        }

        mutating func scanHTML() throws {
            // Without a following closing angle this is ordinary text. Cache the
            // last closer once so repeated malformed '<' cannot rescan the suffix.
            guard position < lastClosingAngle else { advance(to: position + 1); return }
            let candidate = htmlTag()
            htmlScanBytes += candidate.scanned
            // Speculative malformed tags may overlap. Bound their combined work
            // by input size rather than restarting an unlimited suffix search.
            guard htmlScanBytes <= bytes.count * 4 else { throw RepositoryDocumentError(.limitExceeded) }
            if let end = candidate.end {
                links.append(contentsOf: candidate.links)
                advance(to: end)
            } else {
                // Commit neither links nor consumed text until the tag is complete.
                advance(to: position + 1)
            }
        }

        func htmlTag() -> (end: Int?, scanned: Int, links: [Link]) {
            var cursor = position + 1
            var found: [Link] = []
            func failed() -> (end: Int?, scanned: Int, links: [Link]) {
                (nil, cursor - position, [])
            }
            let closing = cursor < bytes.count && bytes[cursor] == 47
            if closing { cursor += 1 }
            let tagStart = cursor
            guard cursor < bytes.count && asciiLetter(bytes[cursor]) else { return failed() }
            cursor += 1
            while cursor < bytes.count && (asciiLetter(bytes[cursor]) || (48...57).contains(bytes[cursor]) || bytes[cursor] == 45) { cursor += 1 }
            let tag = String(decoding: bytes[tagStart..<cursor], as: UTF8.self).lowercased()
            while cursor < bytes.count {
                let beforeSpace = cursor
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
                if cursor < bytes.count && bytes[cursor] == 62 {
                    return (cursor + 1, cursor + 1 - position, found)
                }
                if !closing && cursor + 1 < bytes.count && bytes[cursor] == 47 && bytes[cursor + 1] == 62 {
                    return (cursor + 2, cursor + 2 - position, found)
                }
                guard !closing, cursor > beforeSpace, cursor < bytes.count,
                      asciiLetter(bytes[cursor]) || bytes[cursor] == 95 || bytes[cursor] == 58 else { return failed() }
                let nameStart = cursor
                cursor += 1
                while cursor < bytes.count && (asciiLetter(bytes[cursor]) || (48...57).contains(bytes[cursor])
                    || [45, 46, 58, 95].contains(bytes[cursor])) { cursor += 1 }
                let name = String(decoding: bytes[nameStart..<cursor], as: UTF8.self).lowercased()
                let nameEnd = cursor
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count else { return failed() }
                if bytes[cursor] != 61 {
                    cursor = nameEnd // A boolean attribute; preserve the next separator.
                    continue
                }
                cursor += 1
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count else { return failed() }
                let quote = bytes[cursor] == 34 || bytes[cursor] == 39 ? bytes[cursor] : 0
                if quote != 0 { cursor += 1 }
                let valueStart = cursor
                while cursor < bytes.count && (quote == 0 ? !whitespace(bytes[cursor]) && bytes[cursor] != 62 : bytes[cursor] != quote) {
                    if quote == 0 && [34, 39, 60, 61, 96].contains(bytes[cursor]) { return failed() }
                    cursor += 1
                }
                guard cursor > valueStart || quote != 0 else { return failed() }
                guard quote == 0 || cursor < bytes.count else { return failed() }
                if name == "href" || name == "src" {
                    found.append(.init(destination: String(decoding: bytes[valueStart..<cursor], as: UTF8.self),
                                       isNavigation: tag == "a" && name == "href", isHistoricalCitation: false))
                }
                if quote != 0 { cursor += 1 }
            }
            return failed()
        }

        func whitespace(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
        func asciiLetter(_ byte: UInt8) -> Bool { (65...90).contains(byte) || (97...122).contains(byte) }
    }
}
