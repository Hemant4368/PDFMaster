# Architecture

## Overview

PDF Master follows a modular MVVM architecture with actor-based services and SwiftData persistence.

```
┌─────────────────────────────────────────────────────┐
│                      App Layer                       │
│  PDFMasterApp → RootView → MainTabView              │
│                   ↙ ↓ ↘                              │
│          Splash  Onboarding  MainTabView             │
│                              /    \                  │
│                       HomeView  ToolsView            │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│                    Features                          │
│  17 feature modules, each with a dedicated view      │
│  (Scanner, ImageToPDF, MergePDF, OCR, etc.)         │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│                       Core                           │
│  Components  │  Theme    │  Managers  │  Storage     │
│  Extensions  │  Helpers  │  Utilities                │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│                     Services                         │
│  PDFProcessingService (actor)                        │
│  FileStorageService (actor)                          │
│  OCRService (actor)                                  │
│  SubscriptionManager (@MainActor ObservableObject)   │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────┐
│                     Models                           │
│  DocumentRecord (@Model SwiftData)                   │
│  OCRHistoryRecord (@Model SwiftData)                 │
│  SignatureRecord (@Model SwiftData)                  │
│  PDFTool enum + ToolOptions                          │
└─────────────────────────────────────────────────────┘
```

## Key Patterns

### Service Layer (Actors)

All shared services are Swift actors for thread safety:

```swift
actor PDFProcessingService {
    static let shared = PDFProcessingService()
    func merge(_ urls: [URL]) throws -> Data
    func extractPages(from url: URL, indexes: [Int]) throws -> Data
    func protect(url: URL, password: String) throws -> Data
    func watermarked(url: URL, options: WatermarkOptions) throws -> Data
    // ...
}
```

### Navigation

Routing uses a simple `ToolRouterView` that switches on `PDFTool` enum cases. Tab navigation uses a custom `MainTabView` with a floating scan button.

### Persistence

SwiftData with three model types:
- `DocumentRecord` — tracks saved PDFs and their metadata
- `OCRHistoryRecord` — stores OCR extraction history
- `SignatureRecord` — persists saved signatures

### Subscription

StoreKit-based freemium model with `SubscriptionManager` singleton. Products: monthly and yearly.

## Data Flow

```
User Action → View → ViewModel (if complex) → Service Actor → SwiftData / FileSystem
                  ↑                                                      │
                  └─────────────── completion/error ─────────────────────┘
```
