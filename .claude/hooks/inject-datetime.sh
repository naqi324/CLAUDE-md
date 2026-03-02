#!/bin/sh
# UserPromptSubmit hook: inject current datetime into Claude's context.
cat > /dev/null
echo "Current datetime: $(date '+%A, %Y-%m-%d %H:%M %Z')"
