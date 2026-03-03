---
title: "Coda — Where FOSM Goes Next"
chapter_number: 21
part: "Part V — AI Integration & Beyond"
summary:
  - "FOSM is language-agnostic: the pattern — lifecycle DSL, guard conditions, side effects, transition log — can be implemented in Python, Go, TypeScript, or any language with mature web tooling."
  - "Multi-tenant FOSM is the natural extension: different organizations, or different operational contexts within one organization, can run different lifecycle rules for the same object type."
  - "State machines are the compliance officer's best friend: HIPAA, SOX, and GDPR all require demonstrable process controls and audit trails that FOSM provides by construction."
  - "Rails 8 + FOSM + AI is the one-person stack: a solo developer can now build enterprise-grade software without sacrificing auditability, process integrity, or conversational intelligence."
  - "Open questions about cross-system transitions, lifecycle versioning, and distributed FOSM are the frontier — the paradigm is young and the community will shape the answers."
  - "The invitation: build something with FOSM, share what you learn, and evolve the paradigm. The paper is at https://www.parolkar.com/fosm."
---

> **Work in Progress** — This chapter is not yet published.

# Chapter 21 — Coda: Where FOSM Goes Next

Every book about software eventually faces the same problem: by the time it's finished, the landscape has moved. Languages evolve. Frameworks change. The tooling you built around is deprecated or superseded.

But paradigms outlast tools.

Object-oriented programming predates Java by two decades. Functional programming predates Haskell by four. The relational model predates SQL. The pattern — the core insight about how to organize computation — is portable across implementations. The tools are accidents of history.

FOSM is a pattern. The Ruby and Rails implementation in this book is one realization of it. But the underlying claim — that business software should model processes as explicit state machines, record every transition as an immutable event, and expose those events to both humans and AI through clean interfaces — is not tied to Ruby. It's tied to how organizations work.

This final chapter explores where FOSM goes from here.

## FOSM Beyond Rails

The paradigm translates. Here's what it looks like when you carry the idea into other languages.

**In Python with FastAPI and SQLAlchemy:**

The `transitions` library provides state machine functionality similar to AASM. The lifecycle DSL looks different — Python doesn't have Ruby's block syntax — but the structure is the same: model, states, events, guards, callbacks. FastAPI replaces Rails controllers. Alembic handles migrations. The transition log table has the same schema. The bot layer uses the same OpenAI function calling pattern with identical QueryService and QueryTool separation.

The difference is ergonomics. Rails gives you more out of the box — generators, strong parameters, Turbo Streams for real-time UI. Python gives you more deployment flexibility and a larger ML ecosystem. If your team writes Python and your organization lives in Jupyter notebooks, FOSM in Python is the right choice.

**In TypeScript with Next.js and Prisma:**

The XState library is arguably the most sophisticated state machine implementation in any language. Its visual tooling, type inference, and actor model go beyond what AASM provides. A FOSM implementation in TypeScript using XState would have stronger compile-time guarantees about lifecycle correctness — the type system catches invalid transitions at build time, not runtime.

The tradeoff is verbosity. XState machine definitions are more explicit than AASM DSL blocks. For teams comfortable with TypeScript's type system, that explicitness is a feature. For teams moving fast, it's friction.

**In Go:**

Go's structs and interfaces map cleanly to the FOSM pattern. State is a typed field. Events are methods on a service struct. Guards are predicate functions. The transition log is a straightforward append-only write to a Postgres table. Go's concurrency model is actually an advantage for the side effects layer — you can fire notifications concurrently without blocking the state transition.

What Go lacks is Rails' convention-over-configuration productivity. You'll write more boilerplate, but the resulting binary is faster, more predictable, and easier to deploy.

**The DSL changes. The paradigm doesn't.**

Whichever language you choose, the core commitments remain:

1. State is an explicit, enumerated property on the model — not inferred from a combination of flags.
2. Transitions are named business events with guards and side effects — not ad-hoc updates.
3. Every transition produces an immutable log entry — automatically, not optionally.
4. The query layer exposes structured functions to AI — not raw database access.

If your implementation satisfies these four commitments, it's FOSM regardless of what language it's written in.

## Multi-Tenant FOSM

Here's a question that doesn't come up in single-tenant software: what if different organizations need different lifecycle rules for the same object type?

A law firm's NDA lifecycle looks different from a startup's. The law firm might require partner-level approval before an NDA can be sent. The startup might allow any employee to send NDAs for deals under a certain value. The states are the same. The rules are different.

Multi-tenant FOSM is the natural extension of the paradigm into SaaS. Instead of hardcoding lifecycle rules in the model, you load them from a tenant-specific configuration at runtime. The state machine definition becomes data — stored in the database, scoped to the tenant, editable by tenant administrators.

This is a significant architectural change from what we've built in this book. The AASM DSL bakes the lifecycle into the class definition. Multi-tenant lifecycles require either:

**Per-tenant subclasses** — generate a subclass of the model for each tenant at runtime, with a custom lifecycle definition. Works but is memory-intensive and complex to manage.

**Data-driven state machines** — store the lifecycle definition as JSON in the database. At runtime, load the definition and evaluate guards and side effects against the tenant's rules. More flexible but requires building your own state machine evaluator.

**Configuration-layer overrides** — define a base lifecycle with sensible defaults, then allow tenants to configure specific parameters: thresholds for guard conditions, additional approvers, custom notification targets. Not as flexible as full customization, but covers 80% of real-world variation with 20% of the complexity.

The right choice depends on how much lifecycle variation your tenants actually need. Most SaaS applications should start with configuration-layer overrides and evolve toward data-driven state machines only if tenant needs genuinely require it.

The transition log remains the anchor point. Regardless of how the lifecycle is defined, every transition gets recorded. In a multi-tenant system, the log is scoped by tenant, and the records are as immutable and complete as in a single-tenant deployment. This is non-negotiable.

## FOSM and Regulatory Compliance

State machines are the compliance officer's best friend, though most compliance officers have never heard of them.

**HIPAA** requires demonstrated access controls and audit trails for Protected Health Information. A FOSM-based healthcare application has these by construction: every access to a patient record that triggers a state transition is logged with actor identity, timestamp, and action. The audit trail isn't a separate system bolted on — it's the transition log that powers the application's normal operation.

**SOX** (Sarbanes-Oxley) requires documented internal controls over financial reporting. A FOSM-based financial application where invoice approval, expense processing, and payroll runs all happen through explicit lifecycle transitions — with guards ensuring separation of duties, with transition logs providing the audit evidence — satisfies the spirit of SOX controls in a way that a CRUD application simply cannot. A CRUD application lets an administrator update a financial record directly. A FOSM application does not — the only path from `pending_approval` to `approved` runs through the `approve` event, which requires an authorized actor, passes guard conditions, and creates a log entry.

**GDPR** requires the ability to demonstrate lawful basis for data processing and to produce data subject access reports. FOSM's transition log gives you a per-subject timeline of every business event involving that data subject. A GDPR data subject access request becomes a query against the transition log filtered by `subject_id`. The answer is complete and accurate by construction.

<div class="callout callout-why">
<strong>Why "By Construction" Matters</strong>
The phrase "by construction" is doing a lot of work here. It means the compliance property is an inherent consequence of the architecture, not an added feature. You cannot build a FOSM application that lacks audit logs any more than you can build one that lacks models. The compliance properties emerge from the paradigm. Regulators are increasingly asking not just "do you have controls?" but "are your controls reliable?" A system where auditability is architectural gives a more honest answer than one where it's bolted on.
</div>

## The One-Person Stack

There is a vision in the Rails community — articulated most clearly by David Heinemeier Hansson — of software development as a craft that one person can practice at high levels of quality without being blocked by operational complexity. Rails 8 advances this vision significantly: Solid Queue, Solid Cache, Kamal 2, SQLite in production — the friction of deploying a serious web application has dropped dramatically.

FOSM is the business logic complement to that vision.

Rails 8 handles the infrastructure. FOSM handles the process enforcement. AI handles the specification and the conversational interface. Together, these three things let a solo developer build enterprise-grade software — software that enforces approval chains, maintains audit trails, handles complex multi-party workflows, and answers natural language questions about the state of the business — without a team of specialists.

This is not a hypothetical. The [FOSM paper](https://www.parolkar.com/fosm) emerged from the experience of building [Inloop Studio](https://www.parolkar.com/fosm) — a real business application handling real workflows. Every module in this book is an actual module from that application. The architecture works at the scale of a serious business application built and maintained by one person.

What this means for the industry is significant. Enterprise software has historically required enterprise teams: business analysts to define requirements, developers to implement them, QA engineers to verify them, compliance teams to audit them, technical writers to document them. FOSM collapses several of those roles into the software itself: the lifecycle IS the requirements document, the guards ARE the business rules, the transition log IS the audit evidence, and the Lifecycle Explorer IS the documentation.

A solo developer who understands FOSM can build software that previously required a team of ten.

## Open Questions

The paradigm is young. There are important questions that don't have settled answers yet. These are the frontiers.

**Cross-system transitions.** What happens when a FOSM object needs to trigger a state transition in a system you don't control? An invoice in your FOSM application is paid — which should update a QuickBooks record. A candidate is hired — which should trigger onboarding in BambooHR. The transition log records your side, but the external system has its own state. How do you handle failures? Timeouts? Eventual consistency across two state machines in different systems?

The honest answer: this is an unsolved problem. The Saga pattern from distributed systems is the closest analog. FOSM with external integrations needs a compensation mechanism — if the QuickBooks update fails after the invoice is marked paid, what's the correct remediation? This is active design territory.

**Lifecycle versioning.** Your NDA lifecycle has five states and six events in version 1.0 of your application. In version 2.0, you add a `countersigned` state. What happens to the 200 NDAs that were created under the old lifecycle? Some are already `executed` — they don't care about the new state. Some are `partially_signed` — can they transition to `countersigned`? Some are `draft` — they should follow the new lifecycle entirely.

This is the schema migration problem applied to business logic rather than data. Rails migrations handle column changes. There is no equivalent tooling for lifecycle changes. For now, the practical answer is: version your lifecycle cautiously, handle old-state objects explicitly in guards, and document the migration plan before deploying.

**Distributed FOSM across microservices.** What if the CRM and the Invoice module are in different services? A cross-module bot query already works because both services share a database. What if they don't? Maintaining the FOSM properties — consistent state, immutable log, grounded AI queries — across service boundaries requires message-based architectures, distributed tracing, and eventually-consistent state management. This is a hard problem. The monolithic application in this book sidesteps it intentionally. When you need to split, the FOSM boundaries (each module is already a coherent domain) are natural service boundaries.

**AI-initiated transitions.** Everything in this book has the AI querying data, not changing it. The bot answers questions. Humans make state transitions. But the obvious next step is: can a bot take action? "Send reminders to all clients with overdue invoices." Should the bot be able to call `send_reminder` on 12 invoices without a human confirming each one?

The answer is: yes, with explicit confirmation flows and comprehensive logging. The architecture supports it — you'd add action tools alongside query tools, with the same SAFE_METHODS allowlist discipline but now including write operations. The design challenge is the confirmation UX and the authorization model: who can authorize the bot to take action, and on what class of actions?

These questions are the next chapters of the FOSM story — chapters that haven't been written yet.

## The Invitation

If you've read this far, you've built something. Or you're about to. Either way, you're now part of a very small group of people who understand why lifecycle-oriented software is different — not just technically, but organizationally.

Build something with FOSM. It doesn't have to be a 14-module enterprise application. Start with one domain where your organization has a process that matters: a contract approval flow, a client onboarding journey, a support ticket escalation path. Pick the domain where the audit trail would genuinely be valuable. Where the guard conditions would genuinely prevent mistakes. Where the side effects would genuinely reduce manual work.

Then build it as a FOSM object. One lifecycle. Real states. Real guards. Real side effects. Real transition log.

You'll notice something almost immediately: the software forces clarity. When you write the lifecycle DSL, you have to commit to the states. You can't have a vague "in progress" state — you have to name the phases. You can't have an implicit rule that "managers can approve" — you have to write the guard. This forcing function is the value, separate from any technical properties. The act of specifying a FOSM lifecycle produces shared understanding about how a process is supposed to work.

When you've built something, share it. The [FOSM paper](https://www.parolkar.com/fosm) is a starting point for a paradigm, not a finished theory. The questions in the previous section — cross-system transitions, lifecycle versioning, distributed FOSM — need real implementations to generate real answers. Your implementation will find edge cases, design pressures, and constraints that this book didn't anticipate. Those findings are valuable.

The paradigm evolves through practice, not through speculation.

## The Beginning

I built the first version of FOSM because I needed it.

Running Inloop Studio meant managing NDAs, partnerships, projects, invoices, hiring, and a dozen other processes simultaneously. Standard project management tools treated everything as a task. CRMs treated everything as a contact. None of them understood that a signed NDA is fundamentally different from an unsigned one — not just as a data record, but as a business object with different permissions, different notifications, and different downstream effects.

So I built a state machine for each process. Then I noticed that the state machines shared infrastructure — the transition log, the guard evaluation, the side effect handling. I extracted that infrastructure into the FOSM pattern. Then I asked: what if the AI could query this? And the bot layer emerged.

What surprised me was how much the discipline of specifying lifecycles changed how I thought about the business. The act of writing "these are the states, these are the transitions, these are the rules" forced me to be precise about things I'd been vague about. The audit log revealed patterns I hadn't noticed. The bot layer answered questions I'd been answering manually every week.

The software got smarter as I got clearer about what I wanted from it.

That's the promise of FOSM: software that reflects the clarity of your thinking back at you, enforces the rules you chose to enforce, and tells the truth about what happened. In an era where AI generates code faster than any developer can review it, the bottleneck isn't implementation — it's specification and accountability.

FOSM is a specification methodology and an accountability mechanism in one. The more AI accelerates implementation, the more valuable that becomes.

The [FOSM paper](https://www.parolkar.com/fosm) lays out the theory. This book lays out one complete implementation. What comes next is yours to build.

Start.

*— Abhishek Parolkar, Singapore, 2026*
