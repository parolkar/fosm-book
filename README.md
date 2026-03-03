# Finite Object State Machines: Building Business Software for the AI Age

*A hands-on guide to replacing CRUD with lifecycle-driven software using Rails 8, Hotwire, and AI*

**By [Abhishek Parolkar](https://www.parolkar.com)**

Based on the [FOSM paper](https://www.parolkar.com/fosm): *"Implementing Human+AI Collaboration Using Finite Object State Machine"*

---

## About This Book

Business software has been stuck in the CRUD paradigm for three decades. FOSM (Finite Object State Machines) replaces Create/Read/Update/Delete with lifecycle-driven business logic — where every object declares its states, events, guards, side-effects, and actors. AI makes this practical by automating the specification process that was previously the bottleneck.

This book builds a complete AI-powered business management platform — **Inloop Runway** — from `rails new` to a production-capable system with 20 FOSM lifecycle entities, conversational AI bots, role-based transition authorization, a HEY-inspired inbox, and self-documenting process docs.

## Structure

| Part | Chapters | What You Build |
|------|----------|----------------|
| **I — The Paradigm Shift** | 1–3 | Understanding why CRUD fails and how FOSM + AI changes everything |
| **II — The Foundation** | 4–7 | Rails 8 app, FOSM engine (DSL, TransitionService, audit log), first module (NDA) |
| **III — Building the Business Platform** | 8–14 | 14 business modules: Partnerships, CRM, Invoicing, Expenses, Hiring, Leave, Time Tracking, Projects, Vendors, Inventory, Knowledge Base, OKRs, Payroll, Companies |
| **IV — The FOSM Primitives** | 15–17 | Access Control (transition-level authorization), Inbox & Messaging (HEY-inspired), Process Documentation (code-as-docs + llms.txt export) |
| **V — AI Integration & Beyond** | 18–21 | Bot architecture (OpenAI Function Calling), module query tools, the full FOSM + AI circle, future vision |
| **Appendices** | A–E | Glossary, Lifecycle Reference (all 20 models), Paper Summary, Dev Setup, AI Prompt Templates |

## The 20 FOSM Lifecycle Models

| Model | States | Module |
|-------|--------|--------|
| Nda | draft → sent → partially_signed → executed / cancelled / expired | NDA Management |
| PartnershipAgreement | draft → sent → partially_signed → active → terminated / cancelled / expired | Partnerships |
| Referral | pending → qualified → accepted / rejected | Partnerships |
| Contact | lead → qualified → customer → partner / churned → archived | CRM |
| Deal | qualifying → proposal → negotiation → won / lost | CRM |
| Invoice | draft → sent → paid / overdue / cancelled | Invoicing |
| Expense | draft → reported → approved / rejected | Expenses |
| ExpenseReport | draft → submitted → approved → paid / rejected | Expenses |
| Candidate | applied → screening → interviewing → offer → hired / rejected | Hiring |
| LeaveRequest | pending → approved / rejected / cancelled | Leave Management |
| TimeEntry | logged → submitted → approved / rejected | Time Tracking |
| Project | planning → active ↔ on_hold → completed / cancelled | Projects |
| Vendor | prospect → active ↔ under_review / suspended → terminated | Vendors |
| InventoryItem | in_stock → low_stock → out_of_stock / discontinued | Inventory |
| KbArticle | draft → in_review → published / archived | Knowledge Base |
| Objective | draft → active ↔ at_risk → completed / abandoned | OKRs |
| PayRun | draft → submitted → approved → paid / voided | Payroll |
| FeedbackTicket | reported → triaged → planned → in_progress → resolved / wontfix | Feedback |
| InboxThread | open → assigned → waiting → resolved → closed | Inbox |
| Company | prospect → active → suspended → dissolved | Companies |

## Reading the Book

This is a [nanoc](https://nanoc.app/) static site. Each chapter is a standalone Markdown file with:

- **Mermaid state diagrams** for every lifecycle
- **Numbered code listings** (Listing N.N format)
- **Callout boxes**: "Why This Matters", "Under the Hood", "AI Insight"
- **Git checkpoints**: `git checkout chapter-N` for a working codebase at any point

### Build the site locally

```bash
$ gem install bundler
$ bundle install
$ bundle exec nanoc compile
$ bundle exec nanoc view
# Open http://localhost:3000
```

### Git checkpoints

Every chapter has a corresponding tag:

```bash
$ git tag -l
chapter-01
chapter-02
...
chapter-21

$ git checkout chapter-07   # Working NDA module
$ git checkout chapter-14   # All 20 FOSM models complete
$ git checkout chapter-21   # Full book
```

## LLMs.txt

The file `content/llms.txt` is the entire book concatenated into a single plain-text Markdown file (~101,000 words, 852 KB) with a system prompt header. Feed it as context to any LLM to give it full knowledge of the FOSM paradigm:

```
You are an AI coding agent that builds business software using the FOSM paradigm.
Use the following book as your complete reference...
```

This is the FOSM answer to documentation drift — one file, always current, machine-readable.

## Key Concepts

**The FOSM Contract:** Every business object declares a `lifecycle do...end` block with states, events, guards, side-effects, and actors. The transition log (`fosm_transitions` table) is the single source of truth.

**The 8-Step Module Pattern:**
1. Migration (with `status` column)
2. Model with `include Fosm::Lifecycle` and `lifecycle do...end`
3. Controller with transition actions
4. Routes with member transition routes
5. Views with state badges and transition buttons
6. Bot Tool Integration (QueryService + QueryTool + ToolExecutor)
7. Module Setting Registration (admin toggle)
8. Home Page Tile (summary card)

**The Three Primitives:**
- **Access Control** — Transition-level authorization: "Can user X trigger event Y on object Z?"
- **Inbox & Messaging** — HEY-inspired lanes with anti-burial urgency scoring
- **Process Documentation** — `process_doc` + `doc:` keywords → auto-generated llms.txt

## Reference Codebase

The companion codebase is **Inloop Runway v0.24** — a fully functional Rails 8.1 application with 127 commits, 20 FOSM models, 54 model files, 59 controllers, and 195 view templates. The `AGENTS.md` file (1,305 lines) serves as the machine-readable architecture guide.

## Technology Stack

| Component | Technology |
|-----------|------------|
| Framework | Rails 8.1 |
| Database | SQLite |
| Real-time UI | Hotwire (Turbo + Stimulus) |
| Asset Pipeline | Vite |
| CSS | Tailwind CSS |
| Authentication | Devise |
| AI | OpenAI API (Function Calling) |

## Author

**Abhishek Parolkar** — CEO of Inloop Studio. Author of the [FOSM paper](https://www.parolkar.com/fosm). Building AI-native business software.

- Web: [parolkar.com](https://www.parolkar.com)
- Twitter: [@parolkar](https://twitter.com/parolkar)

## License

This project is licensed under the **Functional Source License, Version 1.1, Apache 2.0 Future License (FSL-1.1-Apache-2.0)**. See [LICENSE](LICENSE) for the full text.

In short: you can use, modify, and redistribute for any non-competing purpose (internal use, education, research, professional services). The license automatically converts to Apache 2.0 two years after each release.

The names "FOSM", "FOSM-AWESOME" and the domain names "parolkar.com", "parolkar.github.io/com", "abhishek.parolkar.com" are the exclusive property of Abhishek Parolkar.
