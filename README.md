# 📁 Mobile File Explorer (Flutter)

A modern, high-performance, and full-featured File Explorer application built in Flutter for mobile devices (Android & iOS). Manage, organize, browse, edit, and share files and directories on your mobile phone with ease.

### ⚡ 7. QuickDrop (Apple AirDrop-style Instant Transfer in Milliseconds)
- **High-Speed Direct P2P Transfer**: Streams files directly device-to-device over raw local TCP sockets at full local Wi-Fi / hotspot speed (up to 50–100+ MB/s, transferring in milliseconds).
- **Sub-50ms UDP Radar Discovery**: Automatically detects nearby devices on the local network via periodic UDP broadcast beacons.
- **AirDrop Radar UI**: Concentric pulsating animated radar with device bubbles floating around your avatar. Simply tap a nearby device bubble to drop files.
- **Universal WebDrop (No App Needed for PC / Mac / iPhone)**: Embedded local HTTP server with a QR Code and local link (`http://192.168.x.x:53319`). Any browser on a computer or iPhone can scan the QR code to immediately download or upload files to your phone.
- **Auto-Save to Download/FileDrop**: Received files are automatically saved and trigger a direct "Open" notification.

---

## ✨ Features

### 🗂️ 1. Complete File & Directory Management (CRUD)
- **Create Folder & File**: Easily create new directories and text files anywhere in storage.
- **Copy & Cut (Move)**: Select files/folders and use the persistent bottom clipboard banner to paste them into any target directory.
- **Batch Operations**: Multi-selection mode (tap or long-press) with Select All, Batch Delete, Batch Share, Batch Copy, and Batch Move.
- **Rename**: Rename any file or directory with validation to avoid name collisions.
- **Delete**: Safe deletion with confirmation dialogs.
- **Open With**: Launch files using external apps registered on the device (PDF readers, media players, Office suites, APK installers) via `open_filex`.
- **Share**: Direct integration with native mobile share sheets via `share_plus`.

### 🧭 2. Intelligent Storage & Breadcrumb Navigation
- **Storage Overview**: Visual card displaying internal storage and SD card usage (Total, Used, Free space) with percentage bars.
- **Interactive Breadcrumb Bar**: Tap any folder in the breadcrumb trail to instantly jump back up the directory hierarchy.
- **Quick Access Shortcuts**: Instant one-tap access to common folders: `Downloads`, `DCIM / Photos`, `Documents`, `Music`, `Movies`, and `WhatsApp Media`.
- **Show / Hide Hidden Files**: Toggle visibility of dotfiles (e.g. `.nomedia`, `.git`).

### 🏷️ 3. Categorized File Browser
- Filter storage by media and file types:
  - 🖼️ **Images** (JPG, PNG, GIF, WebP, SVG, HEIC)
  - 🎬 **Videos** (MP4, MKV, MOV, AVI, WEBM, 3GP)
  - 🎵 **Audio** (MP3, WAV, AAC, FLAC, M4A, OGG)
  - 📄 **Documents** (PDF, DOCX, XLSX, PPTX, TXT, RTF)
  - 📦 **APKs / Apps** (APK, XAPK)
  - 🗜️ **Archives** (ZIP, RAR, 7Z, TAR, GZ)
  - 💻 **Code & Text** (Dart, Python, JS, HTML, CSS, JSON, XML, SQL, Markdown)
  - 📂 **Others**
- Real-time search inside categories.

### 📝 4. Built-in Text Editor & Viewer
- Open and edit code, configuration, and text files directly inside the app without needing a third-party app.
- Supports `.txt`, `.md`, `.json`, `.xml`, `.dart`, `.py`, `.html`, `.css`, `.csv`, `.log`, and more.
- Line numbers, character count, and unsaved changes confirmation dialog.

### 🔍 5. Interactive Image Viewer
- Full-screen image preview with pinch-to-zoom (`InteractiveViewer`).
- Built-in sharing, file details sheet, and deletion actions.

### 🎨 6. Modern Material 3 UI / UX
- **Grid View & List View**: Toggle between a dense list view and an expansive card grid view with a single tap.
- **Sorting Options**: Sort by Name, Date Modified, Size, or File Type in Ascending or Descending order.
- **Light & Dark Themes**: Modern Royal Blue theme with automatic dark mode support.
- **File Details Sheet**: View full path, file size in bytes and human-readable format, last modified timestamp, and MIME type with quick path copy.

### ⚡ 7. QuickDrop (Apple AirDrop-style Instant Transfer in Milliseconds)
- **High-Speed Direct P2P Transfer**: Streams files directly device-to-device over raw local TCP sockets at full local Wi-Fi / hotspot speed (up to 50–100+ MB/s, transferring in milliseconds).
- **Sub-50ms UDP Radar Discovery**: Automatically detects nearby devices on the local network via periodic UDP broadcast beacons.
- **AirDrop Radar UI**: Concentric pulsating animated radar with device bubbles floating around your avatar. Simply tap a nearby device bubble to drop files.
- **Universal WebDrop (No App Needed for PC / Mac / iPhone)**: Embedded local HTTP server with a QR Code and local link (`http://192.168.x.x:53319`). Any browser on a computer or iPhone can scan the QR code to immediately download or upload files to your phone.
- **Auto-Save to Download/FileDrop**: Received files are automatically saved and trigger a direct "Open" notification.

---

## 🔒 Android Permissions & Scoped Storage

To manage **all files** across device storage on Android 11+ (API 30+), the app is configured with:
- `MANAGE_EXTERNAL_STORAGE` (All Files Access permission)
- `READ_EXTERNAL_STORAGE` & `WRITE_EXTERNAL_STORAGE` (for Android 10 and below)
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (for Android 13+)
- `requestLegacyExternalStorage="true"`

The app includes a dedicated **Permission Screen** that explains why storage access is required and guides the user to grant permission or configure system settings.

### ⚡ 7. QuickDrop (Apple AirDrop-style Instant Transfer in Milliseconds)
- **High-Speed Direct P2P Transfer**: Streams files directly device-to-device over raw local TCP sockets at full local Wi-Fi / hotspot speed (up to 50–100+ MB/s, transferring in milliseconds).
- **Sub-50ms UDP Radar Discovery**: Automatically detects nearby devices on the local network via periodic UDP broadcast beacons.
- **AirDrop Radar UI**: Concentric pulsating animated radar with device bubbles floating around your avatar. Simply tap a nearby device bubble to drop files.
- **Universal WebDrop (No App Needed for PC / Mac / iPhone)**: Embedded local HTTP server with a QR Code and local link (`http://192.168.x.x:53319`). Any browser on a computer or iPhone can scan the QR code to immediately download or upload files to your phone.
- **Auto-Save to Download/FileDrop**: Received files are automatically saved and trigger a direct "Open" notification.

---

## 🏗️ Project Architecture

```
lib/
├── main.dart                          # App entry point, Material 3 theming (Light/Dark)
├── models/
│   ├── file_item.dart                 # FileItem entity, categories, and sort options
│   ├── storage_info.dart              # Storage capacity and usage stats model
│   └── clipboard_item.dart            # In-app clipboard for Copy/Cut/Paste
├── services/
│   ├── permission_service.dart        # Android/iOS runtime permissions handling
│   ├── storage_service.dart           # Storage discovery, directory listing, recursive search
│   └── file_operations_service.dart   # File CRUD, copy/move, open, share, and text I/O
├── utils/
│   ├── app_state.dart                 # Global ChangeNotifier for theme, view mode, clipboard
│   └── file_utils.dart                # Byte formatting, date formatting, MIME types, category icons
├── widgets/
│   ├── breadcrumb_bar.dart            # Interactive path navigation bar
│   ├── storage_card.dart              # Storage capacity visual progress card
│   ├── category_grid.dart             # Quick category grid buttons
│   ├── file_tile.dart                 # List view file/folder tile with contextual menu
│   ├── file_grid_tile.dart            # Grid view file/folder card
│   ├── clipboard_banner.dart          # Floating action banner for Paste & Move operations
│   ├── file_details_sheet.dart        # Bottom sheet for file metadata and path copy
│   └── empty_state.dart               # Clean placeholder for empty folders or search
└── screens/
    ├── home_screen.dart               # Main dashboard (Storage, Categories, Quick Access)
    ├── explorer_screen.dart           # Primary directory browsing and file operations
    ├── category_screen.dart           # Filtered view by file category
    ├── search_screen.dart             # Storage-wide recursive file search
    ├── text_editor_screen.dart        # In-app text viewer & editor
    ├── image_viewer_screen.dart       # In-app photo viewer with zoom
    └── permission_screen.dart         # Guided storage permission onboarding
```

### ⚡ 7. QuickDrop (Apple AirDrop-style Instant Transfer in Milliseconds)
- **High-Speed Direct P2P Transfer**: Streams files directly device-to-device over raw local TCP sockets at full local Wi-Fi / hotspot speed (up to 50–100+ MB/s, transferring in milliseconds).
- **Sub-50ms UDP Radar Discovery**: Automatically detects nearby devices on the local network via periodic UDP broadcast beacons.
- **AirDrop Radar UI**: Concentric pulsating animated radar with device bubbles floating around your avatar. Simply tap a nearby device bubble to drop files.
- **Universal WebDrop (No App Needed for PC / Mac / iPhone)**: Embedded local HTTP server with a QR Code and local link (`http://192.168.x.x:53319`). Any browser on a computer or iPhone can scan the QR code to immediately download or upload files to your phone.
- **Auto-Save to Download/FileDrop**: Received files are automatically saved and trigger a direct "Open" notification.

---

## 🚀 Running the App

### On Android Mobile Device or Emulator:
1. Connect your Android phone via USB with USB Debugging enabled, or launch an Android emulator.
2. Run:
   ```bash
   flutter run
   ```
3. When prompted on first launch, tap **"Grant Storage Access"** and enable **"Allow management of all files"** in the Android system settings.

### Build APK:
```bash
flutter build apk --release
```
The generated APK will be at `build/app/outputs/flutter-apk/app-release.apk`.
