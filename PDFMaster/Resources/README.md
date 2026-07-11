# PDF Master AI – Scanner, Editor & Converter

## Setup
Open `PDFMaster.xcodeproj` in Xcode 16 or newer, choose an iOS 17+ simulator or device, set your signing team, and run the `PDF Master AI` target.

The app uses native Apple frameworks only: SwiftUI, SwiftData, PDFKit, VisionKit, Vision, PencilKit, StoreKit 2, PhotosUI, and LocalAuthentication.

## Architecture
The codebase follows a modular MVVM shape:

- `App`: app entry, root routing, splash/onboarding/main flow.
- `Core`: theme, reusable components, UIKit bridges, managers, helpers, utilities.
- `Models`: SwiftData models, PDF tools, export options.
- `Services`: PDF processing, OCR, file storage, subscriptions.
- `Features`: each user-facing feature in its own folder.

Feature views are thin. Heavy work is isolated in services so cloud sync, AI OCR summary APIs, and entitlement gates can be added without rewriting screens.

## PDFKit
`PDFProcessingService` handles merge, extract, delete, reorder, password write/unlock, PDF-to-image rendering, watermark rendering, and signature stamping. `PDFKitView` wraps `PDFView` for native zooming, scrolling, dark mode behavior, sharing, and printing.

## VisionKit Scanner
`ScannerFlowView` presents `VNDocumentCameraViewController` through `DocumentScannerView`. It supports multipage scans, Apple’s document edge detection, perspective correction, preview, rename, save, and open.

## OCR Pipeline
`OCRService` renders PDF pages to images and runs `VNRecognizeTextRequest` with configurable recognition languages. Results are editable, copyable, shareable, and can be persisted as `OCRHistoryRecord`.

## Storage
Physical files are stored in the app container under `PDFMaster/Documents`. SwiftData persists metadata (`DocumentRecord`), OCR history, signatures, and preferences through `AppStorage`.

## StoreKit 2
`SubscriptionManager` expects products:

- `pdfmasterai.monthly`
- `pdfmasterai.yearly`

Add matching products in App Store Connect or a local StoreKit configuration before testing purchases.

## Deployment
Set bundle ID/team, provide final app icons, add a privacy manifest if your release process requires it, configure StoreKit products, test camera scanning on device, archive, validate, and upload from Xcode Organizer.

## App Store Notes
Camera, Photos, and Face ID usage strings are included in `Info.plist`. The app stores documents locally and is structured for iCloud or API-backed sync later.
