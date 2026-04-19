#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib


def repo_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[1]


def canonical_manifest_path(root: pathlib.Path) -> pathlib.Path:
    return root.parent / "system-backup" / "manifests" / "claude-sources.json"


def legacy_manifest_path(root: pathlib.Path) -> pathlib.Path:
    return root / ".claude" / "skills-manifest.json"


def resolve_manifest(explicit: str | None) -> pathlib.Path:
    root = repo_root()
    if explicit:
        path = pathlib.Path(explicit).expanduser()
        if not path.is_file():
            raise SystemExit(f"Missing manifest: {path}")
        return path

    for candidate in (canonical_manifest_path(root), legacy_manifest_path(root)):
        if candidate.is_file():
            return candidate

    raise SystemExit(
        "Missing manifest: expected "
        f"{canonical_manifest_path(root)} or {legacy_manifest_path(root)}"
    )


def load_manifest_rows(
    manifest_path: pathlib.Path, home: pathlib.Path
) -> tuple[list[tuple[str, pathlib.Path]], list[str]]:
    try:
        data = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in manifest {manifest_path}: {exc}") from exc

    legacy_skills = data.get("skills")
    if isinstance(legacy_skills, list):
        rows: list[tuple[str, pathlib.Path]] = []
        for entry in legacy_skills:
            name = entry.get("name")
            source = entry.get("source")
            if not isinstance(name, str) or not name:
                raise SystemExit(f"Invalid legacy skill name in {manifest_path}")
            if not isinstance(source, str) or not source:
                raise SystemExit(f"Invalid legacy skill source for {name} in {manifest_path}")
            rows.append((name, pathlib.Path(source).expanduser()))
        return rows, []

    repos = data.get("repos")
    links = data.get("skill_links")
    if not isinstance(repos, list) or not isinstance(links, list):
        raise SystemExit(f"Unsupported manifest schema in {manifest_path}")

    repo_roots: dict[str, pathlib.Path] = {}
    for repo in repos:
        repo_id = repo.get("id")
        checkout_rel = repo.get("checkout_rel")
        if not isinstance(repo_id, str) or not repo_id:
            raise SystemExit(f"Invalid repo id in {manifest_path}")
        if not isinstance(checkout_rel, str) or not checkout_rel:
            raise SystemExit(f"Invalid checkout_rel for repo {repo_id} in {manifest_path}")
        repo_roots[repo_id] = home / checkout_rel

    rows = []
    for link in links:
        name = link.get("name")
        repo_id = link.get("repo")
        subpath = link.get("subpath", ".")
        if not isinstance(name, str) or not name:
            raise SystemExit(f"Invalid skill link name in {manifest_path}")
        if not isinstance(repo_id, str) or not repo_id:
            raise SystemExit(f"Invalid repo reference for skill {name} in {manifest_path}")
        if not isinstance(subpath, str) or not subpath:
            raise SystemExit(f"Invalid subpath for skill {name} in {manifest_path}")
        if repo_id not in repo_roots:
            raise SystemExit(
                f"Skill {name} references unknown repo {repo_id} in {manifest_path}"
            )
        source = repo_roots[repo_id]
        if subpath != ".":
            source = source / pathlib.Path(subpath)
        rows.append((name, source))

    retired = []
    for name in data.get("retired_skill_names") or []:
        if isinstance(name, str) and name:
            retired.append(name)
    return rows, retired


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", help="Optional explicit manifest path.")
    parser.add_argument(
        "--mode",
        choices=("rows", "retired", "stock", "path"),
        default="rows",
        help="Output mode.",
    )
    parser.add_argument(
        "--home",
        default=str(pathlib.Path.home()),
        help="Home directory used to resolve canonical checkout paths.",
    )
    args = parser.parse_args()

    manifest_path = resolve_manifest(args.manifest)
    rows, retired = load_manifest_rows(manifest_path, pathlib.Path(args.home).expanduser())

    if args.mode == "path":
        print(manifest_path)
        return 0

    if args.mode == "retired":
        for name in retired:
            print(name)
        return 0

    if args.mode == "stock":
        data = json.loads(manifest_path.read_text())
        for name in data.get("stock_skill_names") or []:
            if isinstance(name, str) and name:
                print(name)
        return 0

    for name, source in rows:
        print(f"{name}\t{source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
