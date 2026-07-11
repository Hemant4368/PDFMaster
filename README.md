# PDF Master AI

A powerful iOS PDF toolkit built with SwiftUI — merge, split, annotate, sign, watermark, scan, OCR, protect, and convert PDFs with ease.

## Features

| Tool | Description |
|------|-------------|
| Document Scanner | Scan physical documents using the camera |
| Image to PDF | Convert photos and images to PDF format |
| PDF to Image | Extract pages as JPG or PNG images |
| Merge PDFs | Combine multiple PDFs into one document |
| Extract Pages | Pull specific pages from a PDF |
| Reorder Pages | Rearrange page order in a PDF |
| Password Protect | Lock PDFs with owner/user passwords |
| Watermark | Add text watermarks with custom opacity, rotation, and position |
| Signature | Draw and apply signatures to any page |
| Annotate | Freehand drawing and text annotations with PencilKit |
| OCR Text | Extract text from scanned documents using Vision |

## Architecture

```
PDFMaster/
├── App/            # App entry, root view, navigation
├── Core/           # Theme, components, extensions, managers
├── Features/       # 17 feature modules (one per tool)
├── Models/         # SwiftData models, enums, options
└── Services/       # PDF processing, file storage, OCR, subscriptions
```

## Tech Stack

- **SwiftUI** with SwiftData persistence
- **PDFKit** for PDF rendering and manipulation
- **VisionKit** for document scanning
- **Vision** for OCR text recognition
- **PencilKit** for freehand annotations and signatures
- **StoreKit** for in-app subscriptions
- **LocalAuthentication** for biometric app lock

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `PDFMaster.xcodeproj` in Xcode
3. Build and run on a simulator or device

## License

MIT
