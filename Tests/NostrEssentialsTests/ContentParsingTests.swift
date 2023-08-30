//
//  ContentParsingTests.swift
//  
//
//  Created by Fabian Lachman on 28/08/2023.
//

import XCTest
@testable import NostrEssentials

final class ContentParsingTests: XCTestCase {
    
    // Example mock data sources:
    class MockPubkeys {
        // Mock tags
        public let tags = [
            ("p", "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd34"),
            ("p", "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd34")
        ]
    }

    class MockNames {
        // Mock names
        let names = [
            "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e": "Fabian",
            "9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33": "Nostur",
            "npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe": "Fabian",
            "npub1lrnvvs6z78s9yjqxxr38uyqkmn34lsaxznnqgd877j4z2qej3j5s09qnw5": "corndalorian"
        ]
        
    }

    // Example of using ContentParser
    // It takes a string of content, custom handlers for any type of replacements, and data sources to use in the handlers
    func testContentParser() throws {
        
        // First define some custom handlers, here are 3 examples: nostrUriHandler, indexTagHandler, npubHandler
        
        func nostrUriHandler (_ uriString: String, _ contentItems: [ContentItem], _ dataSources: [String: AnyObject]) -> [ContentItem] {
            // uriString: "nostr:nprofile1qqsfhc97pejd8z3f488vnfwgaawcw0ptlffk9f94trd9la5mc09ms8spzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgpvhe4f"
            
            // Handle nostr:nprofile1...
            let nprofileMatches = NostrRegexes.default.matchingStrings(uriString, regex: NostrRegexes.default.cache[.nprofile]!)
            
            if !nprofileMatches.isEmpty {
                let nprofileString = nprofileMatches[0][0]
                // nprofileString: "nprofile1qqsfhc97pejd8z3f488vnfwgaawcw0ptlffk9f94trd9la5mc09ms8spzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgpvhe4f"
                
                if let nprofile = try? ShareableIdentifier(nprofileString) {
                    return contentItems + [ContentItem.nprofile1(nprofile)]
                }
            }
            
            // Handle others, eg nostr:npub1 or nostr:naddr1 etc..
            
            // If we can't handle, just return the text
            return contentItems + [ContentItem.text(uriString)]
        }
        
        func indexTagHandler (_ input: String, _ dataSources: [String: AnyObject]) -> String {
            guard let mockTags = (dataSources["tags"] as? MockPubkeys)?.tags else { return input }
            
            guard let mockNames = (dataSources["names"] as? MockNames)?.names else { return input }
           
            var newText = input
            let matches = NostrRegexes.default.cache[.indexedTag]!.matches(in: input, range: NSRange(location: 0, length: input.utf16.count))
            
            for match in matches.prefix(100) { // 100 limit for sanity
                // match.range(at: 0) = #[3]
                // match.range(at: 1) = 3
                let indexTag = (input as NSString).substring(with: match.range(at: 0))
                let index = (input as NSString).substring(with: match.range(at: 1))
                guard let indexInt = Int(index) else { continue }
                guard indexInt < mockTags.count else { continue }
                let tag = mockTags[indexInt]

                if (tag.0 == "p") {
                    if let name = mockNames[tag.1] {
                        newText = newText.replacingOccurrences(of: indexTag, with: "(\(name))[nostr:\(Keys.npub(hex: tag.1))]")
                    }
                   
        //               newText = newText.replacingOccurrences(of: match.output.0, with: "[@\(contactUsername(fromPubkey: tag.1, event:event).escapeMD())](nostur:p:\(tag.1))")
               }
               else if (tag.0 == "e") {
                   //
               }
           }
           return newText
        }

        func npubHandler (_ input: String, _ dataSources: [String: AnyObject]) -> String {
            guard let mockNames = (dataSources["names"] as? MockNames)?.names else { return input }
            
            let replaced = NostrRegexes.default.replaceMatches(in: NostrRegexes.default.cache[.npub]!, in: input) { input in
                if let name = mockNames[input] {
                    return "(\(name))[nostr:\(input)]"
                }
                return input
            }
            return replaced
        }
        
        // The ContentParser, takes string, usually the .content field of a nostr event
        // Parses it and returns an array of ContentItem.
        
        // The ContentParser needs 3 things stored in dictionaries:
        // 1. Embed handlers, stored in .embedHandlers where the key is a NSRegularExpression and the value is a function called to replace found matches
        // 2. Inline text handlers stored in .inlineHandlers where the key is a NSRegularExpression and the value is a function called to replace found matches
        // 3. Data sources, the key is a String that identifies the data source, the value can be Any object that is expected to be used in your embed/inline handlers
        let parser = ContentParser()
        
        // .nostrUri is a regex that matches any "nostr:..." uri
        parser.embedHandlers[NostrRegexes.default.cache[.nostrUri]!] = nostrUriHandler
        
        // .indexTag is a regex that matches #[0], #[1], #[2], #[3], etc.
        // indexTagHandler replaces any indexTag with markdown link
        parser.inlineHandlers[NostrRegexes.default.cache[.indexedTag]!] = indexTagHandler
        
        // .npub is a regex that matches any npub
        parser.inlineHandlers[NostrRegexes.default.cache[.npub]!] = npubHandler
        
        // "tags" and "names" are example data sources, used by handlers to lookup replacements, for example:
        // replace #[0] with the p-tag value at index 0 in "tags" (MockPubkeys)
        // replace that p-tag value with its mapped name ("Fabian") in "names" (MockNames)
        parser.dataSources["tags"] = MockPubkeys()
        parser.dataSources["names"] = MockNames()
        
        // Example content
        let exampleContent = "Hello #[0]! Did you create #[1]? Is this your profile? nostr:nprofile1qqsfhc97pejd8z3f488vnfwgaawcw0ptlffk9f94trd9la5mc09ms8spzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgpvhe4f\nDo you know npub1lrnvvs6z78s9yjqxxr38uyqkmn34lsaxznnqgd877j4z2qej3j5s09qnw5?"
        
        
        let contentItems = try parser.parse(exampleContent)

        // In this test the parser returns 3 items
        
        // First is a text was parsed by inlineHandlers (indexTagHandler), to create markdown urls in the text
        XCTAssertEqual(contentItems[0], ContentItem.text("Hello (Fabian)[nostr:npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe]! Did you create (Nostur)[nostr:npub1n0stur7q092gyverzc2wfc00e8egkrdnnqq3alhv7p072u89m5es5mk6h0]? Is this your profile? "))
        
        // Second an nprofile, parsed by the embedHandler: nostrUriHandler, it first detected the nostr uri, then
        // the handler has an example implementation for nprofiles, so it parsed and return that
        XCTAssertEqual(contentItems[1], ContentItem.nprofile1(try! ShareableIdentifier("nprofile1qqsfhc97pejd8z3f488vnfwgaawcw0ptlffk9f94trd9la5mc09ms8spzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgpvhe4f")))
        
        // Last, the remaining text, parsed by inlineHandlers (npubHandler), to create a markdown url again
        XCTAssertEqual(contentItems[2], ContentItem.text("\nDo you know (corndalorian)[nostr:npub1lrnvvs6z78s9yjqxxr38uyqkmn34lsaxznnqgd877j4z2qej3j5s09qnw5]?"))
        
        
        XCTAssertEqual(contentItems.count, 3)
    }

}
