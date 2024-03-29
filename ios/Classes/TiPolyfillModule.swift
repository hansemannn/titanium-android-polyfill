//
//  TiPolyfillModule.swift
//  titanium-polyfill
//
//  Created by Hans Knöchel
//  Copyright (c) 2022 Hans Knöchel
//

import UIKit
import AVKit
import TitaniumKit

@objc(TiPolyfillModule)
class TiPolyfillModule: TiModule {
  
  var tabGroupHeight = 0.0
    
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
  
  @objc(formattedDateRange:)
  func formattedDateRange(args: [Any]) -> String? {
    guard let params = args.first as? [String: String],
          let startDate = params["startDate"],
          let endDate = params["endDate"] else {
      fatalError("Invalid parameters")
    }
    
    let formatter = DateIntervalFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    
    let dateFormatter = DateFormatter()
    guard let startDateNative = dateFormatter.date(from: startDate),
          let endDateNative = dateFormatter.date(from: endDate) else {
      return nil
    }
    
    return formatter.string(from: startDateNative, to: endDateNative)
  }
  
  @objc(openFullscreenVideoPlayer:)
  func openFullscreenVideoPlayer(args: [Any]) {
    guard let params = args.first as? [String: Any] else { return }
    guard let url = params["url"] as? String else { return }
    
    let player = AVPlayer(url: URL(string: url)!)
    let vc = AVPlayerViewController()
    vc.player = player
    vc.modalPresentationStyle = .overFullScreen;
    
    TiThreadPerformOnMainThread({
      TiApp.controller().topPresentedController().present(vc, animated: true) {
        let selectorName: String = {
          if #available(iOS 11.3, *) {
            return "_transitionToFullScreenAnimated:interactive:completionHandler:"
          } else {
            return "_transitionToFullScreenAnimated:completionHandler:"
          }
        }()
        let selectorToForceFullScreenMode = NSSelectorFromString(selectorName)
        
        if vc.responds(to: selectorToForceFullScreenMode) {
          vc.perform(selectorToForceFullScreenMode, with: true, with: nil)
        }
        vc.player?.play()
      }
    }, false)
  }
  
  @objc(isAppInstalled:)
  func isAppInstalled(args: [Any]?) -> Bool {
    guard let packageId = args?.first as? String, let url = URL(string: "\(packageId)://") else {
      return false
    }
    
    return UIApplication.shared.canOpenURL(url)
  }
  
  @objc(relativeDateString:)
  func relativeDateString(args: [Any]) -> String {
    guard let date = args.first as? Date else {
      fatalError("Missing date")
    }
    
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    
    return formatter.localizedString(for: date, relativeTo: Date())
  }
  
  @objc(startListeningForKeyboardUpdates:)
  func startListeningForKeyboardUpdates(params: [Any]) {
    if let params = params.first as? [String: Any],
       let tabGroupProxy = params["tabGroup"] as? TiWindowProxy,
       let tabGroup = tabGroupProxy.value(forKey: "tabbar") as? UITabBar {
      self.tabGroupHeight = tabGroup.bounds.height
    }

    // Notifications for when the keyboard opens/closes
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.keyboardWillShow),
        name: UIResponder.keyboardWillShowNotification,
        object: nil)

    NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.keyboardWillHide),
        name: UIResponder.keyboardWillHideNotification,
        object: nil)
  }
  
  @objc(stopListeningForKeyboardUpdates:)
  func stopListeningForKeyboardUpdates(params: [Any]) {
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    
    self.tabGroupHeight = 0.0
  }
  
  @objc func keyboardWillShow(_ notification: NSNotification) {
    moveViewWithKeyboard(notification: notification, keyboardWillShow: true)
  }
  
  @objc func keyboardWillHide(_ notification: NSNotification) {
    moveViewWithKeyboard(notification: notification, keyboardWillShow: false)
  }
  
  func moveViewWithKeyboard(notification: NSNotification, keyboardWillShow: Bool) {
    // Keyboard's size
    guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
    let keyboardHeight = keyboardSize.height
    
    // Keyboard's animation duration (in ms)
    let keyboardDuration = notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as! Double * 1000
    
    // Keyboard's animation curve
    let keyboardCurve = UIView.AnimationCurve(rawValue: notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as! Int)!
    
    // Change the constant
    fireEvent("keyboardChanged", with: [
      "transitionType": keyboardWillShow ? "show" : "hide",
      "bottomSpacing": keyboardWillShow ? keyboardHeight - tabGroupHeight : 0,
      "duration": keyboardDuration,
      "curve": keyboardCurve.rawValue
    ] as [String : Any])
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
