# Project Rules

## Architecture & Design

1. **SwiftUI-first** — All UI must use SwiftUI. UIKit bridges only via `UIViewRepresentable` / `UIViewControllerRepresentable` for system components (PDFKit, PencilKit, VisionKit, UIDocumentPicker).

2. **SwiftData for persistence** — All models use `@Model` macro. No Core Data, no manual SQLite.

3. **Actor-based services** — Shared services (`PDFProcessingService`, `FileStorageService`, `OCRService`) are Swift actors for thread safety.

4. **MVVM pattern** — Each feature with complex state gets a dedicated `@MainActor` `ObservableObject` ViewModel.

## Code Organization

5. **Feature folders** — Each tool lives in `Features/[ToolName]/` with a single main view file (or View+ViewModel for complex features).

6. **Core vs Features** — Reusable code (components, extensions, theme, managers) goes in `Core/`. Feature-specific logic stays in `Features/`.

7. **File naming** — View files use the pattern `[ToolName]View.swift`. ViewModels use `[ToolName]ViewModel.swift`.

## Conventions

8. **Imports** — Import only what's needed. Order: Apple frameworks first, then third-party, then project modules.

9. **Error handling** — Use `LocalizedError` enums with descriptive `errorDescription`. Propagate errors via `throws` in actors, catch in views with `.alert()`.

10. **Async/await** — Prefer structured concurrency. Use `Task { }` in views, `async throws` in services. No completion handlers.

11. **Access control** — Use `private` by default. Use `fileprivate` only when necessary. Mark shared singletons as `static let shared`.

12. **Design system** — Use `AppTheme` colors and modifiers (`premiumCard()`, `redButtonStyle()`). No hardcoded colors or radii.

## AI Development Rules

13. **Use code-review-graph first** — Always use semantic search / query graph before Grep/Glob/Read to understand code structure.

14. **Use Ruflo for multi-step tasks** — Coordinate complex changes through Ruflo's swarm/agent system.

15. **Ruflo MCP tools** — Use `memory_store`, `memory_search`, `swarm_init`, `agent_spawn` for persistent context and parallel work.
