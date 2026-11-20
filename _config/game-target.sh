# game-target.sh -- source me (bash): GAME_FWD = the game folder of the first enabled target of targets.json ("D:/Games/..."), GAME_UNIX = the same
# folder as Git Bash sees it ("/d/Games/..."). The bash twin of game_target.py and game-target.ps1: the install path lives in ONE place, targets.json
# (KUMM EXP-0329, 2026-10-25). Paid again 2026-11-13 (the move to 3.1.0, KUMM plan 53): 14 shell tools still had «Conan Exiles 3.0.1» written in.
# An explicit GAME in the environment wins (the `${GAME:-...}` contract the old scripts had).
#
#   . "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"        (from _config/rdoc or _config/release: ".../../game-target.sh")
# [NOT-TESTED]
__gt_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
GAME_FWD="${GAME:-$(python -I -c "import sys; sys.path.insert(0, r'$__gt_here'); import game_target; print(game_target.GAME_DIR.replace(chr(92), '/'))")}"
[ -n "$GAME_FWD" ] || { echo "game-target.sh: no game folder (targets.json / game_target.py)" >&2; exit 2; }   # exit, not return: a sourcing script must stop (judge D, B6)
GAME_UNIX="$(cygpath -u "$GAME_FWD")"
unset __gt_here
