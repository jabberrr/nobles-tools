import Foundation

/// Just enough HTML reading to pull attribute data out of a page, without a parser dependency.
enum HTMLScanning {
    /// The attributes of every `<tagName …>` start tag, in document order. Names are lowercased
    /// and values entity-decoded. Only double-quoted values are read; values may span lines.
    static func startTags(named tagName: String, in html: String) -> [[String: String]] {
        var tags: [[String: String]] = []
        var rest = html[...]
        while let open = rest.range(of: "<\(tagName)", options: .caseInsensitive) {
            if let next = rest[open.upperBound...].first, next.isWhitespace || next == ">" {
                tags.append(attributes(of: startTag(from: open.lowerBound, in: rest)))
            }
            // Resume right after the tag name, so a stray "<div" in a script can't swallow real tags.
            rest = rest[open.upperBound...]
        }
        return tags
    }

    /// Text from `start` through the first `>` outside a quoted value (or to the end).
    private static func startTag(from start: Substring.Index, in text: Substring) -> Substring {
        var inQuotes = false
        var index = start
        while index < text.endIndex {
            switch text[index] {
            case "\"": inQuotes.toggle()
            case ">" where !inQuotes: return text[start...index]
            default: break
            }
            index = text.index(after: index)
        }
        return text[start...]
    }

    /// `name="value"` pairs in a start tag; the first of a repeated name wins.
    private static func attributes(of tag: Substring) -> [String: String] {
        var attributes: [String: String] = [:]
        var rest = tag
        while let equals = rest.range(of: "=\""), let close = rest[equals.upperBound...].firstIndex(of: "\"") {
            let nameStart = rest[..<equals.lowerBound].lastIndex(where: \.isWhitespace).map(rest.index(after:)) ?? rest.startIndex
            let name = rest[nameStart..<equals.lowerBound].lowercased()
            if attributes[name] == nil {
                attributes[name] = String(rest[equals.upperBound..<close]).decodingHTMLEntities
            }
            rest = rest[rest.index(after: close)...]
        }
        return attributes
    }
}

extension String {
    /// With `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;` and numeric references such as
    /// `&#039;` or `&#x2019;` decoded. Anything else is left as written.
    var decodingHTMLEntities: String {
        guard contains("&") else { return self }
        var result = ""
        var rest = self[...]
        while let ampersand = rest.firstIndex(of: "&") {
            result += rest[..<ampersand]
            let reference = rest[rest.index(after: ampersand)...]
            if let semicolon = reference.prefix(10).firstIndex(of: ";"),
               let character = Self.character(forEntity: reference[..<semicolon]) {
                result.append(character)
                rest = reference[reference.index(after: semicolon)...]
            } else {
                result.append("&")
                rest = reference
            }
        }
        return result + rest
    }

    private static func character(forEntity name: Substring) -> Character? {
        switch name {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return " "
        default:
            guard name.first == "#" else { return nil }
            let number = name.dropFirst()
            let code = number.first == "x" || number.first == "X" ? UInt32(number.dropFirst(), radix: 16) : UInt32(number)
            return code.flatMap(Unicode.Scalar.init).map(Character.init)
        }
    }
}
