# AGENTS.md — Mnemox

> Source of truth for any AI agent (Cursor, Claude, Copilot) working on this codebase.
> Read this file entirely before touching any file.
> Last updated: May 2026 (includes native-first UI rule)

---
## Resources
> [SWIFTUI.md](./SWIFTUI.md) - Before building ui consult this document to get the right context on swift ui docs.
---

## What is Mnemox

Mnemox is a native macOS coding agent written in Swift 6.
It runs entirely on-device on Apple Silicon. Zero cloud. Zero telemetry.
The user's code never leaves their machine.

**The problem it solves:**
Local 7–16B models are powerful but fail on complex tasks because they are
used as monolithic oracles. Mnemox orchestrates them as a team of specialists —
each with an atomic task, minimal context, and verifiable output.

**The core principle:**
> Mnemox thinks. Models execute.

No model ever plans, decides, or chooses what to do next.
It receives one atomic task with complete context and produces structured output.
Everything else is Mnemox.

---

## General Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       MNEMOX.APP                            │
│                                                             │
│   ProjectSidebar    ConversationPanel      DiffView         │
│   ─────────────     ─────────────────      ────────         │
│   Projects          Chat with Main Agent   File changes     │
│   Active agents     Activity log           Approval flow    │
│   History           Sub-agent status       Branch/commit    │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │       ORCHESTRATOR      │
              │       (Main Agent)      │
              │                         │
              │  1. Receives user task  │
              │  2. Analyzes scope      │
              │  3. Pre-flight checks   │
              │  4. Creates sub-agents  │
              │  5. Coordinates flow    │
              │  6. Aggregates results  │
              │  7. Presents diff       │
              └────────────┬────────────┘
                           │ MessageBus [MXF]
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────▼─────┐   ┌──────▼─────┐  ┌──────▼─────┐
    │  Scanner  │   │  Writer    │  │  Verifier  │
    │  Agent    │   │  Agent     │  │  Agent     │
    └───────────┘   └────────────┘  └────────────┘
    ArchitectAgent   I18nAgent        TestAgent ...
```

**Internal agent communication uses MXF exclusively.**
Natural language is only used for user-facing output.

---

## Tech Stack

### Application
- **Language**: Swift 6, strict concurrency enabled
- **UI**: SwiftUI native macOS 13+; **native-first** controls only (see Absolute Rule **10**)
- **Target hardware**: Apple Silicon M1–M4 Max
- **No Electron, Python, or Node.js dependencies**

### Local Models
- **Primary runtime**: vllm-mlx — native Apple Silicon, MCP tool calling
- **Fallback runtime**: Ollama
- **Interface**: any OpenAI-compatible local endpoint
- **No cloud models — ever. No fallback to external APIs.**
- **Recommended models**:
  - `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` (~5GB) — standard executor
  - `mlx-community/Qwen2.5-Coder-14B-Instruct-4bit` (~9GB) — complex tasks
  - 3B model — router/classifier (Phase 3)

### Universal Parsing
- **Phase 1**: Regex-based parser (zero external dependencies)
- **Phase 2**: Tree-sitter (C library with Swift bindings)

---

## Project Structure

```
mnemox/
├── Package.swift
├── Support/
│   └── MnemoxEmbeddedInfo.plist          ← linked into the executable (bundle ID + version for Xcode/SPM)
├── AGENTS.md                              ← this file
│
├── Sources/mnemox/
│   │
│   ├── main.swift                         ← app entry point
│   │
│   ├── UI/                                ← SwiftUI layer
│   │   ├── MnemoxApp.swift                ← app shell
│   │   ├── ProjectSidebar.swift           ← projects and active agents list
│   │   ├── ConversationPanel.swift        ← chat + activity log
│   │   ├── DiffView.swift                 ← proposed changes + approval
│   │   ├── AgentStatusBar.swift           ← real-time agent activity
│   │   └── Components/                    ← reusable UI components
│   │
│   ├── Orchestrator/                      ← system brain
│   │   ├── MainAgent.swift                ← entry point, receives user task
│   │   ├── AgentFactory.swift             ← creates sub-agents based on task
│   │   ├── AgentPool.swift                ← manages agents and RAM
│   │   ├── MessageBus.swift               ← inter-agent communication [MXF]
│   │   └── ResultAggregator.swift         ← combines agent outputs
│   │
│   ├── Agents/                            ← vertical sub-agents
│   │   ├── BaseAgent.swift                ← base protocol
│   │   ├── ScannerAgent.swift             ← repo analysis
│   │   ├── ArchitectAgent.swift           ← approach planning
│   │   ├── WriterAgent.swift              ← code generation
│   │   ├── RefactorAgent.swift            ← code optimization
│   │   ├── I18nAgent.swift                ← translation management
│   │   ├── TestAgent.swift                ← test writing and verification
│   │   └── VerifierAgent.swift            ← correctness verification
│   │
│   ├── MXF/                               ← Mnemox Format — internal protocol
│   │   ├── MXFSchema.swift                ← formal format definition
│   │   ├── MXFEncoder.swift               ← data structures → compact format
│   │   ├── MXFDecoder.swift               ← compact format → data structures
│   │   ├── MXFValidator.swift             ← message validity verification
│   │   └── MXFTokenCounter.swift          ← token measurement before dispatch
│   │
│   ├── Core/                              ← intelligence layer
│   │   ├── ProjectScanner.swift           ← language and framework detection
│   │   ├── DependencyGraph.swift          ← dependency graph
│   │   ├── ConventionProfiler.swift       ← project conventions
│   │   ├── PreFlightSystem.swift          ← pre-execution validation
│   │   ├── ImpactAnalyzer.swift           ← change impact analysis
│   │   ├── TaskDecomposer.swift           ← complex task decomposition
│   │   └── SnapshotManager.swift          ← checkpoint and rollback
│   │
│   ├── Parsers/                           ← static code analysis
│   │   ├── UniversalParser.swift          ← language dispatcher
│   │   ├── TypeScriptParser.swift         ← TS/JS/Vue/Nuxt/Next/React
│   │   ├── PythonParser.swift             ← Python/FastAPI/Django
│   │   ├── SwiftParser.swift              ← Swift/SwiftUI/SPM
│   │   └── GenericParser.swift            ← regex-based fallback
│   │
│   ├── ModelInterface/                    ← model runtime abstraction
│   │   ├── ModelClient.swift              ← base protocol
│   │   ├── VllmMLXClient.swift            ← vllm-mlx adapter
│   │   ├── OllamaClient.swift             ← Ollama adapter
│   │   ├── PromptEngine.swift             ← builds surgical prompts via MXF
│   │   └── ResponseParser.swift          ← parses structured model output
│   │
│   └── Models/                            ← data structures
│       ├── AgentMessage.swift             ← inter-agent messages
│       ├── FileDependency.swift           ← single dependency
│       ├── ProjectSnapshot.swift          ← full project state
│       ├── ConventionProfile.swift        ← detected conventions
│       ├── ComponentInterface.swift       ← props, emits, slots
│       ├── ImpactReport.swift             ← change impact report
│       └── ExecutionPlan.swift            ← execution plan
│
└── Tests/mnemoxTests/
    ├── MXFTests.swift                     ← encode/decode/validate
    ├── ParserTests.swift
    ├── CoreTests.swift
    └── AgentTests.swift
```

---

## Absolute Rules

### 1. Architecture is immutable without explicit authorization
Structure and file responsibilities are defined here.
Propose changes as a comment — never implement them unilaterally.

### 2. One file, one responsibility
No file exceeds 300 lines. If it does, split it.
No logic from one layer bleeds into another.

### 3. Zero unauthorized dependencies
Do not modify `Package.swift` without explicit authorization.
Authorized dependencies are listed in the Dependencies section.

### 4. Always structured output
- **stdout**: valid parseable JSON (for orchestrator and tools)
- **stderr**: human-readable logs (for debugging)
- **exit code**: 0 success, 1 error, 2 warning with partial output

### 5. Never hardcode paths or framework conventions
Paths are always resolved dynamically from project root.
Conventions are always detected by `ConventionProfiler` — never assumed.

### 6. Swift 6 strict concurrency
- No `try!`
- No force unwrap `!` on nullable values in production
- Every error propagated, logged to stderr, appropriate exit code
- Actor isolation respected everywhere

### 7. Testability in isolation
Every Core component testable without a real filesystem.
Dependency injection everywhere. No static dependencies.

### 8. Models are always local
No cloud API calls. No external service fallbacks.
If local model unavailable → explicit error to user.

### 9. All code, comments, documentation, and UI must be in English
This is a mandatory rule for an open source project.
The only exception is user-provided content (filenames, strings, etc.).

### 10. Native-first UI (macOS)
The app is a **native SwiftUI macOS product**. Prefer system building blocks and semantics; do not reinvent standard controls.

- **Prefer SwiftUI built-ins**: `TextField`, `TextEditor`, `SecureField`, `Button`, `Toggle`, `Picker`, `Menu`, `List`, `Table`, `NavigationSplitView`, `Label`, `ProgressView`, `DisclosureGroup`, `GroupBox`, `Form`, `Section`, and standard materials (e.g. `regularMaterial`). Use dynamic colors (`foregroundStyle`, `Color(nsColor:)`) over ad-hoc RGB.
- **No AppKit bridging for what SwiftUI already provides** (e.g. multiline input = `TextEditor`). Use `NSViewRepresentable` / `NSOpenPanel` / `NSAlert` only when there is no SwiftUI API—add a one-line comment at the call site explaining why.
- **Prefer `Label`** over manual `HStack { Image; Text }` for actions and list-style rows when it fits.
- **`UI/` shared pieces** (`Components/`): only **thin composition** (shared padding, grouped layout, tiny helpers). Do **not** ship custom “fake” buttons, bespoke spinners, or lookalike text fields when `Button` + `.buttonStyle`, `ProgressView`, and `TextEditor` suffice. Extend natives via `.buttonStyle`, `.controlSize`, `.tint`, and accessibility labels.
- **Diff / domain visuals** (e.g. green/red line hints) may use semantic system colors when they convey patch meaning, not decorative chrome.

---

## MXF — Mnemox Format

MXF is the internal communication protocol between agents and the model.
It is designed to minimize token usage while preserving full semantic meaning.
**Natural language is never used for internal agent communication.**

### Design principles

- No redundant keywords — node type is implicit from position and symbol
- Hierarchy via minimal indentation (2 spaces)
- Abbreviated types
- Relationships via operators
- File references via `#`

### Type abbreviations

```
str   → string
num   → number
bool  → boolean
fn    → function
arr   → array
obj   → object
?     → optional
!     → required
*     → variadic
void  → no return value
```

### Relationship operators

```
->    returns / produces
<-    depends on / imports
~>    emits (events)
=>    implements (interface/protocol)
::    belongs to (namespace/module)
@     framework annotation
#     file reference
+     add
-     remove
~     modify
```

### MXF Node types

```
// File node
#path/to/file.ext @framework?
  <-imports[sym1,sym2] from #path
  tmpl[Comp1,Comp2]
  auto[use1,use2]

// Symbol declaration
name[!?]:type ->returnType

// Props block (components)
props[name!:type, name?:type default=val]

// Execution plan
PLAN:action/target
  N:AGENT_TYPE action params
  N:AGENT_TYPE action params

// Convention profile
@framework @modifier
rule:value CONSTRAINT

// Impact report
IMPACT:symbol changeType
  file[reason] requiresUpdate:bool

// Agent message
MSG from:AgentID to:AgentID type
  payload
```

### MXF examples — token comparison

**Component interface:**
```
// VERBOSE — 89 tokens
// SectionHero component located at app/components/sections/SectionHero.vue
// This component accepts the following props:
// - badge: optional string for the badge text above the title
// - title: required string for the main heading
// - subtitle: required string for the subtitle text
// - ctaLabel: required string for the CTA button label
// - ctaHref: required string for the CTA button URL
// Uses UiCta component internally. Uses useI18n for translations.

// MXF — 22 tokens
#sections/SectionHero.vue @vue
  props[badge?:str, title!:str, subtitle!:str, ctaLabel!:str, ctaHref!:str]
  <-UiCta <-useI18n
```

**File with dependencies:**
```
// VERBOSE — 71 tokens
// File: app/pages/index.vue
// Imports CLIENT_LOGOS, COMPANY, portfolioCaseHomeImage from constants.ts
// Imports CaseEntry, FaqItem, IntroPillar, ProcessStep types from types/home.ts
// Uses composables: useI18n, useHead, definePageMeta
// Uses components: SectionHero, SectionClientLogos, SectionIntro...

// MXF — 38 tokens
#pages/index.vue @nuxt
  <-constants[CLIENT_LOGOS,COMPANY,portfolioCaseHomeImage]
  <-types/home[CaseEntry,FaqItem,IntroPillar,ProcessStep,ServiceEntry,StatEntry]
  auto[useI18n,useHead,definePageMeta]
  tmpl[SectionHero,SectionClientLogos,SectionIntro,SectionServices,
       SectionCases,SectionProcess,SectionStats,SectionFaq,SectionCta]
```

**Execution plan:**
```
// VERBOSE — 52 tokens
// Step 1: Scanner agent should analyze the repository and find all
// files that use SectionHero component.
// Step 2: Writer agent should modify SectionHero to add description prop.
// Step 3: Writer agent should update all usages with the new prop.
// Step 4: Verifier agent should check imports, types, and i18n compliance.

// MXF — 24 tokens
PLAN:add-prop/SectionHero.description
  1:SCAN ->usages[SectionHero] ->affected[]
  2:WRITE #SectionHero +prop(description?:str)
  3:WRITE affected[] +usage(description)
  4:VERIFY imports+types+i18n
```

**Convention profile:**
```
// VERBOSE — 48 tokens
// This project uses Nuxt 4 with TypeScript strict mode.
// All visible strings must be internationalized via @nuxtjs/i18n.
// Components auto-imported from app/components, pathPrefix false.
// Styling: Tailwind CSS only, no inline styles allowed.

// MXF — 18 tokens
@nuxt4 @ts-strict
i18n[@nuxtjs/i18n it,en] ->locales/*.ts REQUIRED
components:auto ~/components no-prefix
style:tailwind-only NO-inline
```

**Inter-agent message:**
```
// MSG from MainAgent to WriterAgent
MSG main->writer taskAssignment #a1b2
  PLAN:add-prop/SectionHero.description
    WRITE #sections/SectionHero.vue +prop(description?:str)
    conv[@ts-strict i18n:REQUIRED tailwind-only]
    out:swift code-only no-explanation
```

### Token savings summary

```
Format          Internal overhead (typical task, 5 agents)
────────────────────────────────────────────────────────
Verbose prose   ~800 tokens
MXF             ~150 tokens
Savings         81% reduction in internal token usage
```

### MXF component implementation

```swift
// MXFSchema.swift — formal type definitions
enum MXFNodeType {
  case file, symbol, props, plan, convention, impact, message
}

struct MXFNode {
  let type: MXFNodeType
  let identifier: String
  let attributes: [String: String]
  let children: [MXFNode]
  let relationships: [MXFRelationship]
}

struct MXFRelationship {
  let operator: MXFOperator   // ->, <-, ~>, =>, ::
  let target: String
  let cardinality: MXFCardinality
}

// MXFEncoder.swift
struct MXFEncoder {
  static func encode(_ dependency: FileDependency) -> String
  static func encode(_ component: ComponentInterface) -> String
  static func encode(_ plan: ExecutionPlan) -> String
  static func encode(_ conventions: ConventionProfile) -> String
  static func encode(_ message: AgentMessage) -> String
}

// MXFDecoder.swift
struct MXFDecoder {
  static func decode(_ mxf: String) throws -> MXFNode
  static func decodeFileDependency(_ mxf: String) throws -> FileDependency
  static func decodeComponentInterface(_ mxf: String) throws -> ComponentInterface
  static func decodeExecutionPlan(_ mxf: String) throws -> ExecutionPlan
  static func decodeAgentMessage(_ mxf: String) throws -> AgentMessage
}

// MXFValidator.swift
struct MXFValidator {
  static func validate(_ mxf: String) -> ValidationResult
  static func validateMessage(_ message: AgentMessage) -> ValidationResult
}

// MXFTokenCounter.swift
struct MXFTokenCounter {
  // Estimate token count before dispatching to model
  static func count(_ mxf: String) -> Int
  static func count(_ messages: [AgentMessage]) -> Int
  static func exceedsLimit(_ mxf: String, limit: Int) -> Bool
}
```

---

## Multi-Agent System

### How it works

Agents do not run in parallel on the model — the model is shared and
agents use it sequentially. Parallelism is only for non-model operations:
scanning, parsing, syntax verification.

```
USER → Main Agent → [Pre-flight] → [Decompose] → AgentFactory
                                                       │
                                            creates sub-agents
                                            based on task scope
                                                       │
                    ┌──────────────────────────────────┤
                    │                                  │
              (parallel)                        (sequential
              no model needed                   on shared model)
                    │                                  │
              ScannerAgent                       WriterAgent
              VerifierAgent (syntax)             ArchitectAgent
                    │                            I18nAgent
                    └──────────────────────────────────┘
                                       │
                               ResultAggregator
                                       │
                              Main Agent → USER
                         (natural language diff + approval)
```

### BaseAgent protocol

```swift
protocol BaseAgent {
  var id: AgentID { get }
  var type: AgentType { get }
  var modelClient: ModelClient { get }
  var messageBus: MessageBus { get }

  // Receives one atomic task with complete context in MXF
  func execute(task: AtomicTask) async throws -> AgentResult

  // Requests context from other agents via MXF message
  func requestContext(_ request: ContextRequest) async throws -> ContextResponse

  // Reports progress to Main Agent via MXF message
  func reportProgress(_ update: ProgressUpdate)
}
```

### AgentMessage structure

```swift
struct AgentMessage {
  let id: UUID
  let from: AgentID
  let to: AgentID             // specific or .broadcast
  let type: MessageType
  let payload: String         // always MXF-encoded
  let timestamp: Date
  let correlationID: UUID?    // tracks multi-step conversations
}

enum MessageType {
  case taskAssignment         // Main → SubAgent: execute this
  case contextRequest         // SubAgent → Scanner: need X
  case contextResponse        // Scanner → SubAgent: here is X
  case progressUpdate         // SubAgent → Main: doing Y
  case resultReady            // SubAgent → Main: output ready
  case blockingQuestion       // SubAgent → User: need clarification
  case conventionViolation    // SubAgent → Main: violation found
  case error                  // any → Main: something failed
}
```

### AgentFactory — automatic creation logic

```swift
// Complex task: "add push notification system"
// AgentFactory automatically creates:
[ScannerAgent, ArchitectAgent, I18nAgent, WriterAgent, TestAgent, VerifierAgent]

// Simple task: "rename formatDate to formatDateLocalized"
// AgentFactory automatically creates:
[ScannerAgent, WriterAgent, VerifierAgent]

// Refactor task: "reorganize repo structure"
// AgentFactory automatically creates:
[ScannerAgent, ArchitectAgent, WriterAgent, VerifierAgent]
```

### AgentPool — Apple Silicon RAM management

```swift
class AgentPool {
  // One model loaded at a time — never duplicate
  var activeModelClient: ModelClient

  // RAM threshold — never exceed 75% of available unified memory
  var memoryThreshold: Double = 0.75

  // Agents waiting if RAM is insufficient
  var pendingQueue: [BaseAgent]

  // Auto-unload model after idle period
  var idleTimeoutSeconds: Int = 300
}
```

---

## PromptEngine — surgical prompt construction

The model always receives the minimum necessary context, encoded in MXF:

```
[SYSTEM — ~30 tokens]
Code generator. Output ONLY valid [language]. No explanations.
No markdown. No comments unless requested.
[MXF convention profile — ~18 tokens]

[CONTEXT — max 300 tokens]
[MXF representation of relevant symbols only]
[Never full files — only relevant signatures and dependencies]

[TASK — max 50 tokens]
[MXF atomic task with explicit output contract]
[Explicit stop condition]

[OUTPUT CONTRACT — max 20 tokens]
[Expected type, structure, constraints]
```

**Model parameters:**
- `temperature: 0.1` — deterministic tasks (refactoring, rename)
- `temperature: 0.3` — generative tasks (new components)
- `max_tokens` — always explicit, calibrated to task
- Never send the full execution plan — only the current step

---

## Pre-Flight System — 5 mandatory checks

Executed sequentially before any executor agent runs:

```
CHECK 1 — Ambiguity Guard
  Task has missing required parameters?
  → Block. Ask user before proceeding.
  Ex: "add hero" without text content
  → "Component requires title, subtitle, ctaLabel. What values should I use?"

CHECK 2 — I18n Guard
  Task generates visible strings in an i18n project?
  → Block. "This project uses i18n (it/en).
             Strings must go in locales/. Which key should I use?"

CHECK 3 — Duplication Guard
  Does something similar already exist in the repo?
  → Inform before proceeding.
  "Found formatDateString in utils/date.ts.
   Do you want to extend it or create something separate?"

CHECK 4 — Breaking Change Guard
  Task modifies an interface used by other files?
  → Inform. "This change impacts 4 files.
              I will update all of them in the same operation."

CHECK 5 — Scope Guard
  Task too large to be atomic?
  → Decompose and ask for plan confirmation.
  "I identified 6 steps. Should I proceed in this order? [list]"
```

---

## Convention Profiler — supported languages and frameworks

### TypeScript / JavaScript
- ES module imports: `import { X } from 'Y'`
- Path aliases: `@/`, `~/`, `~~/`, `@@/`
- Barrel files: `index.ts`
- Naming: camelCase functions, PascalCase classes/components

### Vue / Nuxt
- Component auto-import from `/components/**`
- Composable auto-import from `/composables/**`
- Vue globals: `ref`, `computed`, `watch`, `onMounted`, `nextTick`, etc.
- Nuxt globals: `useNuxtApp`, `useRoute`, `useHead`, etc.
- SFC structure: `<script setup lang="ts">`, `<template>`, `<style>`
- Props via `defineProps<{}>()` with TypeScript generics
- i18n via `useI18n()` — hardcoded strings are a convention violation

### React / Next.js
- Explicit imports always required
- File-based routing: `/app` (App Router) or `/pages`
- Server vs Client components: `'use client'` directive
- Hook convention: `use` prefix required

### Python
- Absolute and relative imports: `from . import X`
- `__init__.py` as barrel file
- FastAPI: `@router.get()` decorators
- Type hints required in all new files

### Swift
- `import Framework` for dependencies
- `Package.swift` as dependency manifest
- SwiftUI: `View` protocol, `@State`, `@Binding`, `@ObservableObject`

---

## Snapshot and Rollback

```swift
struct ProjectSnapshot {
  let id: String              // "snap_20240115_143022"
  let timestamp: Date
  let files: [FileSnapshot]   // SHA hash of each modified file
  let agentPlan: ExecutionPlan
  let mxfLog: [String]        // full MXF communication log
}
```

- Automatic snapshot before every ExecutionPlan
- Rollback available for up to 10 previous snapshots
- Atomic rollback — either all files revert, or none
- Full MXF log of every agent decision preserved

---

## Authorized Dependencies

### Phase 1 (current) — Zero external dependencies
Swift stdlib and Foundation only. Regex-based parsers.

### Phase 2 (planned)
```swift
// Package.swift
.package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.8.0")
```
Grammars: typescript, javascript, python, swift, vue

### Phase 3 (planned)
Swift LSP client for tsserver, pylsp, sourcekit-lsp.

---

## Current Project Status

```
✅ COMPLETED
   vllm-mlx runtime on M4 Max (Qwen2.5-Coder-7B-Instruct-4bit)
   Surgical prompt proof of concept validated empirically
   Dependency resolver prototyped and tested on real Nuxt project (0 unresolved)
   Domain mnemox.dev registered
   MXF protocol designed and specified

⬜ PHASE 1 — Core Intelligence
   [ ] Swift Package structure
   [ ] MXF component (Encoder, Decoder, Validator, TokenCounter)
   [ ] UniversalParser TypeScript/Vue
   [ ] ProjectScanner
   [ ] DependencyGraph
   [ ] ConventionProfiler
   [ ] PreFlightSystem — 5 checks

⬜ PHASE 2 — Orchestrator
   [ ] MainAgent
   [ ] AgentFactory with auto-creation
   [ ] MessageBus (MXF-native)
   [ ] AgentPool with RAM management
   [ ] ResultAggregator
   [ ] Base agents: Scanner, Writer, Verifier

⬜ PHASE 3 — SwiftUI
   [ ] App shell
   [ ] ProjectSidebar multi-repo
   [ ] ConversationPanel
   [ ] DiffView + approval flow
   [ ] AgentStatusBar real-time

⬜ PHASE 4 — Advanced
   [ ] Auto-generated vertical agents
   [ ] Tree-sitter integration
   [ ] LSP client
   [ ] 3B router model
   [ ] Plugin system for custom frameworks
```

---

## Manifesto

> *"Your code never leaves your machine."*

> *"A well-orchestrated 7B beats a poorly-orchestrated 70B."*

> *"Mnemox remembers everything about your project. You focus on the goal."*

> *"We harness the full native power of macOS."*

---

*Mnemox — Local. Native. Yours.*