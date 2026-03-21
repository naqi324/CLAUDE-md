#!/usr/bin/env python3
"""
Audit installed MCP servers against the current static read-only permission policy.

Reports:
- whole-server wildcard approvals
- covered read-only tools in partially gated namespaces
- intentionally gated tools
- uncovered safe read-only tools
"""

from __future__ import annotations

import json
import re
from fnmatch import fnmatch
from pathlib import Path


REPO_ROOT = Path("/Users/naqi.khan/git/CLAUDE-md")
REPO_SETTINGS = REPO_ROOT / ".claude/settings.json"
LIVE_SETTINGS = Path("/Users/naqi.khan/.claude/settings.json")
CLAUDE_JSON = Path("/Users/naqi.khan/.claude.json")
SLACK_SRC = Path("/Users/naqi.khan/git/mcps/slack-mcp/src/tools")
PROJECT_OVERRIDE_DIRS = {
    "slack": Path("/Users/naqi.khan/git/mcps/slack-mcp/.claude"),
}

SAFE_PREFIXES = ("get_", "list_", "search_", "find_")
UNSAFE_PREFIXES = (
    "create_",
    "update_",
    "edit_",
    "delete_",
    "send_",
    "add_",
    "remove_",
    "upload_",
    "download_",
    "open_",
    "join_",
    "mark_",
    "set_",
    "archive_",
    "pin_",
    "unpin_",
    "complete_",
    "reply_",
    "share_",
    "move_",
    "copy_",
    "rename_",
    "convert_",
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def mcp_allow_entries(path: Path) -> list[str]:
    data = load_json(path)
    return [
        entry
        for entry in data.get("permissions", {}).get("allow", [])
        if isinstance(entry, str) and entry.startswith("mcp__")
    ]


def installed_servers() -> dict:
    data = load_json(CLAUDE_JSON)
    return data.get("mcpServers", {})


def slack_tools() -> list[str]:
    names: set[str] = set()
    pattern = re.compile(r'"(slack_[a-z_]+)"')
    for path in SLACK_SRC.glob("*.ts"):
        for match in pattern.findall(path.read_text()):
            names.add(match)
    return sorted(names)


def classify_slack_tool(tool: str) -> str:
    if tool in {"slack_admin_search_channels", "slack_admin_list_users"}:
        return "intentionally_excluded_admin_read"
    verb = tool.removeprefix("slack_")
    if verb.startswith(SAFE_PREFIXES):
        return "safe_read_only"
    if verb.startswith(UNSAFE_PREFIXES):
        return "intentionally_gated"
    return "manual_review"


def covered_by_allow(tool_name: str, patterns: list[str]) -> bool:
    mcp_name = f"mcp__slack__{tool_name}"
    return any(fnmatch(mcp_name, pattern) for pattern in patterns)


def whole_server_approvals(patterns: list[str], servers: dict) -> tuple[list[str], list[str]]:
    whole = []
    partial = []
    for server in sorted(servers):
        wildcard = f"mcp__{server}__*"
        if wildcard in patterns:
            whole.append(server)
        else:
            partial.append(server)
    return whole, partial


def project_override_files(server: str) -> list[Path]:
    claude_dir = PROJECT_OVERRIDE_DIRS.get(server)
    if not claude_dir:
        return []
    return [
        path
        for path in (claude_dir / "settings.json", claude_dir / "settings.local.json")
        if path.exists()
    ]


def slack_baseline_patterns(patterns: list[str]) -> list[str]:
    return sorted(pattern for pattern in patterns if pattern.startswith("mcp__slack__"))


def summarize_items(items: list[str], limit: int = 5) -> str:
    if not items:
        return "none"
    if len(items) <= limit:
        return ", ".join(items)
    remaining = len(items) - limit
    return f"{', '.join(items[:limit])}, ... ({remaining} more)"


def diff_summary(repo_patterns: list[str], live_patterns: list[str]) -> str:
    if repo_patterns == live_patterns:
        return "repo/live settings MCP allow entries match"
    return "repo/live settings MCP allow entries differ"


def main() -> int:
    repo_patterns = mcp_allow_entries(REPO_SETTINGS)
    live_patterns = mcp_allow_entries(LIVE_SETTINGS)
    servers = installed_servers()
    whole, partial = whole_server_approvals(live_patterns, servers)

    print("MCP Read-Only Policy Audit")
    print()
    print(f"Installed MCP servers: {', '.join(sorted(servers))}")
    print(f"Settings parity: {diff_summary(repo_patterns, live_patterns)}")
    print()

    print("Whole-server approvals")
    for server in whole:
        print(f"- {server}")
    print()

    print("Partially gated namespaces")
    for server in partial:
        print(f"- {server}")
    print()

    if "slack" in servers:
        print("Slack audit")
        covered_safe: list[str] = []
        uncovered_safe: list[str] = []
        intentionally_gated: list[str] = []
        intentionally_excluded_admin: list[str] = []
        manual_review: list[str] = []

        for tool in slack_tools():
            classification = classify_slack_tool(tool)
            is_covered = covered_by_allow(tool, live_patterns)
            if classification == "safe_read_only":
                (covered_safe if is_covered else uncovered_safe).append(tool)
            elif classification == "intentionally_gated":
                intentionally_gated.append(tool)
            elif classification == "intentionally_excluded_admin_read":
                intentionally_excluded_admin.append(tool)
            else:
                manual_review.append(tool)

        print("- Covered safe read-only tools:")
        for tool in covered_safe:
            print(f"  - {tool}")
        print("- Intentionally excluded admin reads:")
        for tool in intentionally_excluded_admin:
            print(f"  - {tool}")
        print("- Intentionally gated state-changing/local-write tools:")
        for tool in intentionally_gated:
            print(f"  - {tool}")
        print("- Uncovered safe read-only tools:")
        if uncovered_safe:
            for tool in uncovered_safe:
                print(f"  - {tool}")
        else:
            print("  - none")
        print("- Manual review:")
        if manual_review:
            for tool in manual_review:
                print(f"  - {tool}")
        else:
            print("  - none")
        print()

        print("Project-local override audit")
        override_files = project_override_files("slack")
        if not override_files:
            print("- none")
        else:
            baseline_patterns = slack_baseline_patterns(live_patterns)
            baseline_safe_tools = [
                tool
                for tool in slack_tools()
                if classify_slack_tool(tool) == "safe_read_only"
                and covered_by_allow(tool, baseline_patterns)
            ]

            for path in override_files:
                local_patterns = mcp_allow_entries(path)
                local_safe_tools = [
                    tool for tool in baseline_safe_tools if covered_by_allow(tool, local_patterns)
                ]
                uncovered_local_safe = [
                    tool for tool in baseline_safe_tools if tool not in local_safe_tools
                ]
                missing_baseline_patterns = [
                    pattern for pattern in baseline_patterns if pattern not in local_patterns
                ]
                local_extras = [
                    pattern
                    for pattern in local_patterns
                    if pattern.startswith("mcp__slack__") and pattern not in baseline_patterns
                ]

                if uncovered_local_safe:
                    print(f"- WARNING narrower than global safe-read baseline: {path}")
                    print(
                        f"  - local safe-read coverage: {len(local_safe_tools)}/{len(baseline_safe_tools)}"
                    )
                    print(
                        f"  - missing baseline patterns: {summarize_items(missing_baseline_patterns)}"
                    )
                    print(
                        f"  - sample uncovered safe reads: {summarize_items(uncovered_local_safe)}"
                    )
                else:
                    print(f"- aligned with global safe-read baseline: {path}")
                    print(
                        f"  - local safe-read coverage: {len(local_safe_tools)}/{len(baseline_safe_tools)}"
                    )

                if local_extras:
                    print(f"  - preserved local exceptions: {summarize_items(local_extras)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
