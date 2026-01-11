import Foundation
import SwiftUI

@MainActor
final class ToneMetaStore: ObservableObject
{
    struct ToneMeta: Codable, Equatable
    {
        var favorite: Bool
        var tags: [String]
    }

    @AppStorage("blackalpha.toneMeta.json") private var rawJSON: String = "{}"
    @Published private(set) var cache: [String: ToneMeta] = [:]

    init()
    {
        load()
    }

    func key(bankId: String, toneIndex: Int) -> String
    {
        "\(bankId):\(toneIndex)"
    }

    func meta(bankId: String, toneIndex: Int) -> ToneMeta
    {
        cache[key(bankId: bankId, toneIndex: toneIndex)] ?? ToneMeta(favorite: false, tags: [])
    }

    func isFavorite(bankId: String, toneIndex: Int) -> Bool
    {
        meta(bankId: bankId, toneIndex: toneIndex).favorite
    }

    func tags(bankId: String, toneIndex: Int) -> [String]
    {
        meta(bankId: bankId, toneIndex: toneIndex).tags
    }

    func setFavorite(bankId: String, toneIndex: Int, _ value: Bool)
    {
        var m = meta(bankId: bankId, toneIndex: toneIndex)
        m.favorite = value
        cache[key(bankId: bankId, toneIndex: toneIndex)] = m
        persist()
    }

    func addTag(bankId: String, toneIndex: Int, tag: String)
    {
        let t = normalizeTag(tag)
        guard !t.isEmpty else { return }
        var m = meta(bankId: bankId, toneIndex: toneIndex)
        if !m.tags.contains(t)
        {
            m.tags.append(t)
            m.tags.sort()
            cache[key(bankId: bankId, toneIndex: toneIndex)] = m
            persist()
        }
    }

    func removeTag(bankId: String, toneIndex: Int, tag: String)
    {
        var m = meta(bankId: bankId, toneIndex: toneIndex)
        m.tags.removeAll { $0 == tag }
        cache[key(bankId: bankId, toneIndex: toneIndex)] = m
        persist()
    }

    private func normalizeTag(_ s: String) -> String
    {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    private func load()
    {
        guard let data = rawJSON.data(using: .utf8) else { cache = [:]; return }
        cache = (try? JSONDecoder().decode([String: ToneMeta].self, from: data)) ?? [:]
    }

    private func persist()
    {
        rawJSON = (try? String(data: JSONEncoder().encode(cache), encoding: .utf8)) ?? "{}"
        objectWillChange.send()
    }
}

