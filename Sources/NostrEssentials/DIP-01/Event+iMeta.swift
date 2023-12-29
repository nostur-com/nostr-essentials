//
//  Event+iMeta.swift
//  
//
//  Created by Fabian Lachman on 29/12/2023.
//

import Foundation

extension Event {
    public func iMeta(for url: String) -> IMeta? {
        tags.compactMap { IMeta.fromTag($0) }
            .first(where: { $0.url == url })
    }
}

public struct IMeta {
    public let url: String
    public var blurhash: String?
    public var dim: String?
    public var sha256: String?
    
    public var dimSize: CGSize? {
        guard let dim = dim else { return nil }
        let dims = dim.components(separatedBy: "x")
        guard dims.count == 2 else { return nil }
        guard let width = Double(dims[0]), let height = Double(dims[1]) else { return nil }
        return CGSize(width: ceil(width), height: ceil(height))
    }
    
    static func fromTag(_ tag: Tag) -> IMeta? {
        guard tag.type == "imeta" else { return nil }
        var valuesDict: [String: String] = [:]
        for tag in tag.tag.dropFirst() {
            let property = tag.components(separatedBy: " ")
            guard property.count >= 2 else { continue }
            valuesDict[property[0]] = property[1]
        }
        guard let url = valuesDict["url"] else { return nil }
        return IMeta(url: url, blurhash: valuesDict["blurhash"], dim: valuesDict["dim"], sha256: valuesDict["sha256"])
    }
}
