---
name: journal
description: Log daily work to a Notion journal. Use /journal to summarize and log the current session, or /journal-setup for first-time configuration. Triggers on /journal or /journal-setup.
---

# Notion Daily Work Journal

Two commands — `/journal-setup` for first-time configuration, `/journal` for daily use.

Determine which command was invoked by checking the argument. If the argument is "setup" or the user said `/journal-setup`, run the Setup flow. Otherwise run the Journal flow.

## Setup Flow (`/journal-setup`)

Guide the user through configuring their Notion journal step by step. Ask one question at a time and wait for responses.

### Step 1: Create a Notion Integration

Tell the user:

> Here's how to create your Notion integration:
>
> 1. Go to **https://www.notion.so/my-integrations**
> 2. Click **"+ New integration"**
> 3. Name it something like **"Work Journal"**
> 4. Leave the workspace as your default workspace
> 5. Click **"Submit"**
> 6. On the next page, copy the **"Internal Integration Secret"** — it starts with `ntn_`
>
> Paste your integration token here when ready.

Wait for the user to paste their API key. Validate it starts with `ntn_` or `secret_`.

### Step 2: Create or Choose a Parent Page

Tell the user:

> Now you need a Notion page where the journal database will live.
>
> 1. In Notion, create a new page (or pick an existing one) — something like **"Engineering Journal"**
> 2. Open that page
> 3. Click the **"..." menu** in the top-right corner
> 4. Click **"Connect to"** and select the **"Work Journal"** integration you just created
> 5. Now grab the **page ID** from the URL — it's the 32-character string at the end of the URL (after the page name and before any `?`). It looks like: `https://www.notion.so/Your-Page-Name-abc123def456...` — the `abc123def456...` part is the ID.
>
> Paste the page ID here.

Wait for the user to paste their page ID. Strip any dashes — the API accepts the 32-char hex string with or without dashes.

### Step 3: Create the Database

Using the API key and page ID from the user, create the journal database. **Store the API key in a shell variable so it does not appear in the command text shown to the user:**

```bash
_key="<API_KEY>" && curl -s -X POST "https://api.notion.com/v1/databases" \
  -H "Authorization: Bearer $_key" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "page_id": "<PAGE_ID>" },
    "icon": { "type": "emoji", "emoji": "📓" },
    "title": [{ "type": "text", "text": { "content": "Daily Journal" } }],
    "properties": {
      "Name": { "title": {} },
      "Date": { "date": {} },
      "Tags": { "multi_select": {} }
    }
  }'
```

Replace `<API_KEY>` and `<PAGE_ID>` with the user's values. Parse the response to extract the database `id`. If the call fails, show the error and help troubleshoot (common issues: integration not connected to the page, invalid page ID).

### Step 3b: Create a Database Template

Tell the user:

> Now let's set up a template so new journal entries come pre-filled with the right structure. In Notion:
>
> 1. Open the **Engineering Journal** database you just created
> 2. Click the **dropdown arrow** next to the "New" button
> 3. Click **"+ New template"**
> 4. Set the template name to **"Daily Journal Entry"**
> 5. In the body, add four **Toggle Heading 3** blocks (type `/toggle heading 3` for each):
>    - What I worked on
>    - Decisions & Reasoning
>    - Learned
>    - Blockers / Follow-ups
> 6. Click **"Back"** to save the template
>
> Now whenever you click "New", you'll see "Daily Journal Entry" as an option with all four sections ready to go.

Wait for the user to confirm they've created the template before continuing.

### Step 3c: Create the "How to Use" Page

Create a child page under the parent page (the same `<PAGE_ID>` from Step 2) with usage documentation. Use the Notion API to create a page with the following structure:

```bash
_key="<API_KEY>" && curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $_key" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '<JSON_BODY>'
```

The page should have:
- **Parent:** the parent page ID (NOT the database)
- **Title:** "How to Use the Engineering Journal"
- **Icon:** emoji "📖"

**Page content (as Notion blocks):**

1. **Callout** (💡 icon): "This page explains how to add entries to your Engineering Journal using Claude Code or directly in Notion."
2. **Divider**
3. **Heading 1:** "Overview"
4. **Paragraph:** "The Engineering Journal lives in a Notion database. Each day gets its own page with four structured sections:"
5. **Numbered list items:**
   - "What I worked on — tasks, features, bugs, reviews"
   - "Decisions & Reasoning — choices made and why"
   - "Learned — TILs, gotchas, things to remember"
   - "Blockers / Follow-ups — things you're waiting on or need to revisit"
6. **Paragraph:** "Entries can include optional timestamps and tags (fix, feature, learning, decision, blocker, review, pairing)."
7. **Divider**
8. **Heading 1:** "/journal Command (Recommended)"
9. **Paragraph:** "At the end of any Claude Code session, run:"
10. **Quote:** "/journal"
11. **Paragraph:** "Claude will:"
12. **Numbered list items:**
    - "Review the conversation and draft a summary organized by section"
    - "Present the draft for your review"
    - "Give you three options: **Submit** as-is, **Edit** to make changes, or **Replace** with your own summary"
    - "Log the approved entries to today's journal page"
13. **Paragraph:** "This is the easiest way to keep a consistent journal — it captures work, decisions, and learnings you might forget to log manually."
14. **Divider**
15. **Heading 1:** "Ask Claude During a Session"
16. **Paragraph:** "You can also log entries ad-hoc during any Claude Code session by just asking:"
17. **Quote blocks:**
    - "Journal that I fixed the caching bug at 3pm"
    - "Add to my journal: decided to use Redis over Memcached because we need pub/sub"
    - "Journal learned: Shopify webhooks timeout after 5 seconds"
18. **Paragraph:** "Claude will call the journal script for you, picking the right section and adding timestamps when you mention them."
19. **Divider**
20. **Heading 1:** "Directly in Notion"
21. **Paragraph:** "From your laptop or phone via the Notion app:"
22. **Numbered list items:**
    - "Open the Engineering Journal database"
    - "If today's page exists, tap it and add bullets under the right section"
    - "If today's page doesn't exist yet, run /journal once to create it with the right structure, then edit in Notion"
23. **Callout** (💡 icon): "Tip: On mobile, it's easiest to let /journal create today's page first, then open it in Notion and add entries directly."
24. **Divider**
25. **Heading 1:** "Setup"
26. **Paragraph:** "If you haven't set up the journal yet, run /journal-setup in Claude Code. It will walk you through creating a Notion integration, connecting it to a page, creating the journal database, and saving your configuration."
27. **Paragraph:** "Your API key and database ID are stored in ~/.claude/settings.local.json and never shared."

Construct the full JSON body with all blocks in the `children` array. The Notion API allows up to 100 blocks per request, which is sufficient here.

If the page creation fails, log a warning but don't fail the setup — the journal itself is functional without the documentation page.

### Step 4: Save Configuration

Read the current `~/.claude/settings.local.json` (create it if it doesn't exist). Merge the following into the `env` object (preserving any existing keys):

```json
{
  "env": {
    "NOTION_API_KEY": "<the user's API key>",
    "NOTION_JOURNAL_DB": "<the database ID from step 3>"
  }
}
```

Use the Read tool to check the file first, then Edit or Write to update it.

### Step 5: Verify

Run a test query against the database to confirm it works. **Use a shell variable for the API key so it does not appear in the command text shown to the user:**

```bash
_key="<API_KEY>" && curl -s -X POST "https://api.notion.com/v1/databases/<DATABASE_ID>/query" \
  -H "Authorization: Bearer $_key" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"page_size": 1}'
```

If successful, tell the user:

> Setup complete! Your journal database is ready. Use `/journal` at the end of any session to log your work.

If it fails, help troubleshoot.

---

## Journal Flow (`/journal`)

**SECURITY: Never read `~/.claude/settings.local.json` during the journal flow. Never display, echo, or include the actual `NOTION_API_KEY` value in any output, command, or response text. The env vars are automatically injected by Claude Code — just use them by reference (`$NOTION_API_KEY`).**

### Step 1: Generate Session Summary

Skip any configuration checks — the env vars are auto-injected by Claude Code from `settings.local.json`. If they are missing, the journal script will fail with a clear error in Step 3, at which point tell the user to run `/journal-setup`.

Review the full conversation history from this session. Produce a draft summary organized into these sections:

- **What I worked on** — Each distinct piece of work as a separate bullet. Be specific (e.g., "Fixed race condition in SSR hydration for product pages" not "Worked on SSR").
- **Decisions & Reasoning** — Choices made during the session and why (e.g., "Chose Redis over Memcached — need pub/sub for cache invalidation").
- **Learned** — Things discovered, surprising findings, new knowledge (e.g., "Shopify webhooks have a 5s timeout for responses").
- **Blockers / Follow-ups** — Unresolved issues, things to pick up next time, items waiting on someone else.

Omit sections that have no entries. Each section can have multiple bullets if there were multiple distinct items.

**Hyperlinks:** When entries reference pull requests, issues, commits, or other web resources from the session, include markdown-style links in the entry text so they render as clickable links in Notion. Use the actual URLs from the session context (e.g., `gh pr view` output, GitHub URLs mentioned by the user, issue tracker links). Examples:
- "Fixed race condition in [PR #123](https://github.com/org/repo/pull/123)"
- "Investigated [JIRA-456](https://jira.example.com/browse/JIRA-456) — root cause was stale cache"

For GitHub PRs, construct the URL from the repo origin and PR number if not already available. Do not fabricate URLs — only link when you have the actual URL or can reliably construct it.

**Grouping related items under shared context:** When multiple bullets across different sections share a common context — a meeting, a PR code review, a pairing session, an incident, etc. — group them under a parent bullet that names that context. Items related to the same context become sub-bullets under the parent. Present them indented in the draft summary so the user sees the nesting. Unrelated work in the same session gets its own top-level bullets as normal.

Examples:
- A meeting produces entries in both "What I worked on" and "Decisions & Reasoning" → each section gets a parent bullet like "Canada Expansion Home Base meeting" with the specific items as sub-bullets.
- A PR code review produces entries across multiple sections → each section gets a parent bullet like "Reviewed PR #123 — summary" with specific findings as sub-bullets.
- A debugging session produces entries in "What I worked on" and "Learned" → each section gets a parent bullet like "Debugging cart race condition" with details as sub-bullets.

### Step 2: Present Draft and Collect Response

Show the summary to the user, formatted clearly with section headers and bullet points. Then use the `AskUserQuestion` tool to let them choose an action:

- **Question:** "How does this look?"
- **Options:**
  - **Submit** — "Log these entries to today's journal as-is"
  - **Edit** — "I'll tell you what to change"
  - **Replace** — "I'll provide my own summary instead"

**Handle the response:**

- **Submit**: Proceed to Step 4.
- **Edit**: The user will provide corrections via the "Other" text input or as a follow-up message. Apply their corrections, show the revised summary, and present the same `AskUserQuestion` again (loop).
- **Replace**: The user will provide entirely new content. Organize it into the four sections as appropriate, show it for confirmation, and present the same `AskUserQuestion` again (loop).

### Step 3: Submit Entries

For each bullet in each non-empty section, call the journal script:

```bash
~/.claude/skills/notion-journal/notion-journal.sh <section> "<entry text>" [--tags tag1,tag2] [--sub "sub-bullet text"]...
```

Section mapping:
- "What I worked on" → `worked`
- "Decisions & Reasoning" → `decision`
- "Learned" → `learned`
- "Blockers / Follow-ups" → `blocker`

For tags: include relevant project names, repo names, or ticket numbers that came up in the session (e.g., `GLOW`, `WICK`, `Refill`). If none are obvious, omit `--tags`.

For entries with sub-bullets (e.g., grouped PR review items), use `--sub` for each nested item:

```bash
~/.claude/skills/notion-journal/notion-journal.sh worked "Reviewed [PR #527](https://github.com/org/repo/pull/527) — cart error handling fix" --sub "Posted inline comment with code suggestion for naming consistency" --tags WICK,review
```

### Step 4: Confirm

Report what was logged:

> Logged to today's journal:
> - X items under "What I worked on"
> - Y items under "Decisions & Reasoning"
> - (etc.)
