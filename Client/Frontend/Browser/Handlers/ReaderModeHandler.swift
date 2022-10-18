// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import WebKit
import GCDWebServers
import Shared

public class ReaderModeHandler: InternalSchemeResponse {
  private let profile: Profile
  public static let path = "readermode"
  private static let readerModeStyleHash = "sha256-L2W8+0446ay9/L1oMrgucknQXag570zwgQrHwE68qbQ="
  private static var readerModeCache: ReaderModeCache = DiskReaderModeCache.sharedInstance

  public func response(forRequest request: URLRequest) -> (URLResponse, Data)? {
    guard let _url = request.url, let url = InternalURL(_url) else { return nil }

    let response = InternalSchemeHandler.response(forUrl: url.url)
    
    guard let readerModeUrl = url.extractedUrlParam else {
      return nil
    }
    
    do {
      let readabilityResult = try ReaderModeHandler.readerModeCache.get(readerModeUrl)
      // We have this page in our cache, so we can display it. Just grab the correct style from the
      // profile and then generate HTML from the Readability results.
      var readerModeStyle = DefaultReaderModeStyle
      if let dict = profile.prefs.dictionaryForKey(ReaderModeProfileKeyStyle) {
        if let style = ReaderModeStyle(dict: dict) {
          readerModeStyle = style
        }
      }

      // Must generate a unique nonce, every single time as per Content-Policy spec.
      let setTitleNonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")

      if let html = ReaderModeUtils.generateReaderContent(
        readabilityResult, initialStyle: readerModeStyle,
        titleNonce: setTitleNonce),
         let data = html.data(using: .utf8) {
        // Apply a Content Security Policy that disallows everything except images from anywhere and fonts and css from our internal server   
//        response.setValue("default-src 'none'; img-src *; style-src http://localhost:* '\(ReaderModeHandler.readerModeStyleHash)'; font-src http://localhost:*; script-src 'nonce-\(setTitleNonce)'", forAdditionalHeader: "Content-Security-Policy")
        
        return (response, data)
      }
    } catch {
      
    }
    

    assert(false)
    return nil
  }
  
  public init(profile: Profile) {
    self.profile = profile
  }
}
