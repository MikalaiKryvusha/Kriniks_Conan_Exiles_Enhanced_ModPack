#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/../game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# launch-rdoc.sh — start Conan under RenderDoc (injected at process start), in the background, captures into D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/ (KUMM bug 67: what the
# shadow renderer actually draws). The game must NOT be running (exit 2). After the world is entered and the stand is set, take a frame:
#   "/c/Program Files/RenderDoc/qrenderdoc.exe" --python "D:/work/ai_sandbox/ConanExiles/_config/rdoc/rdoc_trigger.py"
# Machine lock and the stand rules (HOUSE_RULES 11, 29) apply as for any run.
# [NOT-TESTED]
EXE="$GAME_FWD/ConanSandbox/Binaries/Win64/ConanSandbox-Win64-Shipping.exe"
if tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH 2>/dev/null | grep -qi "ConanSandbox-Win64-Shipp"; then
  echo "the game is already running — close it first"; exit 2
fi
mkdir -p /d/work/ai_sandbox/ConanExiles/_scratch/rdoc
"/c/Program Files/RenderDoc/renderdoccmd.exe" capture -d "$(dirname "$EXE")" -c "D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/conan" "$EXE" > /d/work/ai_sandbox/ConanExiles/_scratch/rdoc/launch.log 2>&1 &
sleep 5
tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH | grep -i "ConanSandbox" || { echo "the game did not start"; cat /d/work/ai_sandbox/ConanExiles/_scratch/rdoc/launch.log; exit 1; }
echo "started under RenderDoc"
