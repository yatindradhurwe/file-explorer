# 🚀 Google Play Store Listing & Deployment Guide
**App Name:** File Explore  
**Tagline / Developer:** Design by yjtechnosoft  
**Package ID:** `com.yjtechnosoft.fileexplorer`  
**Target SDK:** 36 (Android 16 Ready) | **Min SDK:** 24 (Android 7.0+)  
**Version Code:** `2` | **Version Name:** `1.0.1`  

---

## 📱 Store Metadata Details

### 1. App Title (Max 30 characters)
```text
File Explore: Quick File Manager
```
*(Alternative: `File Explore - yjtechnosoft`)*

---

### 2. Short Description (Max 80 characters)
```text
Smart file manager with instant QuickDrop peer-to-peer file transfer & storage tools.
```
*(78 characters)*

---

### 3. Full Description (Max 4,000 characters)

```text
⚡ File Explore by yjtechnosoft — The all-in-one ultra-fast file manager, wireless QuickDrop transfer, mobile document scanner, PDF reader, and Office suite!

Designed with a sleek, premium interface and lightning-speed performance, File Explore gives you total control over your device's internal storage, SD card, and downloaded media. Seamlessly manage, organize, and transfer documents, images, videos, audio, APKs, and archives.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌟 KEY FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ QUICKDROP — INSTANT OFFLINE FILE TRANSFER
• Experience Apple AirDrop-like peer-to-peer file sharing directly on Android!
• Transfer gigabytes of photos, videos, documents, and apps in milliseconds over your local Wi-Fi / hotspot network.
• Zero internet data required — 100% offline, private, and secure.
• Real-time animated radar discovery finds nearby devices instantly.
• High-speed streaming engine with live transfer percentage and transfer history.

📷 SMART DOCUMENT SCANNER (ADOBE SCAN EXPERIENCE)
• Auto Document Corner Detection: Automatically detects paper edges and boundaries.
• 4-Corner Draggable Cropping: Interactive polygon handles with magnifying grid for pixel-perfect edge alignment.
• Professional Document Filters: Magic Color (vibrant contrast), B&W Clean Document, Grayscale, Lighten, and Original.
• Document Transforms: 90° Clockwise/Counter-Clockwise Rotation & Horizontal/Vertical Flipping.
• Multi-Page Batch Scanning: Scan multiple pages, reorder, delete, and export directly as crystal-clear A4 PDF files.

📑 BUILT-IN PDF READER & OFFICE SUITE
• Built-in PDF Viewer: Night mode invert, smooth page navigation, jump to page, and instant sharing.
• Excel & Spreadsheet Viewer: Interactive data table viewer for CSV, TSV, XLSX, and XLS sheets.
• PowerPoint & Word Support: Inspect and launch PPT, PPTX, DOC, and DOCX files effortlessly.
• Tabbed Document Hub: Dedicated tabs for quick filtering across PDF, Excel, PowerPoint, and Word docs.

🎬 UNIVERSAL VIDEO & MEDIA ENGINE
• Universal Video Support: Plays and indexes 45+ video formats (.mp4, .mkv, .mov, .avi, .webm, .3gp, .ts, .mts, .flv, .vob, .divx, .m4v, .rmvb, and more).
• Deep Multi-Directory Crawler: Instantly indexes videos across DCIM, Camera, Movies, WhatsApp, Telegram, Bluetooth, and custom folders.
• One-Tap System Player Integration: Launch with VLC, MX Player, Google Photos, or your preferred player.

📊 INTUITIVE STORAGE ANALYTICS & DASHBOARD
• Luxury dual-gradient storage visualizer displaying real-time Used vs. Free space.
• One-tap access to smart auto-organized categories:
  - 📷 Photos & Images
  - 🎬 Videos & Movies (all formats)
  - 🎵 Music & Audio tracks
  - 📄 Documents (PDF, DOCX, XLSX, TXT)
  - 📦 APK Application Installers
  - 🗜️ ZIP, RAR, 7Z Archives
  - 💻 Code & Script files
  - 📁 Other uncategorized files

📁 FULL-FEATURED FILE MANAGER & SIDE DRAWER
• Convenient Side Menu Drawer: Fast navigation to Doc Scanner, PDF Reader, Office Tools, QuickDrop, and Settings.
• Seamless Navigation: Smooth breadcrumb pill navigation for effortless directory jumping.
• Complete File Operations: Cut, Copy, Paste, Rename, Delete, Share, and Multi-select batch actions.
• View Switching: Toggle instantly between modern compact List View and high-density Grid View.
• Sorting & Filtering: Sort files by Name, Size, Date Modified, or Type (Ascending/Descending).
• Hidden Files Support: Toggle display of hidden dotfiles and system directories anytime.

🔒 PRIVACY & SECURITY FIRST
• No tracking, no background telemetry, and no external cloud uploads.
• All peer-to-peer file transfers occur strictly over your local Wi-Fi or hotspot connection.
• You hold full ownership and encryption over your private data.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Designed & Developed with ❤️ by yjtechnosoft
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔑 Keystore & Signing Credentials

| Parameter | Value |
|---|---|
| **Keystore File** | `android/app/upload-keystore.jks` |
| **Keystore Password** | `FileExplorer2026!` |
| **Key Alias** | `upload` |
| **Key Password** | `FileExplorer2026!` |
| **Validity** | 10,000 days (until year 2054) |
| **SHA-256 Fingerprint** | Generated in build log |

> ⚠️ **IMPORTANT**: Backup `android/app/upload-keystore.jks` and `android/key.properties` to a secure offline vault. If lost, Google Play will not allow updates to this package name.

---

## 📦 Release Artifacts

- **Google Play App Bundle (AAB):**  
  `playstore/app-release.aab`
- **Store Icon (512 x 512 px):**  
  `playstore/graphics/app_icon_512.jpg`
- **Feature Graphic (1024 x 500 px):**  
  `playstore/graphics/feature_graphic_1024x500.jpg`
- **App Screenshots:**  
  `playstore/screenshots/`

---

## 📋 Step-by-Step Google Play Console Upload Guide

### Step 1: Create Your App on Google Play Console
1. Go to [Google Play Console](https://play.google.com/console).
2. Click **Create app**.
3. Enter App name: **File Explore**.
4. Default language: **English (United States)** (or your preferred locale).
5. App or game: **App**; Free or paid: **Free**.
6. Accept Declarations and click **Create app**.

### Step 2: Set Up Store Listing Assets
1. Navigate to **Grow** > **Store presence** > **Main store listing**.
2. Paste the **Short description** and **Full description** from above.
3. Upload **App icon**: `playstore/graphics/app_icon_512.jpg`.
4. Upload **Feature graphic**: `playstore/graphics/feature_graphic_1024x500.jpg`.
5. Upload phone screenshots from `playstore/screenshots/` (minimum 4, up to 8).
6. Click **Save**.

### Step 3: Complete App Content Declarations
Under **Policy** > **App content**, complete each required questionnaire:
1. **Privacy Policy**: Provide URL pointing to your hosted `PRIVACY_POLICY.md`.
2. **App Access**: Choose "All functionality is available without special access".
3. **Ads**: Choose "No, my app does not contain ads".
4. **Content Ratings**: Complete the questionnaire (Utility/Tools category). Expected rating: **Everyone (3+)**.
5. **Target Audience**: Select age group **18 and over** or **13-17, 18 and over**.
6. **Data Safety**:
   - Data collection: No user data is collected or shared with third parties.
   - All network transfers are peer-to-peer over local network.
7. **All Files Access (`MANAGE_EXTERNAL_STORAGE`) Declaration**:
   - **Describe one feature in your app that requires a permitted use (Max 500 characters):**
     ```text
     File Explore is a full-featured file manager whose primary purpose is device-wide file organization. The app enables users to browse, search, copy, move, rename, delete, and organize all file types across internal storage and SD cards, including ZIP archives, APK installers, PDFs, documents, code files, and custom directories. Without All Files Access, users cannot manage or organize non-media files or navigate complete directory structures outside restricted shared media folders.
     ```
   - **Usage (Select all that apply):**
     - Select: `[x] Core functionality` *(Do NOT select Ads or Analytics)*
   - **Technical reason (Max 500 characters):**
     ```text
     MediaStore API is strictly limited to media files (photos, videos, audio) and cannot index, discover, or manage essential file manager items such as APKs, ZIP/RAR archives, code, and document trees. Storage Access Framework (SAF) creates unacceptable friction for a primary file manager by requiring manual system picker prompts for every single directory access, making system-wide search, batch file operations (copy, move, delete), and seamless breadcrumb directory navigation impossible.
     ```
   - **Video instructions:**
     - Pre-recorded 22-second demonstration video is available at `playstore/manage_storage_demo.mp4`.
     - Upload this video to Google Drive or YouTube (set as "Unlisted" or "Anyone with link can view") and paste the public link in the URL field.

### Step 4: Create a Release and Upload AAB
1. Navigate to **Release** > **Testing** > **Internal testing** (recommended first) or **Production**.
2. Click **Create new release**.
3. Enable **Play App Signing** (Google manages signing key).
4. Drag and drop `playstore/app-release.aab`.
5. Enter Release name: `1.0.1 (2)`.
6. Add Release notes:
   ```text
   Initial official release of File Explore:
   - Complete file management & category filters
   - High-speed peer-to-peer QuickDrop file sharing
   - Built-in text editor and zoomable photo viewer
   - Storage dashboard with modern Material 3 theme
   ```
7. Click **Next** > **Save** > **Start rollout**!
