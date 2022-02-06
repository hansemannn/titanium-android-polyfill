//
//  TiPolyfillModule.swift
//  titanium-polyfill
//
//  Created by Hans Knöchel
//  Copyright (c) 2022 Hans Knöchel
//

import UIKit
import TitaniumKit

@objc(TiPolyfillModule)
class TiPolyfillModule: TiModule {

  public let testProperty: String = "Hello World"
  
  func moduleGUID() -> String {
    return "79b0059b-4142-47d3-8bac-586c5a859586"
  }
  
  override func moduleId() -> String! {
    return "ti.polyfill"
  }

  @objc(isDarkImage:)
  func isDarkImage(args: [Any]) -> Bool {
    guard let imageProxy = args.first else { return false }
    guard let image = TiUtils.image(imageProxy, proxy: self) else { return false }
  
    return image.ti_isDark
  }
}

extension CGImage {
    var ti_isDark: Bool {
        get {
            guard let imageData = self.dataProvider?.data else { return false }
            guard let ptr = CFDataGetBytePtr(imageData) else { return false }
            let length = CFDataGetLength(imageData)
            let threshold = Int(Double(self.width * self.height) * 0.45)
            var darkPixels = 0

            for i in stride(from: 0, to: length, by: 4) {
                let r = ptr[i]
                let g = ptr[i + 1]
                let b = ptr[i + 2]
                let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                if luminance < 150 {
                    darkPixels += 1
                    if darkPixels > threshold {
                        return true
                    }
                }
            }
            return false
        }
    }
}

extension UIImage {
    var ti_isDark: Bool {
        get {
            return self.cgImage?.ti_isDark ?? false
        }
    }
}
