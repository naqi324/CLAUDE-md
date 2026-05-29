# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations). Installed at `/opt/homebrew/bin/rtk`.

## Meta Commands

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
which rtk             # Verify correct binary: /opt/homebrew/bin/rtk
```

⚠️ **Name collision**: if `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## How filtering is applied

There is no command-rewriting hook installed, so commands are NOT auto-proxied. To get
token-filtered output, call `rtk <cmd>` explicitly (for example `rtk git status`). Do not
assume plain command output has already been rtk-filtered.
