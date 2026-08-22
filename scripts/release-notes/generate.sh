#!/usr/bin/env bash
#
# Generates the TestFlight "What to Test" texts for de-DE and en-US from the
# commits since the last release tag, and writes them to dist/notes/.
#
# Stateless by design: the range is always <last v* tag>..HEAD, so the notes are
# cumulative for the whole test cycle and reproducible for any given commit.
# The previous build's notes are passed in as an anchor so wording stays stable
# between builds instead of being re-invented every run.
#
# This script never fails the build. Every error path falls back to a plain
# commit list and exits 0.
set -euo pipefail

MODEL="claude-haiku-4-5-20251001"
MAX_TOKENS=2000
# App Store Connect rejects anything longer. Measured in bytes, which is at or
# above the character count for UTF-8, so staying under it is always safe.
MAX_BYTES=4000
# A single tag that is moved on every build, rather than one tag per build:
# the anchor only ever needs the immediately preceding notes, and a tag per
# build would bury the release tags in the repository's tag list.
ANCHOR_TAG="release-notes/latest"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel)
SYSTEM_PROMPT="${SCRIPT_DIR}/system-prompt.md"
OUT_DIR="${REPO_ROOT}/dist/notes"
OVERRIDE_DIR="${REPO_ROOT}/release-notes"
DE_OUT="${OUT_DIR}/WhatToTest.de-DE.txt"
EN_OUT="${OUT_DIR}/WhatToTest.en-US.txt"
JSON_OUT="${OUT_DIR}/notes.json"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT_DIR"

warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*" >&2; }

# --------------------------------------------------------------------------
# Commit range
# --------------------------------------------------------------------------
# git describe exits non-zero when nothing matches, which would abort under
# `set -e`, hence the guard.
BASE=$(git describe --tags --match 'v*' --abbrev=0 HEAD 2>/dev/null || true)
if [ -n "$BASE" ]; then
    LOG_ARGS=("${BASE}..HEAD")
    RANGE_LABEL="${BASE}..HEAD"
else
    LOG_ARGS=(-n 50 HEAD)
    RANGE_LABEL="last 50 commits (no v* tag yet)"
fi

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Drops whole lines from the end until the file fits the limit, so the text
# never ends mid-sentence.
truncate_to_limit() {
    local file=$1 limit=$2 tmp size line len
    if [ "$(wc -c < "$file")" -le "$limit" ]; then
        return 0
    fi
    # Accumulates line by line and stops before the first line that would cross
    # the limit. Deliberately avoids `head -n -1`, which is GNU-only and would
    # break when the script is run locally on macOS.
    tmp="${WORK}/truncated.txt"
    : > "$tmp"
    size=0
    while IFS= read -r line || [ -n "$line" ]; do
        len=$(printf '%s\n' "$line" | wc -c | tr -d ' ')
        if [ $(( size + len )) -gt "$limit" ]; then
            break
        fi
        printf '%s\n' "$line" >> "$tmp"
        size=$(( size + len ))
    done < "$file"
    mv "$tmp" "$file"
    warn "$(basename "$file") exceeded ${limit} bytes and was shortened at a line boundary."
}

# Single exit point. Every path lands here so the outputs are always shaped the
# same way, including notes.json, which is what the anchor tag stores - both
# locales, so the English wording is held steady across builds too.
finish() {
    truncate_to_limit "$DE_OUT" "$MAX_BYTES"
    truncate_to_limit "$EN_OUT" "$MAX_BYTES"
    jq -n --rawfile de "$DE_OUT" --rawfile en "$EN_OUT" \
        '{"de-DE": $de, "en-US": $en}' > "$JSON_OUT"
    info "Range: ${RANGE_LABEL}"
    info "de-DE: $(wc -c < "$DE_OUT" | tr -d ' ') bytes, en-US: $(wc -c < "$EN_OUT" | tr -d ' ') bytes"
    exit 0
}

# Plain commit list, used whenever the model cannot be reached or disagrees
# with its own output format.
write_fallback() {
    git log --oneline "${LOG_ARGS[@]}" > "$DE_OUT"
    cp "$DE_OUT" "$EN_OUT"
    warn "Fell back to a plain commit list."
    finish
}

# --------------------------------------------------------------------------
# Override: hand-written notes in the repo win outright
# --------------------------------------------------------------------------
if [ -f "${OVERRIDE_DIR}/WhatToTest.de-DE.txt" ]; then
    info "Using the checked-in override in ${OVERRIDE_DIR}; skipping the model call."
    cp "${OVERRIDE_DIR}/WhatToTest.de-DE.txt" "$DE_OUT"
    if [ -f "${OVERRIDE_DIR}/WhatToTest.en-US.txt" ]; then
        cp "${OVERRIDE_DIR}/WhatToTest.en-US.txt" "$EN_OUT"
    else
        warn "No en-US override next to the de-DE one; reusing the German text."
        cp "$DE_OUT" "$EN_OUT"
    fi
    finish
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    warn "ANTHROPIC_API_KEY is not set."
    write_fallback
fi

# --------------------------------------------------------------------------
# Previous notes, read from the message of the moving anchor tag
# --------------------------------------------------------------------------
# Kept in a tag rather than a commit so writing them back cannot trigger
# another workflow run.
git log --first-parent --reverse --pretty=format:'- %s%n%b' "${LOG_ARGS[@]}" \
    > "${WORK}/commits.txt"

: > "${WORK}/previous.txt"
if git rev-parse -q --verify "refs/tags/${ANCHOR_TAG}" >/dev/null; then
    git tag -l --format='%(contents)' "$ANCHOR_TAG" > "${WORK}/previous.txt"
    info "Previous notes taken from ${ANCHOR_TAG}."
else
    info "No ${ANCHOR_TAG} tag yet; generating without a previous-notes anchor."
fi

# --------------------------------------------------------------------------
# Request
# --------------------------------------------------------------------------
# Built entirely with jq --rawfile. Commit messages routinely contain quotes,
# newlines and emoji, so string interpolation would produce invalid JSON.
# shellcheck disable=SC2016  # the $-names below are jq variables, not shell ones
jq -n \
    --arg model "$MODEL" \
    --argjson max_tokens "$MAX_TOKENS" \
    --rawfile system "$SYSTEM_PROMPT" \
    --rawfile commits "${WORK}/commits.txt" \
    --rawfile previous "${WORK}/previous.txt" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        temperature: 0,
        system: $system,
        messages: [
            {
                role: "user",
                content: ("<commits>\n" + $commits + "\n</commits>\n\n"
                          + "<previous_notes>\n" + $previous + "\n</previous_notes>")
            },
            # Prefill: the reply is forced to continue an open brace, which
            # keeps the model from wrapping the JSON in prose or fences. The
            # brace is prepended again when parsing.
            { role: "assistant", content: "{" }
        ]
    }' > "${WORK}/request.json"

HTTP_CODE=$(curl -sS --max-time 120 \
    -o "${WORK}/response.json" \
    -w '%{http_code}' \
    https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    --data-binary "@${WORK}/request.json" || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    warn "The API returned HTTP ${HTTP_CODE}."
    if [ -s "${WORK}/response.json" ]; then
        jq -r '.error.message // empty' "${WORK}/response.json" >&2 || true
    fi
    write_fallback
fi

# --------------------------------------------------------------------------
# Parse and validate
# --------------------------------------------------------------------------
if ! jq -r '.content[] | select(.type == "text") | .text' "${WORK}/response.json" \
        > "${WORK}/text.txt"; then
    warn "Could not read a text block from the response."
    write_fallback
fi

# Put back the brace the prefill consumed.
{ printf '{'; cat "${WORK}/text.txt"; } > "${WORK}/notes.json"

if ! jq -e 'has("de-DE") and has("en-US")' "${WORK}/notes.json" >/dev/null 2>&1; then
    warn "The model did not return valid JSON with both locales."
    write_fallback
fi

jq -r '."de-DE"' "${WORK}/notes.json" > "$DE_OUT"
jq -r '."en-US"' "${WORK}/notes.json" > "$EN_OUT"

if [ ! -s "$DE_OUT" ] || [ ! -s "$EN_OUT" ]; then
    warn "At least one of the two texts came back empty."
    write_fallback
fi

finish
