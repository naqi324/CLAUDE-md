# CLAUDE-md

Claude Code configuration management repository. Contains hooks, settings, scripts, and CLAUDE.md files that define global Claude Code behavior.

## Session Context
- Date: 2026-03-19
- Work state: Fixed llm-history Stop hook reliability and documented --resume crash workaround.
- Decisions:
  - Split llm-history-save.sh into fast dispatcher + detached nohup worker (survives parent exit)
  - Changed dedup lock from event-specific to event-agnostic (`${SESSION_ID}-save.saved`)
  - Lock created in dispatcher before fork to eliminate Stop/SessionEnd race
  - Added SessionEnd hook as belt-and-suspenders fallback
  - Added `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=130000` to ~/.zprofile
  - Added error logging to all hook scripts (/tmp/llm-history-hook.log, worker.log, auto-git-commit.log)
  - Documented `--resume` CLI crash (upstream bug) and `--name` best practice
- Next steps:
  - Test in fresh session: verify Stop hook dispatches worker, llm-history entry appears
  - Stress test: close terminal mid-session, verify worker still completes
