# Changelog

All notable changes to PDF Master will be documented in this file.

## [Initial Release] - 2025-05-26

### Added
- SwiftUI + SwiftData project scaffold
- PDFTool enum with 11 tools (Scanner, ImageToPDF, PDFToImage, Merge, Extract, Reorder, Password, Watermark, Signature, Annotation, OCR)
- Actor-based PDFProcessingService with full processing pipeline
- FileStorageService for document management (save, import, rename, duplicate, delete)
- OCRService using Vision framework
- SubscriptionManager with StoreKit integration
- AppLockManager with biometric authentication
- Reusable component library (PrimaryButton, ToolCard, DocumentRow, EmptyStateView, LoadingOverlay)
- UIKit bridges (PDFKitView, DocumentScannerView, DocumentPickerView, ShareSheet, PencilCanvasView)
- Custom theme system with red gradient and card styling
- SwiftData models: DocumentRecord, OCRHistoryRecord, SignatureRecord
- Feature modules:
  - Home (file browsing, tools grid, tab navigation)
  - Scanner (document camera scanning)
  - ImageToPDF (photo library to PDF conversion)
  - MergePDF (multi-file merge)
  - ExtractPages (page extraction)
  - ReorderPages (drag-to-reorder)
  - Password (add/remove PDF passwords)
  - Watermark (customizable text watermarks)
  - Signature (PencilKit drawing + placement)
  - Annotation (freehand drawing)
  - OCR (Vision-based text extraction)
  - PDFToImage (page rendering to JPG/PNG)
  - Viewer (PDF reading with editing toolbar)
  - Settings (dark mode, quality, security, subscription)
  - Splash (animated launch screen)
  - Onboarding (first-launch tutorial)
- Premium subscription products (monthly/yearly)

### Infrastructure
- Claude Code configuration
- Ruflo agent harness setup (v3.10.46)
- Code Review Graph integration (v2.3.6)
- AI-assisted development tooling
