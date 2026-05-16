# Mnemox

**Local. Native. Yours.**

Mnemox is a native macOS coding agent for Apple Silicon. It runs entirely on-device — no cloud APIs, no telemetry. Your code never leaves your machine.

> **Mnemox thinks. Models execute.**

Local 7–16B models are strong executors but weak oracles. Mnemox treats them as a team of specialists: each agent gets one atomic task, minimal context (encoded in [MXF](#mxf--mnemox-format)), and a verifiable output contract. Planning, decomposition, and coordination stay in Swift — not in the model.

**Website:** [mnemox.dev](https://mnemox.dev)

---

## Table of contents

- [Why Mnemox](#why-mnemox)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Project structure](#project-structure)
- [MXF — Mnemox Format](#mxf--mnemox-format)
- [Development](#development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Related docs](#related-docs)

---

## Why Mnemox

| Approach | Problem |
|----------|---------|
| Cloud coding agents | Code and context leave your machine |
| Single local model chat | Large prompts, vague plans, unreliable multi-file edits |
| IDE plugins with cloud fallback | Privacy and latency trade-offs |

Mnemox orchestrates **local** models with:

- **Surgical prompts** — only relevant symbols and conventions, not whole files
- **Specialist agents** — scan, plan, write, verify, i18n, tests
- **Pre-flight gates** — ambiguity, i18n, duplication, breaking changes, scope
- **Snapshots** — checkpoint and rollback before applying changes

---

## Features

### Implemented

- **Swift 6** macOS app (SwiftUI) with project sidebar, conversation panel, and inspector (Git, files, terminal, browser)
- **MXF** — compact internal protocol (encode, decode, validate, token budgeting)
- **Static analysis** — regex-based parsers for TypeScript/JS/Vue, Python, Swift, and a generic fallback
- **Core intelligence** — project scanner, dependency graph, convention profiler, impact analyzer, task decomposer, pre-flight system, snapshots
- **Orchestrator** — main agent, agent factory, message bus, agent pool, result aggregator
- **Sub-agents** — scanner, architect, writer, refactor, verifier, i18n, test
- **Model runtimes** — OpenAI-compatible clients for [vllm-mlx](https://github.com/ml-explore/mlx-examples) (`localhost:8000`) and [Ollama](https://ollama.com) (`localhost:11434`)
- **Test suite** — MXF, parsers, core, agents, model interface

### In progress

- End-to-end wiring from the SwiftUI conversation layer to `MainAgent` (orchestrator logic exists; UI currently persists chat state locally)
- Diff view and approval flow for proposed file changes
- Tree-sitter parsers and LSP integration (planned Phase 2+)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  MNEMOX.APP (SwiftUI)                                       │
│  Sidebar · Conversation · Inspector (Git / Files / Terminal)│
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │      MainAgent          │
              │  Pre-flight · Decompose │
              │  AgentFactory · Pool    │
              └────────────┬────────────┘
                           │  MXF on MessageBus
         ┌─────────────────┼─────────────────┐
         │                 │                 │
   ┌─────▼─────┐    ┌──────▼──────┐   ┌──────▼──────┐
   │  Scanner  │    │   Writer    │   │  Verifier   │
   │  Architect│    │   I18n      │   │  Test       │
   └───────────┘    └─────────────┘   └─────────────┘
                           │
              ┌────────────▼────────────┐
              │  ModelClient (shared)   │
              │  vllm-mlx · Ollama      │
              └─────────────────────────┘
```

Agents share one loaded model at a time. Parallelism is reserved for non-model work (scanning, parsing, syntax checks).

---

## Requirements

| Component | Version |
|-----------|---------|
| macOS | 14+ (Sonoma or later) |
| Hardware | Apple Silicon (M1–M4 recommended) |
| Xcode | 15+ with Swift 5.9+ |
| Local model runtime | **vllm-mlx** (primary) or **Ollama** (fallback) |

Recommended models (quantized, ~5–9 GB):

- `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` — default executor
- `mlx-community/Qwen2.5-Coder-14B-Instruct-4bit` — heavier tasks

Mnemox does **not** call external cloud APIs. If no local runtime is reachable, operations fail with an explicit error.

---

## Quick start

### 1. Clone the repository

```bash
git clone https://github.com/snowinch/mnemox.git
cd mnemox
```

### 2. Start a local model runtime

**Option A — vllm-mlx (recommended on Apple Silicon)**

Run an OpenAI-compatible server on port `8000` with the default model id:

`mlx-community/Qwen2.5-Coder-7B-Instruct-4bit`

Follow the [mlx-examples / vLLM](https://github.com/ml-explore/mlx-examples) documentation for your environment. Mnemox expects:

- Chat completions: `http://localhost:8000/v1/chat/completions`

**Option B — Ollama**

```bash
ollama pull qwen2.5-coder:7b
ollama serve
```

Mnemox uses Ollama’s OpenAI-compatible bridge:

- Chat completions: `http://localhost:11434/v1/chat/completions`

### 3. Build and run

**Using the helper script (builds a `.app` bundle and opens it):**

```bash
./run.sh
```

**Using Swift Package Manager directly:**

```bash
swift build
swift run mnemox
```

**Run tests:**

```bash
swift test
```

---

## Usage

1. Launch Mnemox (`./run.sh` or `swift run mnemox`).
2. Ensure your local model server is running (vllm-mlx on `:8000` or Ollama on `:11434`).
3. Create a **New Agent** (`⌘N`) and select a project folder.
4. Describe an atomic task in the conversation panel (e.g. “Add optional `description` prop to `SectionHero` and update all usages”).

Keyboard shortcuts:

| Shortcut | Action |
|----------|--------|
| `⌘N` | New agent / conversation |
| `⌘B` | Toggle sidebar |
| `⇧⌘R` | Toggle inspector |

Application state is stored under:

`~/Library/Application Support/Mnemox/state.json`

---

## Project structure

```
mnemox/
├── Package.swift              # SwiftPM manifest (macOS 14+ executable)
├── AGENTS.md                  # Architecture & agent rules (read before contributing)
├── SWIFTUI.md                 # macOS SwiftUI patterns for UI work
├── run.sh                     # Build .app bundle and open
├── Sources/mnemox/
│   ├── UI/                    # SwiftUI shell
│   ├── Orchestrator/          # MainAgent, factory, bus, pool
│   ├── Agents/                # Specialist agents
│   ├── MXF/                    # Internal protocol
│   ├── Core/                  # Scanner, graph, pre-flight, snapshots
│   ├── Parsers/               # Phase 1 regex parsers
│   ├── ModelInterface/        # vllm-mlx & Ollama clients
│   └── Models/                # Shared data types
└── Tests/mnemoxTests/         # Unit tests
```

---

## MXF — Mnemox Format

Internal agent and model context uses **MXF**, not natural language. MXF compresses file dependencies, component props, execution plans, and inter-agent messages into a token-efficient notation.

Example — component interface:

```
#sections/SectionHero.vue @vue
  props[badge?:str, title!:str, subtitle!:str, ctaLabel!:str, ctaHref!:str]
  <-UiCta <-useI18n
```

Full specification, operators, and examples: see **[AGENTS.md § MXF](AGENTS.md#mxf--mnemox-format)**.

---

## Development

### Conventions

- **Swift 6** strict concurrency — no `try!`, no force-unwrap in production paths
- **One file, one responsibility** — target ≤300 lines per file
- **English only** for code, comments, docs, and UI strings
- **No new Package.swift dependencies** without explicit approval (current UI dependency: [Luminare](https://github.com/MrKai77/Luminare))
- **Models stay local** — never add cloud API fallbacks

Read **[AGENTS.md](AGENTS.md)** in full before opening a PR. It is the source of truth for architecture and agent behavior.

### UI work

Follow **[SWIFTUI.md](SWIFTUI.md)** for macOS SwiftUI patterns (focus handling, `TextEditor`, layout, keyboard shortcuts).

### Model client defaults

| Runtime | Host | Default model id |
|---------|------|------------------|
| vllm-mlx | `localhost:8000` | `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` |
| Ollama | `localhost:11434` | same model id string (pull a compatible tag in Ollama) |

Configuration types live in `Sources/mnemox/ModelInterface/`.

---

## Roadmap

| Phase | Focus | Status |
|-------|--------|--------|
| **1** | MXF, parsers, core intelligence, pre-flight | Largely implemented |
| **2** | Orchestrator, specialist agents, message bus | Largely implemented |
| **3** | SwiftUI shell, multi-project sidebar, conversation | In progress (UI ↔ orchestrator integration) |
| **4** | Tree-sitter, LSP, 3B router model, plugins | Planned |

Detailed checklist: **[AGENTS.md § Current Project Status](AGENTS.md#current-project-status)** (note: the checklist may lag the codebase during active development).

---

## Contributing

1. Read [AGENTS.md](AGENTS.md).
2. Open an issue or discuss large architectural changes before implementing them (architecture changes require explicit authorization).
3. Keep PRs focused; match existing naming and layer boundaries.
4. Run `swift test` before submitting.

Bug reports and feature requests: [GitHub Issues](https://github.com/snowinch/mnemox/issues).

---

## Related docs

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Architecture, MXF spec, agent rules, roadmap |
| [SWIFTUI.md](SWIFTUI.md) | macOS SwiftUI reference for contributors |

---

## Manifesto

> *"Your code never leaves your machine."*

> *"A well-orchestrated 7B beats a poorly-orchestrated 70B."*

> *"Mnemox remembers everything about your project. You focus on the goal."*

---

*Mnemox — Local. Native. Yours.*
