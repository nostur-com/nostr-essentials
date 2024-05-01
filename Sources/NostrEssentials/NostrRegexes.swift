//
//  NostrRegexes.swift
//  
//
//  Created by Fabian Lachman on 18/08/2023.
//

import Foundation

// Initialization of NSRegularExpression regexes is expensive, so initialize once
// and reuse the singleton
public class NostrRegexes {
    static public let `default` = NostrRegexes()
    
    
    // Pattern definitions
    public enum pattern: String {
        case hexId       = ###"[0-9a-z]{64}"###
        case npub        = ###"npub1[023456789acdefghjklmnpqrstuvwxyz]{58}"###
        case nsec        = ###"nsec1[023456789acdefghjklmnpqrstuvwxyz]{58}"###
        case note        = ###"note1[023456789acdefghjklmnpqrstuvwxyz]{58}"###
        
        case nevent      = ###"nevent1[023456789acdefghjklmnpqrstuvwxyz]+\b"###
        case nprofile    = ###"nprofile1[023456789acdefghjklmnpqrstuvwxyz]+\b"###
        case naddr       = ###"naddr1[023456789acdefghjklmnpqrstuvwxyz]+\b"###
        case nrelay      = ###"nrelay1[023456789acdefghjklmnpqrstuvwxyz]+\b"###
        
        case anyId       = ###"((npub1|nsec1|note1|nevent1|nprofile1|naddr1|nrelay1)[023456789acdefghjklmnpqrstuvwxyz]+)\b"###
        case nostrUri    = ###"nostr:((npub1|nsec1|note1|nevent1|nprofile1|naddr1|nrelay1)[023456789acdefghjklmnpqrstuvwxyz]+)\b"###
        
        case hashtag     = ###"(?<![/\?]|\b)(\#)([^\s#\]\[]\S{2,})\b"###
        case indexedTag  = ###"#\[(\d+)\]"###
        
        case bolt11  = ###"\["bolt11","(.*?)"\]"###
    }
    
    // Cache the regex initializations before use
    public var cache: [pattern: NSRegularExpression] = [
        .hexId: try! NSRegularExpression(pattern: pattern.hexId.rawValue, options: []),
        .npub: try! NSRegularExpression(pattern: pattern.npub.rawValue, options: []),
        .nsec: try! NSRegularExpression(pattern: pattern.nsec.rawValue, options: []),
        .note: try! NSRegularExpression(pattern: pattern.note.rawValue, options: []),
        .nevent: try! NSRegularExpression(pattern: pattern.nevent.rawValue, options: []),
        .nprofile: try! NSRegularExpression(pattern: pattern.nprofile.rawValue, options: []),
        .naddr: try! NSRegularExpression(pattern: pattern.naddr.rawValue, options: []),
        .nrelay: try! NSRegularExpression(pattern: pattern.nrelay.rawValue, options: []),
        .anyId: try! NSRegularExpression(pattern: pattern.anyId.rawValue, options: []),
        .nostrUri: try! NSRegularExpression(pattern: pattern.nostrUri.rawValue, options: []),
        .hashtag: try! NSRegularExpression(pattern: pattern.hashtag.rawValue, options: []),
        .indexedTag: try! NSRegularExpression(pattern: pattern.indexedTag.rawValue, options: []),
        .bolt11: try! NSRegularExpression(pattern: pattern.bolt11.rawValue, options: [])
    ]
    // Replace matches in regex with result of function, which takes the match as a parameter
    public func replaceMatches(in regex: NSRegularExpression, in string: String, with function: (String) -> String) -> String {
        let range = NSRange(location: 0, length: string.utf16.count)
        var result = string
        for match in regex.matches(in: string, options: [], range: range) {
            let matchRange = match.range(at: 0)
            let matchString = String(string[Range(matchRange, in: string)!])
            let replacement = function(matchString)
            result = regex.stringByReplacingMatches(in: result, options: [], range: matchRange, withTemplate: replacement)
        }
        return result
    }
    
    public func matchingStrings(_ input: String, regex: NSRegularExpression) -> [[String]] {
        let nsString = input as NSString
        let results  = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
    
    public func matchingStrings(_ input: String, regex: String) -> [[String]] {
        let regex = (try! NSRegularExpression(pattern: regex, options: []))
        let nsString = input as NSString
        let results  = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
    
}
