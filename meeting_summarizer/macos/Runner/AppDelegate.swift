import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var platformChannel: FlutterMethodChannel?
  private var statusBarItem: NSStatusItem?
  private var dockMenu: NSMenu?
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    setupPlatformChannel()
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func setupPlatformChannel() {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    
    platformChannel = FlutterMethodChannel(
      name: "com.yhsung.meeting_summarizer/macos_platform",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    platformChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }
  
  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      handleInitialize(result: result)
    case "setupSpotlightSearch":
      handleSetupSpotlightSearch(result: result)
    case "setupDockIntegration":
      handleSetupDockIntegration(result: result)
    case "setupTouchBar":
      handleSetupTouchBar(result: result)
    case "setupNotificationCenter":
      handleSetupNotificationCenter(result: result)
    case "setupServicesMenu":
      handleSetupServicesMenu(result: result)
    case "setupGlobalHotkeys":
      handleSetupGlobalHotkeys(result: result)
    case "setupFileAssociations":
      handleSetupFileAssociations(result: result)
    case "indexRecording":
      handleIndexRecording(call.arguments, result: result)
    case "removeFromIndex":
      handleRemoveFromIndex(call.arguments, result: result)
    case "setupDockMenu":
      handleSetupDockMenu(call.arguments, result: result)
    case "updateDockBadge":
      handleUpdateDockBadge(call.arguments, result: result)
    case "clearDockBadge":
      handleClearDockBadge(result: result)
    case "setupTouchBarControls":
      handleSetupTouchBarControls(call.arguments, result: result)
    case "updateTouchBar":
      handleUpdateTouchBar(call.arguments, result: result)
    case "setupNotificationCategories":
      handleSetupNotificationCategories(call.arguments, result: result)
    case "registerGlobalHotkeys":
      handleRegisterGlobalHotkeys(call.arguments, result: result)
    case "showApp":
      handleShowApp(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - Method Handlers
  
  private func handleInitialize(result: @escaping FlutterResult) {
    // Initialize platform-specific features
    result(true)
  }
  
  private func handleSetupSpotlightSearch(result: @escaping FlutterResult) {
    // TODO: Implement Core Spotlight integration
    // For now, return success as a placeholder
    result(true)
  }
  
  private func handleSetupDockIntegration(result: @escaping FlutterResult) {
    // Initialize dock integration
    setupDockIntegration()
    result(true)
  }
  
  private func handleSetupTouchBar(result: @escaping FlutterResult) {
    // TODO: Implement Touch Bar support
    // Check if Touch Bar is available
    if #available(macOS 10.12.2, *) {
      result(true)
    } else {
      result(false)
    }
  }
  
  private func handleSetupNotificationCenter(result: @escaping FlutterResult) {
    // TODO: Implement notification categories
    result(true)
  }
  
  private func handleSetupServicesMenu(result: @escaping FlutterResult) {
    // TODO: Implement Services menu integration
    result(true)
  }
  
  private func handleSetupGlobalHotkeys(result: @escaping FlutterResult) {
    // TODO: Implement global hotkey registration
    result(true)
  }
  
  private func handleSetupFileAssociations(result: @escaping FlutterResult) {
    // TODO: Implement file associations
    result(true)
  }
  
  private func handleIndexRecording(_ arguments: Any?, result: @escaping FlutterResult) {
    guard arguments is [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    // TODO: Implement Core Spotlight indexing
    result(nil)
  }
  
  private func handleRemoveFromIndex(_ arguments: Any?, result: @escaping FlutterResult) {
    guard arguments is [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    // TODO: Implement Core Spotlight removal
    result(nil)
  }
  
  private func handleSetupDockMenu(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let menuItems = args["menuItems"] as? [[String: Any]] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    setupDockMenu(with: menuItems)
    result(nil)
  }
  
  private func handleUpdateDockBadge(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }
    
    let recordingCount = args["recordingCount"] as? Int
    let isRecording = args["isRecording"] as? Bool ?? false
    
    updateDockBadge(recordingCount: recordingCount, isRecording: isRecording)
    result(nil)
  }
  
  private func handleClearDockBadge(result: @escaping FlutterResult) {
    NSApp.dockTile.badgeLabel = nil
    result(nil)
  }
  
  private func handleSetupTouchBarControls(_ arguments: Any?, result: @escaping FlutterResult) {
    // TODO: Implement Touch Bar controls setup
    result(nil)
  }
  
  private func handleUpdateTouchBar(_ arguments: Any?, result: @escaping FlutterResult) {
    // TODO: Implement Touch Bar updates
    result(nil)
  }
  
  private func handleSetupNotificationCategories(_ arguments: Any?, result: @escaping FlutterResult) {
    // TODO: Implement notification categories
    result(nil)
  }
  
  private func handleRegisterGlobalHotkeys(_ arguments: Any?, result: @escaping FlutterResult) {
    // TODO: Implement global hotkey registration
    result(nil)
  }
  
  private func handleShowApp(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      if let window = NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
      }
    }
    result(nil)
  }
  
  // MARK: - Dock Integration
  
  private func setupDockIntegration() {
    // Initialize dock menu
    dockMenu = NSMenu()
    NSApp.dockTile.contentView = NSView()
  }
  
  private func setupDockMenu(with menuItems: [[String: Any]]) {
    dockMenu?.removeAllItems()
    
    for itemData in menuItems {
      guard let title = itemData["title"] as? String,
            let action = itemData["action"] as? String else {
        continue
      }
      
      let menuItem = NSMenuItem(title: title, action: #selector(dockMenuItemClicked(_:)), keyEquivalent: "")
      menuItem.representedObject = action
      menuItem.target = self
      
      if let enabled = itemData["enabled"] as? Bool {
        menuItem.isEnabled = enabled
      }
      
      dockMenu?.addItem(menuItem)
    }
    
    // Note: NSApp.dockTile.contextualMenu is not available on macOS
    // Dock menu functionality would be implemented differently in a full implementation
  }
  
  @objc private func dockMenuItemClicked(_ sender: NSMenuItem) {
    guard let action = sender.representedObject as? String else { return }
    
    platformChannel?.invokeMethod("onDockAction", arguments: [
      "action": action,
      "parameters": [:]
    ])
  }
  
  private func updateDockBadge(recordingCount: Int?, isRecording: Bool) {
    DispatchQueue.main.async {
      if isRecording {
        NSApp.dockTile.badgeLabel = "●"
      } else if let count = recordingCount, count > 0 {
        NSApp.dockTile.badgeLabel = String(count)
      } else {
        NSApp.dockTile.badgeLabel = nil
      }
    }
  }
  
  // MARK: - File Handling
  
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    // Handle files opened with the app
    let audioFiles = filenames.filter { filename in
      let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma"]
      let fileExtension = (filename as NSString).pathExtension.lowercased()
      return audioExtensions.contains(fileExtension)
    }
    
    if !audioFiles.isEmpty {
      platformChannel?.invokeMethod("onFilesDropped", arguments: [
        "filePaths": audioFiles,
        "dropTarget": "app"
      ])
    }
  }
}
