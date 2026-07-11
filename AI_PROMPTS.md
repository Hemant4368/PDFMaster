# AI Prompts

Useful prompts for AI-assisted development of PDF Master.

## Code Review

```
Review the latest changes using code-review-graph's detect_changes tool.
Focus on:
- Risk-scored functions
- Affected execution flows
- Missing test coverage
```

## Architecture Analysis

```
Use get_architecture_overview to explain the high-level architecture.
Then use list_communities and get_community to explore each module.
```

## Adding a New Feature

```
I want to add a new PDF tool called [TOOL_NAME].

1. Use semantic_search_nodes to find similar tools
2. Use query_graph to understand the patterns used by existing tools
3. Create the feature following the existing conventions:
   - Feature file in Features/[ToolName]/
   - Entry in PDFTool enum
   - Route in ToolRouterView
4. Use get_impact_radius before making changes
```

## Debugging

```
I'm seeing [BUG_DESCRIPTION].

1. Use detect_changes to find recent changes that could cause this
2. Use get_affected_flows to find impacted execution paths
3. Use query_graph to trace dependencies
4. After fixing, verify with get_review_context
```

## Refactoring

```
Plan a refactor of [MODULE_NAME].

1. Use refactor_tool to preview rename impacts
2. Use get_impact_radius to understand blast radius
3. Use query_graph to find all callers and dependents
4. Execute with apply_refactor_tool
```

## Swarm Coordination (Ruflo)

```
/swarm init pattern=mesh goal="[GOAL]"
/agent spawn role=coder task="[TASK]"
/agent spawn role=reviewer task="[TASK]"
/memory store key="[KEY]" value="[VALUE]"
```

## Onboarding

```
Use get_architecture_overview to understand the project structure.
Then explore each module with query_graph.
```
