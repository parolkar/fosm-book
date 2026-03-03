---
title: "Appendix A: FOSM Glossary"
chapter_number: "A"
part: "Appendices"
author: "Abhishek Parolkar"
---

> **Work in Progress** — This appendix is not yet published.

# Appendix A: FOSM Glossary

This glossary defines every term you will encounter when reading, writing, or debugging FOSM-based applications. Terms are listed alphabetically. Where a term has a corresponding Ruby constant, DSL keyword, or database column, that reference is shown immediately after the definition.

---

## A

---

**Actor**

An Actor is any participant that can trigger a state transition on a FOSM object. Every transition must declare which actor types are permitted to fire it. FOSM recognises three actor types, each expressed as a Ruby symbol.

```ruby
transition :submit,
  from: :draft, to: :pending_review,
  actors: [:human, :ai]
```

The three actor types are:

- **`:human`** — A user authenticated through the application's session layer. Humans trigger transitions explicitly through UI actions (button clicks, form submissions). They are responsible for judgement calls that require context, empathy, or accountability that an automated system cannot provide.

- **`:ai`** — An LLM or AI agent operating through the application's API or an internal bot integration. AI actors are constrained to the transitions they are explicitly listed on; they cannot trigger transitions outside their declared scope, which is the fundamental safety boundary FOSM provides. An AI actor fires a transition by calling the same transition service that a human uses — there is no separate code path.

- **`:system`** — A background job, scheduled task, webhook receiver, or any automated Ruby process running inside the application itself. System actors handle time-based escalations (e.g., marking an invoice `overdue` after a payment deadline passes) and automated fan-out operations.

---

**Bounded Context**

A Bounded Context is the set of states, events, guards, and side-effects defined for a single FOSM model. It is the explicit boundary within which an AI actor (or human actor) operates. An AI agent configured to work within the `Deal` lifecycle can see only the states, transitions, and process documentation belonging to `Deal`; it has no structural visibility into, say, `Invoice` unless that context is explicitly shared. This isolation prevents capability creep and is the mechanism by which FOSM makes AI integration safe at scale. The term is borrowed from Domain-Driven Design and has the same intent: a model is meaningful only within its context, and crossing contexts requires an explicit translation layer.

---

## E

---

**Event (FOSM Event)**

An Event is a named business action that triggers a state transition. Events are declared as symbols inside the `lifecycle do...end` block. An event is not a database record — it is the *trigger* that, when processed by the Transition Service, produces a transition log entry. Events should be named as imperative verbs from the business domain (`submit`, `approve`, `reject`, `expire`), not as technical operations (`update_status`, `set_flag`).

```ruby
# Event declaration inside a lifecycle block
event :approve do
  transition from: :pending_review, to: :approved, actors: [:human]
  guard      :sufficient_budget?
  side_effect :notify_requester
end
```

A single event name can appear in multiple `transition` declarations if the same action is valid from more than one source state.

---

**EventBus**

The EventBus is the internal publish/subscribe mechanism through which FOSM side-effects and cross-lifecycle communication travel. When the Transition Service completes a transition, it publishes a message onto the EventBus containing the model name, record ID, event name, from-state, to-state, and actor identity. Subscribers — which can be other lifecycle observers, notification services, or webhook dispatchers — receive this message asynchronously. The EventBus decouples the act of transitioning from the downstream reactions to it, keeping the Transition Service synchronous and fast while allowing arbitrarily complex reactions to unfold in the background.

In a Rails application, the EventBus is typically implemented as a thin wrapper around Active Job, with each side-effect subscriber becoming a distinct job class.

---

## F

---

**FosmDefinition**

`FosmDefinition` is the Ruby module (or concern) that hosts the parsed, in-memory representation of a lifecycle after the DSL has been evaluated. It is the bridge between the declarative `lifecycle do...end` block the developer writes and the runtime objects the Transition Service interrogates. A `FosmDefinition` holds:

- The ordered list of all `State` objects
- The graph of valid `FosmTransition` mappings (from-state × event → to-state)
- The initial state declaration
- Terminal state flags
- All guard and side-effect references
- The process documentation hash

```ruby
# Accessed at runtime like:
Nda.fosm_definition.states          # => [#<State name=:draft>, ...]
Nda.fosm_definition.initial_state   # => :draft
Nda.fosm_definition.transition_for(state: :draft, event: :send_for_signature)
```

---

**FosmTransition**

A `FosmTransition` is the single object that fully describes one valid path through the lifecycle graph: a specific `(from_state, event) → to_state` triple, together with its permitted actors, guard reference, and side-effect references. It is **the single source of truth** for whether a given event is legal at any moment in time.

When the Transition Service receives a request to fire event `:approve` on a `LeaveRequest` record currently in state `:pending`, it looks up exactly one `FosmTransition` object. If no `FosmTransition` matches, the event is illegal and a descriptive error is raised before any database write occurs. If a `FosmTransition` is found, every piece of information the Transition Service needs — who may fire it, what guard to check, what side-effects to enqueue — is read from that single object.

This makes `FosmTransition` the canonical definition of behaviour: not the controller, not the model callbacks, not a sprawling service class, but the transition declaration in the lifecycle block.

```ruby
transition :approve,
  from: :pending,  to: :approved,
  actors: [:human],
  guard: :manager_is_approver?,
  side_effect: [:send_approval_email, :update_leave_balance]
```

---

## G

---

**Guard**

A Guard is a predicate — a method that returns `true` or `false` — evaluated by the Transition Service immediately before a transition is allowed to proceed. Guards enforce domain invariants that cannot be expressed as simple state checks. A guard method is defined on the model class (or a dedicated concern) and receives the record as its context.

```ruby
# In the lifecycle block:
guard :sufficient_budget?

# On the model:
def sufficient_budget?
  expense_report.total_amount <= budget_remaining
end
```

If a guard returns `false`, the Transition Service raises a `GuardFailed` exception and the transition is aborted. No state change is written, no side-effects are enqueued, and the calling code receives a clear, named error it can rescue and surface to the actor.

**`GuardFailed`** is the standard exception class raised when a guard check does not pass. It carries the guard name and the record that failed, giving callers all the information they need to render a meaningful error message. Never rescue `GuardFailed` silently — it represents a legitimate business rule violation and should be communicated to the actor.

```ruby
rescue FosmEngine::GuardFailed => e
  render json: { error: "Transition blocked: #{e.guard_name}" }, status: :unprocessable_entity
```

---

## I

---

**Initial State**

The Initial State is the state automatically assigned to a record when it is first created. Every FOSM lifecycle must declare exactly one initial state. It is not a special kind of state — it is a regular state that happens to be the entry point of the graph. Convention uses the `initial:` keyword or, equivalently, marks the first `state` declaration in the block.

```ruby
lifecycle do
  state :draft, initial: true, label: "Draft", color: "#94A3B8"
  state :submitted, label: "Submitted", color: "#3B82F6"
  # ...
end
```

Attempting to create a record without the initial state being defined is a configuration error raised at boot time, not at runtime.

---

## L

---

**Lifecycle (the `lifecycle do...end` block)**

The Lifecycle is the top-level DSL block defined inside a Rails model that contains the complete FOSM specification for that model. It is the developer's primary artifact: everything about how a business object moves through time lives here. The lifecycle block is evaluated once at class load time; the result is stored as a `FosmDefinition` on the model class.

```ruby
class LeaveRequest < ApplicationRecord
  include FosmEngine::Lifecycle

  lifecycle do
    state  :pending,  initial: true, label: "Pending",  color: "#F59E0B"
    state  :approved,               label: "Approved", color: "#10B981"
    state  :rejected, terminal: true, label: "Rejected", color: "#EF4444"
    state  :cancelled, terminal: true, label: "Cancelled", color: "#6B7280"

    event :approve do
      transition from: :pending, to: :approved, actors: [:human]
      guard :manager_is_approver?
      side_effect :notify_employee
    end

    event :reject do
      transition from: :pending, to: :rejected, actors: [:human]
    end

    event :cancel do
      transition from: :pending, to: :cancelled, actors: [:human, :system]
    end
  end
end
```

---

**Lifecycle Builder**

The Lifecycle Builder is the internal Ruby object that receives the DSL method calls inside a `lifecycle do...end` block and assembles them into a `FosmDefinition`. It is a [Builder pattern](https://refactoring.guru/design-patterns/builder) implementation: each DSL method (`state`, `event`, `transition`, `guard`, `side_effect`, `process_doc`) appends to the builder's internal data structures, and when the block closes, the builder validates the complete graph (checking for unreachable states, undefined guard methods, etc.) and freezes the resulting `FosmDefinition`. Developers rarely interact with the Lifecycle Builder directly, but understanding it clarifies why configuration errors surface at class load time rather than at runtime.

---

## M

---

**Module Setting**

A Module Setting is a per-business-module configuration value stored in the database that controls runtime behaviour of one or more lifecycle features within that module. Module Settings follow Rails' `store_accessor` pattern, allowing typed key-value pairs to be attached to a module's configuration record. For example, the Expenses module might expose a Module Setting for the approval threshold above which a second sign-off is required; this value is read by the `requires_second_approval?` guard at transition time. Module Settings are the recommended mechanism for making lifecycle behaviour configurable by administrators without code changes.

---

## P

---

**Policy (TransitionPolicy)**

A TransitionPolicy is a Pundit-style policy class that centralises authorisation logic for a FOSM model's transitions. While guards enforce domain invariants (business rules about the data itself), policies enforce access control (who is allowed to perform this action). A `TransitionPolicy` receives the current actor (user or AI agent) and the record, and exposes one method per event name. The Transition Service consults the policy before evaluating guards, so an unauthorised actor never reaches the guard layer.

```ruby
class LeaveRequestPolicy < ApplicationPolicy
  def approve?
    user.manager? && record.direct_report?(user)
  end

  def reject?
    approve?  # same authority
  end
end
```

---

**PolicyResolver**

The PolicyResolver is the service object responsible for looking up and instantiating the correct `TransitionPolicy` for a given record and actor pair. It follows Rails convention-over-configuration: a `LeaveRequest` model resolves to `LeaveRequestPolicy` by default, with an opt-in override hook for non-standard naming. The Transition Service delegates all authorisation decisions to the PolicyResolver, keeping the service itself free of policy logic.

---

**Process Documentation (`process_doc`, `doc:`, `doc` method)**

Process Documentation is structured, human-readable text embedded directly in the lifecycle block that describes what each state means and what each event does in plain language. It serves two purposes simultaneously: it keeps documentation co-located with the code that implements it (preventing drift), and it provides the text that an AI agent reads when it needs to understand a lifecycle and decide which event to trigger.

```ruby
lifecycle do
  process_doc "Manages the employee leave request from submission through manager review."

  state :pending, initial: true,
    doc: "Request submitted by employee, awaiting manager review."

  event :approve do
    transition from: :pending, to: :approved, actors: [:human]
    doc "Manager approves the request. Employee is notified and leave balance is decremented."
  end
end
```

The `process_doc` method at the top of the block sets the lifecycle-level description. The `doc:` keyword on a state declaration describes that state. The `doc` method inside an event block describes that event. All three are harvested by the `QueryService` and exposed as structured metadata through the bot integration triple.

---

**QueryService / QueryTool / ToolExecutor (the bot integration triple)**

These three classes form the standard pattern for exposing a FOSM lifecycle to an AI agent via a tool-calling interface.

- **`QueryService`** — A plain Ruby service object that wraps read access to a specific FOSM model. It exposes methods like `find(id)`, `list(filters)`, `available_transitions(record, actor)`, and `process_documentation`. These methods return structured data that an AI agent can reason about.

- **`QueryTool`** — A thin adapter that maps the `QueryService` methods to the JSON schema format expected by a specific LLM's tool-calling API (OpenAI function calling, Anthropic tool use, etc.). It handles parameter validation and type coercion, keeping the `QueryService` clean of protocol concerns.

- **`ToolExecutor`** — The class that receives raw tool-call requests from an LLM, routes them to the correct `QueryTool`, executes the call, and formats the result back into the message format the LLM expects. The `ToolExecutor` is also responsible for enforcing actor identity — every tool call is executed with an authenticated `:ai` actor context, ensuring all FOSM authorisation rules apply.

Together, these three classes implement the "AI as actor" pattern: the AI is not a special participant; it uses the same interface any actor would, just mediated through the tool-calling protocol.

---

## S

---

**Side-Effect**

A Side-Effect is any action that should happen as a consequence of a transition but is not itself a state change. Side-effects are declared by name in the lifecycle block and implemented as methods on the model or a dedicated side-effects module. The Transition Service enqueues all side-effects after the state change has been committed to the database, ensuring they do not prevent the transition from being recorded even if a downstream service is temporarily unavailable.

Canonical side-effects include: sending notification emails, updating denormalised counters, triggering webhooks, creating child records, publishing EventBus messages, and logging to external analytics systems.

```ruby
event :pay do
  transition from: :approved, to: :paid, actors: [:system]
  side_effect :transfer_funds
  side_effect :generate_payment_receipt
  side_effect :update_accounting_ledger
end
```

Side-effects should be idempotent wherever possible, since background job retry semantics may cause them to execute more than once.

---

**State**

A State is a discrete, named condition that a FOSM record can be in at any point in time. States are the nouns of the lifecycle graph; events are the verbs. Each state has a `name` (a Ruby symbol used in code), a `label` (a human-readable string for display), and a `color` (a hex string for visual rendering in dashboards and Mermaid diagrams). A state may also be flagged as `initial: true` or `terminal: true`.

```ruby
state :in_progress, label: "In Progress", color: "#3B82F6"
```

The current state of a record is stored as a string in the `aasm_state` column (or a custom-named column) on the model's database table. It is never computed — it is always persisted.

---

## T

---

**Terminal State**

A Terminal State is a state from which no further transitions are defined. Records that reach a terminal state are considered closed; their lifecycle is complete. Terminal states are declared with `terminal: true` and the Transition Service enforces this — attempting to fire any event on a record in a terminal state raises an error regardless of the event's from-state declarations. Examples: `cancelled`, `executed`, `paid`, `archived`, `hired`, `dissolved`. A lifecycle may have multiple terminal states, each representing a different outcome.

```ruby
state :cancelled, terminal: true, label: "Cancelled", color: "#EF4444"
state :executed,  terminal: true, label: "Executed",  color: "#10B981"
```

---

**Transition (the act)**

A Transition is the act of moving a record from one state to another in response to an event. In code, it is the runtime execution of one `FosmTransition` definition: the Transition Service verifies the actor, evaluates the guard, writes the log entry, updates the record's state column, and enqueues side-effects — in that order. Developers should think of a transition as an atomic business operation, not a database update. The word "transition" appears in three related but distinct contexts: the `FosmTransition` definition (the declaration), the `fosm_transitions` table row (the record), and the act of transitioning (the runtime event). Context makes the meaning clear.

---

**Transition Log (the `fosm_transitions` table)**

The Transition Log is the append-only database table — `fosm_transitions` — that records every state change that has ever occurred across all FOSM models in the application. Each row is an immutable event record containing: `record_type` (model name), `record_id`, `event` (the event name), `from_state`, `to_state`, `actor_type` (`:human`, `:ai`, `:system`), `actor_id`, `metadata` (a JSON column for guard outputs, comments, and contextual data), and `created_at`.

The Transition Log is the business record. It is not a debugging aid or a compliance afterthought — it is the primary source of truth for understanding what happened to any object over time. Aggregated state (the current `aasm_state` column) is a derived, convenience projection of the log. If the two ever disagree, the log wins.

```sql
SELECT event, from_state, to_state, actor_type, actor_id, created_at
FROM fosm_transitions
WHERE record_type = 'LeaveRequest' AND record_id = 42
ORDER BY created_at ASC;
```

---

**Transition Service (the 5-step pipeline)**

The Transition Service is the central orchestrator that executes state transitions. It is a single-purpose service object with one public method (`call(record:, event:, actor:, metadata: {})`). Internally it executes exactly five steps in sequence:

1. **Lookup** — Find the `FosmTransition` definition for the `(record.current_state, event)` pair. Raise `InvalidTransition` if none exists.
2. **Authorise** — Consult the `PolicyResolver` to confirm the actor is permitted to fire this event. Raise `Unauthorized` if not.
3. **Guard** — Evaluate the guard method on the record. Raise `GuardFailed` if it returns `false`.
4. **Persist** — Write the `fosm_transitions` row and update the record's state column in a single database transaction. Both writes succeed or both are rolled back.
5. **Enqueue** — After the transaction commits, enqueue each declared side-effect as a background job via the EventBus.

Nothing outside the Transition Service should directly update a FOSM record's state column. This discipline is what makes the Transition Log complete and trustworthy.

```ruby
TransitionService.call(
  record:   leave_request,
  event:    :approve,
  actor:    current_user,
  metadata: { comment: "Approved for Q2 budget." }
)
```
