#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

TAG="# CRON_SYNC"

# ------------------------------------------------------------
# Exit codes & Colors
# ------------------------------------------------------------
EXIT_NO_CHANGE=0
EXIT_CHANGED=10
EXIT_DRYRUN_CHANGED=11

if [[ -t 1 ]]; then
    BOLD="\033[1m"; DIM="\033[2m"; GREEN="\033[32m"
    BLUE="\033[34m"; RED="\033[31m"; YELLOW="\033[33m"; RESET="\033[0m"
else
    BOLD=""; DIM=""; GREEN=""; BLUE=""; RED=""; YELLOW=""; RESET=""
fi

OK="${GREEN}✓${RESET}"; ADD="${BLUE}+${RESET}"; REMOVE="${RED}✕${RESET}"; INFO="${YELLOW}ℹ${RESET}"

# ------------------------------------------------------------
# Configuration Loading Logic
# ------------------------------------------------------------
# Support --dry-run as $1 and config as $2, or just config as $1
CONFIG_FILE=""
DRY_RUN=false

for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
        DRY_RUN=true
    elif [[ -f "$arg" ]]; then
        CONFIG_FILE="$arg"
    fi
done

if [[ -z "$CONFIG_FILE" ]]; then
    echo -e "${RED}${BOLD}Error:${RESET} No valid config file provided or file not found."
    echo -e "Usage: $0 [--dry-run] <config_file>"
    exit 1
fi

# Source the external config
source "$CONFIG_FILE"

# ------------------------------------------------------------
# Header & Execution
# ------------------------------------------------------------
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HEADER_TEXT="▶ cron-sync"
[[ "$DRY_RUN" == true ]] && HEADER_TEXT+=" · ${YELLOW}dry-run${RESET}"
echo -e "${BOLD}${HEADER_TEXT}${RESET} · ${DIM}$TIMESTAMP${RESET}"
echo -e "${INFO} Config: ${BOLD}$CONFIG_FILE${RESET}"
echo -e "${DIM}────────────────────────────────────────${RESET}"

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
UPDATED=false
OUTPUT=()
REMOVED=()
ADDED=()
UNCHANGED=()

# Compute dynamic label width
LABEL_WIDTH=0
for ENTRY in "${ADD_JOBS[@]:-}"; do
    IFS="|" read -r LABEL _ _ <<< "$ENTRY"
    (( ${#LABEL} > LABEL_WIDTH )) && LABEL_WIDTH=${#LABEL}
done
((LABEL_WIDTH+=2))

MAX_LINE_LENGTH=80

wrap_text() {
    local text="$1" max_len=$2 prefix="$3"
    local result="" first_line=true line=""
    for word in $text; do
        if (( ${#line} + ${#word} + 1 > max_len )); then
            result+="$prefix$line\n"
            first_line=false
            line="$word"
        else
            [[ -n "$line" ]] && line+=" "
            line+="$word"
        fi
    done
    result+="$prefix$line"
    echo -e "$result"
}

# 1. Filter removals
mapfile -t CRON_LINES <<< "$CURRENT_CRON"
i=0
while [[ $i -lt ${#CRON_LINES[@]} ]]; do
    line="${CRON_LINES[$i]}"
    if [[ "$line" == "$TAG"* ]]; then
        label="${line#"$TAG "}"
        next_line="${CRON_LINES[$((i+1))]:-}"
        remove=false
        for target in "${REMOVE_JOBS[@]:-}"; do
            if [[ "$next_line" == *"$target"* ]]; then
                PAD_LABEL=$(printf "%-${LABEL_WIDTH}s" "$label")
                REMOVED+=("$(wrap_text "$next_line" $MAX_LINE_LENGTH "  $REMOVE $PAD_LABEL · ")")
                UPDATED=true
                remove=true
                break
            fi
        done
        if $remove; then ((i+=2)); continue; fi
    fi
    [[ -n "$line" ]] && OUTPUT+=("$line")
    ((i++))
done

# 2. Process additions
MANAGED_COMMANDS=$(printf "%s\n" "${OUTPUT[@]}" | awk '/^# CRON_SYNC/{getline; print}' || true)

for ENTRY in "${ADD_JOBS[@]:-}"; do
    IFS="|" read -r LABEL SCHEDULE COMMAND <<< "$ENTRY"
    FULL_COMMAND="$SCHEDULE $COMMAND"
    PAD_LABEL=$(printf "%-${LABEL_WIDTH}s" "$LABEL")
    if echo "$MANAGED_COMMANDS" | grep -Fxq "$FULL_COMMAND"; then
        UNCHANGED+=("$(wrap_text "$FULL_COMMAND" $MAX_LINE_LENGTH "  $OK $PAD_LABEL · ")")
    else
        ADDED+=("$(wrap_text "$FULL_COMMAND" $MAX_LINE_LENGTH "  $ADD $PAD_LABEL · ")")
        OUTPUT+=("$TAG $LABEL")
        OUTPUT+=("$FULL_COMMAND")
        UPDATED=true
    fi
done

# 3. Final Reporting
[[ ${#REMOVED[@]} -gt 0 ]] && { echo -e "${RED}${BOLD}Removed (${#REMOVED[@]}):${RESET}"; printf "%s\n" "${REMOVED[@]}"; echo; }
[[ ${#ADDED[@]} -gt 0 ]] && { echo -e "${BLUE}${BOLD}Added (${#ADDED[@]}):${RESET}"; printf "%s\n" "${ADDED[@]}"; echo; }
[[ ${#UNCHANGED[@]} -gt 0 ]] && { echo -e "${GREEN}${BOLD}Unchanged (${#UNCHANGED[@]}):${RESET}"; printf "%s\n" "${UNCHANGED[@]}"; echo; }

echo -e "${BOLD}Summary:${RESET} ${RED}${#REMOVED[@]} removed${RESET} | ${BLUE}${#ADDED[@]} added${RESET} | ${GREEN}${#UNCHANGED[@]} unchanged${RESET}"
echo -e "${DIM}────────────────────────────────────────${RESET}"

if $UPDATED; then
    CLEAN_OUTPUT="$(printf "%s\n" "${OUTPUT[@]}" | sed '/^[[:space:]]*$/d')"
    if $DRY_RUN; then
        echo -e "${INFO} Changes detected (dry-run)."
        exit $EXIT_DRYRUN_CHANGED
    else
        echo "$CLEAN_OUTPUT" | crontab -
        echo -e "${INFO} Crontab updated successfully."
        exit $EXIT_CHANGED
    fi
else
    echo -e "${INFO} No changes required."
    exit $EXIT_NO_CHANGE
fi
