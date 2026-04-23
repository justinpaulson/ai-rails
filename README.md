# AI Rails

**An adaptive application that starts as a simple Rails chat interface for Claude Code — and becomes whatever you want it to be.**

AI Rails ships as a minimal, working chat app: you talk to Claude Code in your browser, and Claude Code edits the very codebase serving the chat. From that starting point, you can ask it to build anything — a task tracker, a CRM, a game, a dashboard, an entirely different app — and it will reshape itself into that. The chat is the seed; the application is whatever grows from it.

## How it works

The Rails app is a thin, persistence-and-streaming wrapper around the `claude` CLI:

- You send a prompt from the browser.
- A background job spawns `claude` as a subprocess inside the app's working directory.
- Claude Code's stream-JSON output is parsed message-by-message, persisted to SQLite, and broadcast to the browser over Turbo Streams.
- Because Claude Code runs *inside the app's own directory*, every change it makes — new models, controllers, views, migrations, gems — becomes part of the running application.

The result: a chat app that can rewrite itself in response to what you ask of it.

## Stack

- **Rails 8.1** on Puma, SQLite3
- **Hotwire** (Turbo + Stimulus) and Tailwind for the UI
- **Solid Queue** for background jobs, **Solid Cable** for WebSockets (both DB-backed)
- **Claude Code CLI** invoked via subprocess with a curated tool allowlist (Read, Glob, Grep, Edit, Write, restricted Bash)
- **Kamal** for Docker-based deployment

## Getting started

### Prerequisites

- Ruby (see `.ruby-version`)
- Node.js (for Tailwind)
- The `claude` CLI installed and authenticated on your `PATH`

### Setup

```bash
bundle install
bin/rails db:prepare
```

### Run the app

```bash
bin/dev
```

This starts three processes via `Procfile.dev`:

- `web` — the Rails server on port 3000
- `jobs` — the Solid Queue worker (required; this is what runs Claude Code)
- `css` — the Tailwind watcher

Open http://localhost:3000, start a conversation, and tell Claude Code what you want the app to become.

## Where to look

- `app/services/claude_code_service.rb` — spawns the `claude` subprocess and parses streaming output
- `app/jobs/claude_code_job.rb` — enqueues each prompt as a background job
- `app/models/message.rb` — message persistence and Turbo Stream broadcasts
- `app/controllers/conversations_controller.rb`, `messages_controller.rb` — the HTTP surface
- `config/routes.rb` — RESTful conversations with nested messages, plus `stop`, `replay`, `status`

## Deployment

Configured for Kamal — see `config/deploy.yml` and the included `Dockerfile`.
