#!/usr/bin/env bash
#
# monitor-session.sh - watch a live BeamNG.drive + BeamMP session.
#
# Records noteworthy events (multiplayer connections, authentication, errors,
# warnings, disconnects) from the BeamMP launcher log and the BeamNG game log,
# then exits automatically when the BeamNG main process closes and prints a
# short summary. Safe to run in the background.
#
# It may be started *before* launching BeamMP: it will wait for the game to
# appear (up to 10 minutes) before it begins watching.
#
# Usage:  ./monitor-session.sh
# Output: ~/beammp-launcher/session-events.log   (chronological events)
#         ~/beammp-launcher/session-summary.txt  (end-of-session summary)

set -uo pipefail

GAME_LOG="$HOME/.local/share/BeamNG/BeamNG.drive/current/beamng.log"
LAUNCHER_LOG="$HOME/beammp-launcher/Launcher.log"
EVENTS="$HOME/beammp-launcher/session-events.log"
SUMMARY="$HOME/beammp-launcher/session-summary.txt"

GAME_RE="BinLinux/BeamNG.drive.x64"

# True while the *main* BeamNG process runs (ignore CEF/renderer subprocesses).
game_running() {
    local p cmd
    for p in $(pgrep -f "$GAME_RE" 2>/dev/null); do
        cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)
        case "$cmd" in
            *--type=*) : ;;   # CEF/zygote/renderer helper -> not the main process
            "")        : ;;
            *)         return 0 ;;
        esac
    done
    return 1
}

START=$(date '+%Y-%m-%d %H:%M:%S')
: > "$EVENTS"
{
    echo "BeamNG/BeamMP session monitor started: $START"
    echo "------------------------------------------------------------"
} >> "$EVENTS"

# Follow the BeamMP launcher log.
tail -n0 -F "$LAUNCHER_LOG" 2>/dev/null \
    | grep --line-buffered -iE "connect|disconnect|authenticat|welcome|server|kick|ban|timeout|error|fail|update" \
    | sed -u 's/^/[launcher] /' >> "$EVENTS" &
T1=$!

# Follow the BeamNG game log.
tail -n0 -F "$GAME_LOG" 2>/dev/null \
    | grep --line-buffered -E "\|[EW]\||error|exception|crash|fatal|disconnect|timeout|failed|MPServer|MPCoreNetwork|MPModManager|MPVehicleGE|multiplayer" \
    | sed -u 's/^/[game] /' >> "$EVENTS" &
T2=$!

# If armed before launch, wait for the game to appear (up to 10 minutes).
if ! game_running; then
    for _ in $(seq 1 120); do
        game_running && break
        sleep 5
    done
fi

# Wait for the game to close.
while game_running; do
    sleep 5
done

sleep 2
kill "$T1" "$T2" 2>/dev/null
wait 2>/dev/null

END=$(date '+%Y-%m-%d %H:%M:%S')
# grep -c prints a count and exits non-zero when the count is 0; "|| true"
# keeps the substitution a clean single value.
GAME_ERRORS=$(grep -c '^\[game\].*|E|' "$EVENTS" 2>/dev/null || true)
GAME_WARNINGS=$(grep -c '^\[game\].*|W|' "$EVENTS" 2>/dev/null || true)
LAUNCH_ERRORS=$(grep -c -i '^\[launcher\].*error' "$EVENTS" 2>/dev/null || true)
AUTH_OK=$(grep -c -i 'authentication successful' "$EVENTS" 2>/dev/null || true)

{
    echo "------------------------------------------------------------"
    echo "BeamNG/BeamMP session monitor ended:   $END"
    echo "BeamNG errors   (|E|):     $GAME_ERRORS"
    echo "BeamNG warnings (|W|):     $GAME_WARNINGS"
    echo "Launcher errors:           $LAUNCH_ERRORS"
    echo "Auth successes:            $AUTH_OK"
} | tee -a "$EVENTS" > "$SUMMARY"

exit 0
