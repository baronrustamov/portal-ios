// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import WebKit
import Shared
import BraveCore
import os.log

class FaviconScriptHandler: NSObject, TabContentScript {
  private weak var tab: Tab?
  private var faviconDriver: FaviconLoader.Driver
  
  init(tab: Tab) {
    self.tab = tab
    self.faviconDriver = FaviconLoader.Driver(privateBrowsingMode: tab.isPrivate)
    super.init()
  }
  
  static let scriptName = "FaviconScript"
  static let scriptId = UUID().uuidString
  static let messageHandlerName = "\(scriptName)_\(messageUUID)"
  static let scriptSandbox: WKContentWorld = .defaultClient
  static let userScript: WKUserScript? = {
    guard var script = loadUserScript(named: scriptName) else {
      return nil
    }
    
    return WKUserScript.create(source: secureScript(handlerName: messageHandlerName,
                                                    securityToken: scriptId,
                                                    script: script),
                               injectionTime: .atDocumentStart,
                               forMainFrameOnly: true,
                               in: scriptSandbox)
  }()

  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: (Any?, String?) -> Void) {
    defer { replyHandler(nil, nil) }
    
    guard let webView = message.webView,
          let url = webView.url,
          !InternalURL.isValid(url: url),
          !(InternalURL(url)?.isSessionRestore ?? false) else { return }
    
    faviconDriver.webView(webView, onFaviconURLsUpdated: message)
  }
}
