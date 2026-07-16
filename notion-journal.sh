#!/usr/bin/env bash
# notion-journal.sh — Append entries to the Engineering Journal database in Notion
#
# Usage:
#   notion-journal.sh <section> <entry> [--time HH:MM AM/PM] [--tags tag1,tag2]
#
# Sections: worked, decision, learned, blocker
#
# Examples:
#   notion-journal.sh worked "Fixed race condition in SSR hydration" --time "10:30 AM"
#   notion-journal.sh decision "Chose Redis over Memcached — need pub/sub" --tags decision
#   notion-journal.sh learned "Shopify webhooks have a 5s timeout"
#   notion-journal.sh blocker "Waiting on DevOps for staging Redis cluster"

set -euo pipefail

# Load config from settings.local.json if env vars are not already set
_config_file="$HOME/.claude/settings.local.json"
if [[ -z "${NOTION_API_KEY:-}" || -z "${NOTION_JOURNAL_DB:-}" ]] && [[ -f "$_config_file" ]]; then
  NOTION_API_KEY="${NOTION_API_KEY:-$(python3 -c "import json; print(json.load(open('$_config_file')).get('env',{}).get('NOTION_API_KEY',''))" 2>/dev/null)}"
  NOTION_JOURNAL_DB="${NOTION_JOURNAL_DB:-$(python3 -c "import json; print(json.load(open('$_config_file')).get('env',{}).get('NOTION_JOURNAL_DB',''))" 2>/dev/null)}"
fi

if [[ -z "${NOTION_API_KEY:-}" ]]; then
  echo "Error: NOTION_API_KEY not found. Run /journal-setup to configure." >&2; exit 1
fi
if [[ -z "${NOTION_JOURNAL_DB:-}" ]]; then
  echo "Error: NOTION_JOURNAL_DB not found. Run /journal-setup to configure." >&2; exit 1
fi
DATABASE_ID="$NOTION_JOURNAL_DB"
NOTION_VERSION="2022-06-28"
TODAY=$(date +%Y-%m-%d)
TODAY_DISPLAY=$(date +"%A, %B %-d, %Y")

# --- Parse arguments ---
SECTION="${1:?Usage: notion-journal.sh <worked|decision|learned|blocker> <entry> [--time TIME] [--tags tag1,tag2]}"
ENTRY="${2:?Missing entry text}"
shift 2

TIMESTAMP=""
TAGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --time) TIMESTAMP="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Map section names to bold headers
case "$SECTION" in
  worked)   SECTION_HEADER="What I worked on" ;;
  decision) SECTION_HEADER="Decisions & Reasoning" ;;
  learned)  SECTION_HEADER="Learned" ;;
  blocker)  SECTION_HEADER="Blockers / Follow-ups" ;;
  *) echo "Unknown section: $SECTION (use: worked, decision, learned, blocker)" >&2; exit 1 ;;
esac

# --- Helper: Notion API call ---
notion_api() {
  local method="$1" endpoint="$2" body="${3:-}"
  local args=(
    -s -X "$method"
    "https://api.notion.com/v1${endpoint}"
    -H "Authorization: Bearer $NOTION_API_KEY"
    -H "Notion-Version: $NOTION_VERSION"
    -H "Content-Type: application/json"
  )
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}"
}

# --- Find or create today's page ---
find_today_page() {
  local response
  response=$(notion_api POST "/databases/$DATABASE_ID/query" "$(cat <<ENDJSON
{
  "filter": {
    "property": "Date",
    "date": { "equals": "$TODAY" }
  }
}
ENDJSON
)")
  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('results', [])
if results:
    print(results[0]['id'])
" 2>/dev/null
}

create_today_page() {
  local tags_json="[]"
  if [[ -n "$TAGS" ]]; then
    tags_json=$(echo "$TAGS" | python3 -c "
import sys, json
tags = sys.stdin.read().strip().split(',')
print(json.dumps([{'name': t.strip()} for t in tags if t.strip()]))
")
  fi

  local response
  response=$(notion_api POST "/pages" "$(cat <<ENDJSON
{
  "parent": { "database_id": "$DATABASE_ID" },
  "icon": { "type": "emoji", "emoji": "📝" },
  "properties": {
    "Name": { "title": [{ "text": { "content": "$TODAY_DISPLAY" } }] },
    "Date": { "date": { "start": "$TODAY" } },
    "Tags": { "multi_select": $tags_json }
  },
  "children": [
    {
      "type": "heading_3",
      "heading_3": {
        "rich_text": [{ "type": "text", "text": { "content": "What I worked on" } }],
        "is_toggleable": true
      }
    },
    {
      "type": "heading_3",
      "heading_3": {
        "rich_text": [{ "type": "text", "text": { "content": "Decisions & Reasoning" } }],
        "is_toggleable": true
      }
    },
    {
      "type": "heading_3",
      "heading_3": {
        "rich_text": [{ "type": "text", "text": { "content": "Learned" } }],
        "is_toggleable": true
      }
    },
    {
      "type": "heading_3",
      "heading_3": {
        "rich_text": [{ "type": "text", "text": { "content": "Blockers / Follow-ups" } }],
        "is_toggleable": true
      }
    }
  ]
}
ENDJSON
)")
  echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null
}

# --- Find the section heading block, then append a bullet under it ---
find_section_block() {
  local page_id="$1" target_header="$2"
  local response
  response=$(notion_api GET "/blocks/$page_id/children?page_size=100")
  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target = '$target_header'
for block in data.get('results', []):
    if block.get('type') == 'heading_3':
        texts = block['heading_3'].get('rich_text', [])
        if texts and texts[0].get('plain_text', '') == target:
            print(block['id'])
            break
" 2>/dev/null
}

append_bullet() {
  local block_id="$1" text="$2" timestamp="$3"

  local rich_text
  if [[ -n "$timestamp" ]]; then
    rich_text=$(ENTRY_TS="$timestamp" ENTRY_TEXT="$text" python3 -c "
import json, os
print(json.dumps([
  {'type': 'text', 'text': {'content': os.environ['ENTRY_TS']}, 'annotations': {'bold': True}},
  {'type': 'text', 'text': {'content': ' — ' + os.environ['ENTRY_TEXT']}}
]))
")
  else
    rich_text=$(ENTRY_TEXT="$text" python3 -c "
import json, os
print(json.dumps([
  {'type': 'text', 'text': {'content': os.environ['ENTRY_TEXT']}}
]))
")
  fi

  notion_api PATCH "/blocks/$block_id/children" "$(cat <<ENDJSON
{
  "children": [
    {
      "type": "bulleted_list_item",
      "bulleted_list_item": {
        "rich_text": $rich_text
      }
    }
  ]
}
ENDJSON
)" > /dev/null
}

# --- Update tags on the page if provided ---
update_tags() {
  local page_id="$1" new_tags="$2"
  [[ -z "$new_tags" ]] && return

  # Get existing tags
  local existing
  existing=$(notion_api GET "/pages/$page_id" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tags = data.get('properties', {}).get('Tags', {}).get('multi_select', [])
print(','.join(t['name'] for t in tags))
" 2>/dev/null)

  # Merge existing + new, deduplicate
  local merged
  merged=$(EXISTING_TAGS="$existing" NEW_TAGS="$new_tags" python3 -c "
import json, os
existing = set(os.environ.get('EXISTING_TAGS','').split(',')) if os.environ.get('EXISTING_TAGS') else set()
new = set(os.environ.get('NEW_TAGS','').split(','))
merged = existing | new
merged.discard('')
print(json.dumps([{'name': t.strip()} for t in sorted(merged)]))
")

  notion_api PATCH "/pages/$page_id" "$(cat <<ENDJSON
{
  "properties": {
    "Tags": { "multi_select": $merged }
  }
}
ENDJSON
)" > /dev/null
}

# --- Main ---
PAGE_ID=$(find_today_page)

if [[ -z "$PAGE_ID" ]]; then
  echo "Creating journal page for $TODAY_DISPLAY..."
  PAGE_ID=$(create_today_page)
  if [[ -z "$PAGE_ID" ]]; then
    echo "Error: Failed to create today's page" >&2
    exit 1
  fi
  echo "Created: $TODAY_DISPLAY"
else
  echo "Found existing page for $TODAY_DISPLAY"
fi

# Find the right section heading
BLOCK_ID=$(find_section_block "$PAGE_ID" "$SECTION_HEADER")

if [[ -z "$BLOCK_ID" ]]; then
  echo "Error: Could not find section '$SECTION_HEADER' on today's page" >&2
  exit 1
fi

# Append the bullet
append_bullet "$BLOCK_ID" "$ENTRY" "$TIMESTAMP"

# Update tags if provided
update_tags "$PAGE_ID" "$TAGS"

echo "Added to $SECTION_HEADER: $ENTRY"
