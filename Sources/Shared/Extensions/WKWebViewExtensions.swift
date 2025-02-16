// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import JavaScriptCore
import WebKit

enum JavascriptError: Error {
  case invalid
}

public extension WKWebView {
  func generateJSFunctionString(functionName: String, args: [Any?], escapeArgs: Bool = true) -> (javascript: String, error: Error?) {
    var sanitizedArgs = [String]()
    for arg in args {
      if let arg = arg {
        do {
          if let arg = arg as? String {
            sanitizedArgs.append(escapeArgs ? "'\(arg.htmlEntityEncodedString)'" : "\(arg)")
          } else {
            let data = try JSONSerialization.data(withJSONObject: arg, options: [.fragmentsAllowed])

            if let str = String(data: data, encoding: .utf8) {
              sanitizedArgs.append(str)
            } else {
              throw JavascriptError.invalid
            }
          }
        } catch {
          return ("", error)
        }
      } else {
        sanitizedArgs.append("null")
      }
    }

    if args.count != sanitizedArgs.count {
      assertionFailure("Javascript parsing failed.")
      return ("", JavascriptError.invalid)
    }

    return ("\(functionName)(\(sanitizedArgs.joined(separator: ", ")))", nil)
  }

  func evaluateSafeJavaScript(functionName: String, args: [Any] = [], frame: WKFrameInfo? = nil, contentWorld: WKContentWorld, escapeArgs: Bool = true, asFunction: Bool = true, completion: ((Any?, Error?) -> Void)? = nil) {
    var javascript = functionName

    if asFunction {
      let js = generateJSFunctionString(functionName: functionName, args: args, escapeArgs: escapeArgs)
      if js.error != nil {
        if let completionHandler = completion {
          completionHandler(nil, js.error)
        }
        return
      }
      javascript = js.javascript
    }

    DispatchQueue.main.async {
      // swiftlint:disable:next safe_javascript
      self.evaluateJavaScript(javascript, in: frame, in: contentWorld) { result in
        switch result {
        case .success(let value):
          completion?(value, nil)
        case .failure(let error):
          completion?(nil, error)
        }
      }
    }
  }
  
  @discardableResult @MainActor func evaluateSafeJavaScript(
    functionName: String,
    args: [Any] = [],
    contentWorld: WKContentWorld,
    escapeArgs: Bool = true,
    asFunction: Bool = true
  ) async -> (Any?, Error?) {
    await withCheckedContinuation { continuation in
      evaluateSafeJavaScript(
        functionName: functionName,
        args: args,
        contentWorld: contentWorld,
        escapeArgs: escapeArgs,
        asFunction: asFunction) { value, error in
          continuation.resume(returning: (value, error))
      }
    }
  }
}
