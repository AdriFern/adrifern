# Morning Briefing — Thursday 21 May 2026

> CONNECTOR FAILURE: All MCP connectors (Asana, Google Calendar, Gmail) returned "MCP tool call requires approval" after 3 retries each. No live data could be fetched this run. The briefing below is a shell only.
>
> To fix: the routine needs MCP tool permissions added to the allowlist so it can run unattended. The tools needing approval are from the `Asana`, `Google-Calendar`, and `Gmail` MCP servers.

---

## 1. Today's focus

Source not available (Asana MCP blocked after 3 retries). Cannot produce today's focus list without task data.

Suggested first action at 8 AM: open Asana manually, check "Do today" section, and triage anything that arrived overnight.

---

## 2. Calendar

Source not available (Google Calendar MCP blocked after 3 retries).

Reminder: main work calendar is Outlook and not reachable. Check Outlook manually for work meetings.

---

## 3. Email

Source not available (Gmail MCP blocked after 3 retries).

Reminder: work email is on Outlook, not reachable. Check Outlook manually.

---

## 4. Teams

Teams not reachable from this routine, check manually.

---

## 5. Asana

Source not available (Asana MCP blocked after 3 retries). Sections 5.1 through 5.4 could not be generated.

---

## 6. Yesterday's shipped

Source not available (Asana MCP blocked). Could not retrieve completed tasks from 2026-05-20.

---

## Fix required before next run

The routine runs unattended at 7:30 AM. All three MCP servers need their tool calls added to the project permissions allowlist so they fire without approval prompts. The affected servers are:

- `Asana` (get_tasks, get_my_tasks, search_tasks, get_task, get_project, add_comment)
- `Google-Calendar` (list_events, list_calendars)
- `Gmail` (search_threads, get_thread)

Until those permissions are added, every morning run will produce a blank briefing like this one.
