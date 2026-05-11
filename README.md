# FLACTagger

A native macOS app for managing FLAC music file metadata, solving the issue where macOS Finder cannot display FLAC album artwork.

![macOS](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Why FLACTagger?

macOS Finder reads album artwork from audio files by looking for **ID3 tags**, but FLAC files natively store metadata (including cover art) in **Vorbis Comment** format. This means even if your FLAC files have embedded artwork, Finder won't display it.

FLACTagger solves this by writing the FLAC cover art into an ID3 tag at the beginning of the file, allowing Finder to correctly recognize and display album artwork — with **zero impact on audio quality**.

---

## Features

- 📋 **Metadata Editor** — View and edit FLAC Vorbis Comment tags (title, artist, album, year, genre, track number, and more)
- 🖼️ **Cover Art Manager** — View, import, paste, sync, and export cover art for both FLAC and ID3 tags
- 🔄 **One-click Sync** — Batch write FLAC cover art into ID3 tags so Finder displays artwork correctly
- 🔍 **Health Check** — Quickly filter files missing cover art, lyrics, or artist information
- 🎵 **Lyrics Editor** — View and edit lyrics in both plain text and LRC timestamp format, with automatic format detection
- 📁 **Batch Processing** — Recursively scan entire folders and process all FLAC files at once
- 🔎 **Quick Search** — Real-time search by song title or artist name

---

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon or Intel Mac

---

## Installation

### Option 1: Download Release (Recommended)

1. Go to the [Releases](https://github.com/davie-01/-FLACTagger/releases) page
2. Download the latest `FLACTagger.zip`
3. Unzip and drag `FLACTagger.app` into your `/Applications` folder
4. On first launch, right-click → Open to bypass Gatekeeper

### Option 2: Build from Source

```bash
git clone https://github.com/davie-01/-FLACTagger.git
cd -FLACTagger
open FLACTagger.xcodeproj
```

Then press ⌘R in Xcode to build and run.

---

## Usage

### Importing Files
- Drag and drop FLAC files or folders directly into the window
- Or click the **Import Files** button in the toolbar

### Syncing Cover Art to ID3 (Fix Finder Not Showing Artwork)
1. After importing, click **ID3 Not Synced** in the sidebar to see files that need processing
2. Click **Sync All Covers** in the toolbar to batch process
3. Or right-click individual files and choose **Sync Cover to ID3**

### Editing Metadata
1. Double-click a track in the list to open the detail panel
2. Switch to the **Metadata** tab and edit any field
3. Click **Save Changes** to write back to the file

### Managing Lyrics
1. Open the detail panel and switch to the **Lyrics** tab
2. Edit directly or import from a `.lrc` file in the same directory
3. LRC timestamp format is detected and highlighted automatically

---

## How It Works

FLAC files store text metadata in **Vorbis Comment** blocks and cover art in **PICTURE blocks**. macOS reads cover art by looking for an **APIC frame** inside an **ID3v2 tag** at the start of the file.

FLACTagger inserts an ID3v2 tag at the beginning of the file containing the cover art from the FLAC PICTURE block. The FLAC audio data is completely untouched — no re-encoding, no quality loss.

Supported cover art formats: JPEG, PNG, WebP

---

## License

MIT License © 2025

---

## Acknowledgements

Thanks to [MikeWang000000/ID3flac](https://github.com/MikeWang000000/ID3flac) for the detailed explanation of the FLAC + ID3 tag mechanism that inspired this project.
