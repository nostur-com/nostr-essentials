//
//  ContentParsing.swift
//  
//
//  Created by Fabian Lachman on 27/08/2023.
//

import Foundation

public protocol DataSource { }

public typealias EmbedExpressionHandler = (_ matchingString: String, _ contentItems: [ContentItem], _ dataSources: [String: AnyObject]) -> [ContentItem]

public typealias InlineExpressionHandler = (_ matchingString: String, _ dataSources: [String: AnyObject]) -> String

public class ContentParser {
    
    public init(embedHandlers: [NSRegularExpression: EmbedExpressionHandler] = [:], inlineHandlers: [NSRegularExpression: InlineExpressionHandler] = [:], dataSources: [String: AnyObject] = [:]) {
        self.embedHandlers = embedHandlers
        self.inlineHandlers = inlineHandlers
        self.dataSources = dataSources
    }
    
    public var embedHandlers: [NSRegularExpression: EmbedExpressionHandler] = [:]
    public var inlineHandlers: [NSRegularExpression: InlineExpressionHandler] = [:]
    public var dataSources: [String: AnyObject] = [:]
    
    public func parse(_ input: String) throws -> [ContentItem] {
        let range = NSRange(location: 0, length: input.utf16.count)
        var result: [ContentItem] = []
        var lastMatchEnd = 0
        
        let embedPatterns = embedHandlers
            .keys
            .map { $0.pattern }
            .joined(separator: "|")
        
        guard let combinedEmbedPatterns = try? NSRegularExpression(pattern: embedPatterns) else {
            throw ContentParserError.UnableToCreateRegex
        }
        
        //        let inlinePatterns = inlineHandlers
        //            .keys
        //            .map { $0.pattern }
        //            .joined(separator: "|")
        //
        //        guard let combinedInlinePatterns = try? NSRegularExpression(pattern: inlinePatterns) else {
        //            throw ContentParserError.UnableToCreateRegex
        //        }
        
        // The entire content will be turned into inline text parts, and embed parts
        
        // We try to find/match anything that should be turned into a 'embed' using embedhandlers
        // all the remaining unmatched we handle with inlineHandlers
        combinedEmbedPatterns.enumerateMatches(in: input, options: [], range: range) { embedMatch, _, _ in
            if let embedMatch {
                
                // Everything that matches is embedMatch/embedMatchRange
                // Now we can calculate the range of everything that didn't match
                // this is inlineMatch/inlineRange
                let embedMatchRange = embedMatch.range
                let inlineMatchRange = NSRange(location: lastMatchEnd, length: embedMatchRange.location - lastMatchEnd)
                let inlineMatch = (input as NSString).substring(with: inlineMatchRange)
                let embedMatch = (input as NSString).substring(with: embedMatchRange)
                
                
                // First non match, if there is one, so its inline
                if !inlineMatch.isEmpty {
                    result.append(ContentItem.text(parseInline(inlineMatch, dataSources: self.dataSources)))
                }
                
                // handle any match with embedhandlers
                for (pattern, handler) in embedHandlers {
                    if !NostrRegexes.default.matchingStrings(embedMatch, regex: pattern).isEmpty {
                        result = handler(embedMatch, result, self.dataSources)
                        break
                    }
                    result.append(ContentItem.text(parseInline(embedMatch, dataSources: self.dataSources)))
                }
                
                lastMatchEnd = embedMatchRange.location + embedMatchRange.length
            }
        }
        
        let inlineMatchRange = NSRange(location: lastMatchEnd, length: input.utf16.count - lastMatchEnd)
        let inlineMatch = (input as NSString).substring(with: inlineMatchRange)
        
        if !inlineMatch.isEmpty {
            result.append(ContentItem.text(parseInline(inlineMatch, dataSources: self.dataSources)))
        }
        return result
    }
    
    private func parseInline(_ input:String, dataSources:[String: AnyObject]) -> String {
        var output = input
        for (pattern, handler) in inlineHandlers {
            if !NostrRegexes.default.matchingStrings(input, regex: pattern).isEmpty {
                output = handler(output, dataSources)
            }
        }
        return output
    }
    
    public enum ContentParserError: Error {
        case UnableToCreateRegex
    }
}

public enum ContentItem: Hashable, Identifiable {
    public var id: Self { self }
    case code(String) // dont parse anything here
    case text(String) // text notes
    case npub1(String) // npub
    case note1(String) // note1 id
    case noteHex(String) // hex id of note
    case lnbc(String) // lightning invoice
    case link(String, URL) // web link
    case image(URL) // image url
    case video(URL) // video url
    case linkPreview(URL) // web link
    case nevent1(ShareableIdentifier) // sharable event identifier
    case nprofile1(ShareableIdentifier) // sharable profile identifier
}
