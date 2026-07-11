# Contributing

## Getting Started

1. Ensure you have Xcode 15+ and iOS 17+ SDK
2. Clone the repo and open `PDFMaster.xcodeproj`
3. Build and run on simulator

## Development Workflow

### AI-Assisted Development

This project uses Claude Code + Ruflo + Code Review Graph for AI-assisted development.

1. **Explore the codebase** — Use code-review-graph MCP tools before reading files directly
2. **Plan changes** — Use `get_impact_radius` to understand blast radius
3. **Implement** — Follow the patterns in PROJECT_RULES.md
4. **Review** — Use `detect_changes` for risk-scored review

### Adding a New Tool

1. Add a new case to `PDFTool` enum in `Models/PDFTool.swift`
2. Create `Features/[ToolName]/[ToolName]View.swift`
3. Add routing in `Features/Home/ToolRouterView.swift`
4. Add the tool card appears automatically via `PDFTool.allCases`

### Code Style

- Run SwiftLint if configured
- Follow conventions in CODE_STYLE.md
- Keep views under 300 lines; extract ViewModels for complex logic
- Use `AppTheme` for all colors and styling

## Pull Request Process

1. Run `code-review-graph detect-changes --brief` to check impact
2. Ensure the graph is updated (`code-review-graph update`)
3. Verify the app builds and runs without errors
4. Submit PR with a clear description of changes

## Architecture Decisions

Significant decisions should be documented as ADRs (Architecture Decision Records) using the `@ruflo/adr` plugin:

```bash
/plugin install ruflo-adr@ruflo
```
