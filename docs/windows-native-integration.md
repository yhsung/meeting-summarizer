# Windows Native Integration Guide

This document outlines the native Windows integrations required for the Meeting Summarizer Windows Platform Service implementation.

## Overview

The Windows Platform Service provides comprehensive integration with Windows-specific features through method channels and native implementations. This guide details the required native code implementations and API integrations.

## Method Channels

### Main Platform Channel
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_platform`
- **Purpose**: Core Windows platform service communication

#### Methods

| Method | Parameters | Return | Description |
|--------|------------|--------|-------------|
| `initialize` | None | `bool` | Initialize native Windows platform integration |
| `checkBiometricSupport` | None | `bool` | Check if Windows Hello is available |
| `authenticateBiometric` | `reason`, `allowCredentialManager`, `allowPin`, `allowPassword` | `bool` | Authenticate with Windows Hello |

#### Callbacks from Native

| Method | Parameters | Description |
|--------|------------|-------------|
| `onTrayAction` | `action`, `parameters` | System tray action triggered |
| `onNotificationAction` | `notificationId`, `action` | Notification action clicked |
| `onJumplistAction` | `action`, `parameters` | Jump list item clicked |
| `onFileOpened` | `filePath` | File opened via association |
| `onTaskbarStateChanged` | `isActive` | Taskbar state changed |
| `onBiometricResult` | `success`, `error` | Biometric authentication result |

### Sub-Service Channels

#### Windows Notifications
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_notifications`
- **Purpose**: Toast notifications and Windows 10/11 notification integration

#### Windows Jump Lists
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_jumplist`
- **Purpose**: Taskbar jump list management

#### Windows Registry
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_registry`
- **Purpose**: Registry operations and file associations

#### Windows Taskbar
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_taskbar`
- **Purpose**: Taskbar integration, progress, overlays, thumbnails

#### Windows Clipboard
- **Channel Name**: `com.yhsung.meeting_summarizer/windows_clipboard`
- **Purpose**: Rich clipboard operations

## Native Implementation Requirements

### 1. Windows System Tray Integration

#### Required APIs
- `Shell_NotifyIcon` for system tray management
- `CreateMenu` / `AppendMenu` for context menus
- `RegisterWindowMessage` for custom messages

#### Implementation Details
```cpp
// System tray setup
NOTIFYICONDATA nid = {};
nid.cbSize = sizeof(NOTIFYICONDATA);
nid.hWnd = hwnd;
nid.uID = TRAY_ICON_ID;
nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
nid.uCallbackMessage = WM_TRAY_ICON;
nid.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_ICON));
wcscpy_s(nid.szTip, L"Meeting Summarizer");

Shell_NotifyIcon(NIM_ADD, &nid);
```

#### Required Features
- Dynamic icon updates for recording states
- Context menu with recording controls
- Tooltip updates
- Balloon notifications
- File association handling

### 2. Windows 10/11 Toast Notifications

#### Required APIs
- Windows Runtime APIs (`WinRT`)
- `Windows.UI.Notifications` namespace
- `ToastNotificationManager`
- `ToastNotification`

#### Implementation Details
```cpp
// Toast notification creation
auto notificationManager = ToastNotificationManager::CreateToastNotifier();
auto toastXml = ToastNotificationManager::GetTemplateContent(ToastTemplateType::ToastText02);

// Set notification content
auto textElements = toastXml.GetElementsByTagName(L"text");
textElements.Item(0).AppendChild(toastXml.CreateTextNode(title));
textElements.Item(1).AppendChild(toastXml.CreateTextNode(body));

// Create and show notification
auto toast = ref new ToastNotification(toastXml);
notificationManager.Show(toast);
```

#### Required Features
- Custom notification templates
- Action buttons
- Progress indicators
- Rich content (images, sounds)
- Notification groups
- Action handling callbacks

### 3. Jump Lists Integration

#### Required APIs
- `ICustomDestinationList`
- `IObjectArray`
- `IShellLink`
- `IPropertyStore`

#### Implementation Details
```cpp
// Jump list creation
Microsoft::WRL::ComPtr<ICustomDestinationList> destinationList;
CoCreateInstance(CLSID_DestinationList, nullptr, 
                 CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&destinationList));

UINT maxSlots;
Microsoft::WRL::ComPtr<IObjectArray> removedItems;
destinationList->BeginList(&maxSlots, IID_PPV_ARGS(&removedItems));

// Add custom tasks
Microsoft::WRL::ComPtr<IObjectCollection> taskCollection;
CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                 CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&taskCollection));

// Create shell link for task
Microsoft::WRL::ComPtr<IShellLink> shellLink;
CoCreateInstance(CLSID_ShellLink, nullptr,
                 CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&shellLink));

shellLink->SetPath(applicationPath);
shellLink->SetArguments(L"--action=start_recording");
shellLink->SetDescription(L"Start Recording");

taskCollection->AddObject(shellLink.Get());
destinationList->AddUserTasks(taskCollection.Get());
destinationList->CommitList();
```

#### Required Features
- Dynamic task creation
- Recent items management
- Custom categories
- File associations
- Action argument parsing

### 4. Registry Integration

#### Required APIs
- `RegCreateKeyEx`
- `RegSetValueEx`
- `RegQueryValueEx`
- `RegDeleteKey`
- `RegDeleteValue`

#### Implementation Details
```cpp
// File association registration
HKEY hKey;
LONG result = RegCreateKeyEx(HKEY_CLASSES_ROOT, L".ms-recording",
                            0, nullptr, REG_OPTION_NON_VOLATILE,
                            KEY_WRITE, nullptr, &hKey, nullptr);

if (result == ERROR_SUCCESS) {
    RegSetValueEx(hKey, nullptr, 0, REG_SZ,
                  (BYTE*)L"MeetingSummarizer.Recording",
                  sizeof(L"MeetingSummarizer.Recording"));
    RegCloseKey(hKey);
}

// Program ID registration
result = RegCreateKeyEx(HKEY_CLASSES_ROOT, L"MeetingSummarizer.Recording",
                       0, nullptr, REG_OPTION_NON_VOLATILE,
                       KEY_WRITE, nullptr, &hKey, nullptr);

if (result == ERROR_SUCCESS) {
    RegSetValueEx(hKey, nullptr, 0, REG_SZ,
                  (BYTE*)L"Meeting Summarizer Recording",
                  sizeof(L"Meeting Summarizer Recording"));
    RegCloseKey(hKey);
}
```

#### Required Features
- File type registration
- Context menu entries
- Startup configuration
- Application settings storage
- UAC elevation handling

### 5. Taskbar Integration

#### Required APIs
- `ITaskbarList3`
- `ITaskbarList4`
- `SetProgressValue`
- `SetProgressState`
- `SetOverlayIcon`
- `SetThumbnailTooltip`

#### Implementation Details
```cpp
// Taskbar progress
Microsoft::WRL::ComPtr<ITaskbarList3> taskbarList;
CoCreateInstance(CLSID_TaskbarList, nullptr,
                 CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&taskbarList));

taskbarList->HrInit();
taskbarList->SetProgressValue(hwnd, progress, 100);
taskbarList->SetProgressState(hwnd, TBPF_NORMAL);

// Overlay icon
HICON overlayIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_RECORDING));
taskbarList->SetOverlayIcon(hwnd, overlayIcon, L"Recording");

// Thumbnail toolbar
THUMBBUTTON buttons[3] = {};
buttons[0].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
buttons[0].iId = ID_START_RECORDING;
buttons[0].hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_START));
wcscpy_s(buttons[0].szTip, L"Start Recording");
buttons[0].dwFlags = THBF_ENABLED;

taskbarList->ThumbBarAddButtons(hwnd, ARRAYSIZE(buttons), buttons);
```

#### Required Features
- Progress indicators
- Overlay icons
- Thumbnail toolbars
- Live thumbnails
- Preview windows
- Flash notifications

### 6. Clipboard Integration

#### Required APIs
- `OpenClipboard`
- `SetClipboardData`
- `GetClipboardData`
- `RegisterClipboardFormat`
- `AddClipboardFormatListener`

#### Implementation Details
```cpp
// Rich clipboard data
if (OpenClipboard(hwnd)) {
    EmptyClipboard();
    
    // Set plain text
    HGLOBAL hText = GlobalAlloc(GMEM_MOVEABLE, (textData.size() + 1) * sizeof(wchar_t));
    wcscpy_s((wchar_t*)GlobalLock(hText), textData.size() + 1, textData.c_str());
    GlobalUnlock(hText);
    SetClipboardData(CF_UNICODETEXT, hText);
    
    // Set HTML format
    UINT htmlFormat = RegisterClipboardFormat(L"HTML Format");
    HGLOBAL hHtml = GlobalAlloc(GMEM_MOVEABLE, htmlData.size() + 1);
    strcpy_s((char*)GlobalLock(hHtml), htmlData.size() + 1, htmlData.c_str());
    GlobalUnlock(hHtml);
    SetClipboardData(htmlFormat, hHtml);
    
    // Set custom format
    UINT customFormat = RegisterClipboardFormat(L"MeetingSummarizerData");
    HGLOBAL hCustom = GlobalAlloc(GMEM_MOVEABLE, customData.size());
    memcpy(GlobalLock(hCustom), customData.data(), customData.size());
    GlobalUnlock(hCustom);
    SetClipboardData(customFormat, hCustom);
    
    CloseClipboard();
}
```

#### Required Features
- Multiple format support
- Rich text formatting
- Custom data formats
- Clipboard monitoring
- Large data handling

### 7. Windows Hello Biometric Authentication

#### Required APIs
- `Windows.Security.Credentials.UI`
- `UserConsentVerifier`
- `Windows.Security.Credentials`

#### Implementation Details
```cpp
// Windows Hello authentication
auto verifier = Windows::Security::Credentials::UI::UserConsentVerifier;
auto availability = co_await verifier.CheckAvailabilityAsync();

if (availability == Windows::Security::Credentials::UI::UserConsentVerifierAvailability::Available) {
    auto result = co_await verifier.RequestVerificationAsync(reason);
    
    if (result == Windows::Security::Credentials::UI::UserConsentVerificationResult::Verified) {
        // Authentication successful
        return true;
    }
}
return false;
```

#### Required Features
- Biometric availability check
- Multiple authentication methods
- PIN fallback
- Credential manager integration
- Error handling

## Build Configuration

### CMakeLists.txt Updates
```cmake
# Windows-specific libraries
if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        shell32
        user32
        ole32
        oleaut32
        uuid
        comctl32
        gdi32
        winmm
        windowsapp  # For WinRT APIs
    )
    
    # Enable WinRT support
    target_compile_definitions(${PROJECT_NAME} PRIVATE WINRT_LEAN_AND_MEAN)
    set_property(TARGET ${PROJECT_NAME} PROPERTY VS_WINRT_COMPONENT TRUE)
endif()
```

### Resource Files
- `resources.rc` - Icons, strings, version info
- `tray_icon.ico` - System tray icon
- `recording_icon.ico` - Recording state icon
- `notification_icon.ico` - Notification icon
- Various action icons for taskbar and jump lists

## Security Considerations

### UAC (User Account Control)
- Registry operations may require elevation
- File association registration requires admin rights
- Provide graceful fallbacks for limited permissions

### Code Signing
- Required for Windows SmartScreen compatibility
- Necessary for Windows Store distribution
- Jump lists and notifications work better with signed apps

### Privacy
- Clipboard monitoring requires user consent
- Biometric data handling must follow Windows guidelines
- File associations should be reversible

## Error Handling

### Platform Availability
```cpp
// Check Windows version
OSVERSIONINFOEX osvi = {};
osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
GetVersionEx((OSVERSIONINFO*)&osvi);

bool isWindows10OrLater = (osvi.dwMajorVersion >= 10);
```

### API Failure Handling
- Graceful degradation when APIs unavailable
- Comprehensive error reporting
- Fallback implementations for older Windows versions

## Testing Requirements

### Unit Tests
- Mock Windows APIs for testing
- Platform detection tests
- Error condition handling

### Integration Tests
- Real Windows API testing
- Multi-version compatibility
- Performance benchmarks

### Manual Testing
- Different Windows versions (10, 11)
- Various permission levels
- Multiple monitor configurations
- High DPI scaling

## Dependencies

### Required Packages
- Windows SDK 10.0.19041.0 or later
- Visual Studio 2019 or later with C++/WinRT support
- CMake 3.16 or later

### Runtime Requirements
- Windows 10 version 1903 or later (for full feature support)
- .NET Framework 4.7.2 or later
- Visual C++ Redistributable

## Implementation Priority

1. **Phase 1**: System tray and basic notifications
2. **Phase 2**: Jump lists and registry integration
3. **Phase 3**: Taskbar integration and progress indicators
4. **Phase 4**: Rich clipboard and biometric authentication
5. **Phase 5**: Advanced features and optimizations

## Future Enhancements

- Windows 11 context menu integration
- Timeline API integration
- Cortana skill development
- Microsoft Graph integration
- Windows Subsystem for Linux (WSL) support

---

This implementation provides comprehensive Windows integration while maintaining compatibility and graceful fallbacks for various system configurations.