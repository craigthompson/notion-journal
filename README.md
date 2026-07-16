# Notion Daily Journal for Claude Code

A Claude Code skill that logs your daily engineering work to a structured Notion database. Run `/journal` at the end of any session and Claude summarizes what you worked on, decisions made, things learned, and blockers.

## Installation

Clone this repo into your Claude Code skills directory:

```bash
git clone <repo-url> ~/.claude/skills/notion-journal
```

Make the script executable:

```bash
chmod +x ~/.claude/skills/notion-journal/notion-journal.sh
```

## Setup

Open Claude Code and run:

```
/journal-setup
```

This walks you through:

1. Creating a Notion integration at https://www.notion.so/my-integrations
2. Connecting it to a Notion page
3. Creating the journal database
4. Saving your credentials locally

Your API key and database ID are stored in `~/.claude/settings.local.json` (never committed or shared).

## Usage

### End-of-session summary

```
/journal
```

Claude reviews the conversation, drafts a summary organized into four sections, and lets you review before submitting:

- **What I worked on** -- tasks, features, bugs, reviews
- **Decisions & Reasoning** -- choices made and why
- **Learned** -- TILs, gotchas, things to remember
- **Blockers / Follow-ups** -- things waiting on someone else or to revisit

### Ad-hoc entries

You can also log entries during a session by asking Claude directly:

- "Journal that I fixed the caching bug at 3pm"
- "Add to my journal: decided to use Redis over Memcached because we need pub/sub"
- "Journal learned: Shopify webhooks timeout after 5 seconds"

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- A Notion account with permission to create integrations
- Python 3 (used by the shell script for JSON parsing)
- curl
