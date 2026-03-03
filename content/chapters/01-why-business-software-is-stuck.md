---
title: "Why Business Software Is Stuck"
chapter_number: 1
part: "Part I — The Paradigm Shift"
summary:
  - "Business software has operated on the CRUD paradigm for over 30 years — Create, Read, Update, Delete — which digitized paper forms but didn't change how we model business reality."
  - "The 'status column that lies' is CRUD's original sin: a single string field that anyone can set to anything, with no enforcement of how you got there."
  - "Real business processes are state machines. Invoices don't get 'updated' — they move from draft to sent to paid. CRUD ignores this entirely."
  - "BPM tools, analytics layers, and cloud migrations all retrofitted on top of the same CRUD foundation — none of them fixed the underlying model."
  - "State machines lost to CRUD not because they were wrong, but because specifying them completely was too expensive and too hard."
  - "AI changes the equation. The historical bottleneck — specification — can now be done in minutes, not days."
---

# Chapter 1 — Why Business Software Is Stuck

You open Salesforce. You click Edit on a Contact record. You change the Status dropdown from "Lead" to "Customer." You hit Save.

Congratulations — you just performed the most common action in all of business software.

You also just violated every business rule your company has for customer qualification.

The sales rep hasn't completed a discovery call. Legal hasn't signed off on terms. Finance hasn't received a purchase order. But none of that matters, because the software let you do it anyway. The field is just a field. The value is just a string. The database didn't blink.

This isn't a Salesforce problem. This isn't even a configuration problem. This is a paradigm problem — one that has persisted, essentially unchanged, since the first enterprise software systems were built in the 1980s.

---

## The Paradigm That Ate Business Software

In the beginning, there were filing cabinets.

Business records lived in paper folders. An invoice was a physical document that moved from desk to desk: drafted by the account manager, approved by the finance director, mailed to the client, stamped when paid, filed in the cabinet. The document's physical location told you its status. Its chain of signatures told you who had touched it. The cabinet drawer told you the outcome.

Then computers arrived, and we did something perfectly reasonable: we digitized the paper.

The relational database model — formalized by Edgar Codd in 1970 and commercialized through the 1980s — gave us a way to represent business entities as rows in tables. Oracle, DB2, and later SQL Server and MySQL became the plumbing beneath every enterprise application. And the interaction model that emerged — Create, Read, Update, Delete, or CRUD — made perfect sense for what we were doing. We were replacing filing cabinets.

SAP, built on this foundation, became the canonical enterprise system. It modeled your business as a collection of *objects*: customers, vendors, purchase orders, invoices, employees. Each object had fields. The four verbs let you manipulate those fields. SAP didn't just adopt this model — it codified it. By the mid-1990s, every ERP, CRM, and HR system in the world was built the same way.

CRUD was everywhere. And it was fine — for digitizing paper.

The problem is that business software never grew past that origin.

---

## What CRUD Actually Models

Let's be precise about what CRUD models, because it's important to understand what it *doesn't* model.

CRUD models **nouns**. Objects. Things. A Customer is a row. An Invoice is a row. A Purchase Order is a row. Each row has columns. Columns have values.

CRUD gives you four **verbs** to act on those nouns: create a new row, read existing rows, update column values, delete rows.

That's it. That is the complete vocabulary of CRUD-based business software.

Notice what's missing: **transitions**. Movement. Process. The idea that an object might pass through a sequence of states, that only certain transitions are valid, that some transitions require preconditions, that transitions should be recorded — all of that is absent from the CRUD model. Completely absent.

A CRUD system doesn't know that an Invoice moves from Draft to Sent to Paid. It knows that an Invoice has a `status` column that can contain the strings `"draft"`, `"sent"`, and `"paid"`. The difference sounds minor. It is, in practice, catastrophic.

<div class="callout callout-why">
<strong>Why This Matters</strong>
When your data model is just nouns and fields, your software can't enforce business process. It can only store the outcomes of business process — or whatever humans claim the outcomes are. The status column doesn't tell you how you got there. It doesn't even tell you if you should be there.
</div>

---

## The Status Column That Lies

I want to spend a moment on the `status` column, because it is the single most widespread anti-pattern in business software. Every CRUD system has them. Most have dozens.

Imagine an `invoices` table. It has a `status` column. The valid values are: `draft`, `sent`, `viewed`, `partially_paid`, `paid`, `overdue`, `disputed`, `cancelled`.

In a CRUD system, that column is just a string. Any value can be set at any time. Let's think about what that means.

A developer can write `invoice.update(status: "paid")` and it will work. No validation fires, no event is recorded, no side-effects trigger. The invoice is now "paid" whether or not money moved.

A junior team member, trying to fix something that looks wrong in the UI, changes the status from `overdue` to `sent`. They think they're resetting it. The finance team now doesn't know it was ever overdue. The automated dunning emails stop. Cash flow suffers.

An integration script that imports invoice data from an old system sets status to `"Paid"` — capital P. Now your counts are wrong because you have two valid-looking values.

There's no record of who changed what, when, or why. The `updated_at` timestamp might tell you *when* the last update happened. It won't tell you what the status was before, or who changed it, or whether the business logic was satisfied when the change was made.

This is not a hypothetical. This happens in every CRUD system, in every company, all the time. I've walked into startups where the `leads` table has 23 distinct status values that accumulated over four years, half of them meaning roughly the same thing, none of them enforced by any rule in the code.

The status column lies because it only shows you where things *are* — never where they *were*, how they got there, or whether they were allowed to go there.

---

## How We Tried to Fix It (Without Fixing It)

The enterprise software industry didn't ignore this problem. It just kept solving the wrong version of it.

**The Analytics Layer**

By the 2000s, we had accumulated so much CRUD data that we needed data warehouses to make sense of it. ETL pipelines extracted data from operational systems and loaded it into analytical databases where BI tools could query across it.

The implicit promise: even if the CRUD data is messy, we can derive meaning through analytics.

This is true, up to a point. But analytics is a retrospective tool. It tells you what happened. It doesn't prevent bad things from happening in the first place. And when your underlying data is unreliable — when status columns lie, when transitions aren't recorded — your analytics are built on sand.

No amount of Looker dashboards fixes a model that never tracked process correctly.

**BPM Tools**

Business Process Management tools — Pega, Appian, Camunda, and their predecessors — recognized the problem more directly. Businesses run on *processes*, not just records. Let's model the process.

So BPM vendors built workflow engines that could be layered on top of existing CRUD systems. You could define a sequence: when an invoice is created, trigger this approval step, then route to this person, then move to the next stage.

The problem is that BPM was retrofitted. The underlying data model was still CRUD. The workflow engine was a separate system trying to *orchestrate* CRUD events into something that looked like process. The connection between the workflow definition and the actual data was always fragile — a webhook here, a status update there, a cron job to reconcile what the workflow thought happened versus what the database said.

BPM tools were an acknowledgment that CRUD was insufficient. They were not a solution. They were a scaffolding around a building whose foundation was never designed for what it was being asked to do.

**The Cloud Migration**

Salesforce's genius was taking CRUD and making it someone else's infrastructure problem. Easier to deploy, better UX, accessible from a browser, with an ecosystem of integrations — all genuinely valuable improvements.

But Salesforce is CRUD. Fancy, SaaS-delivered, well-supported CRUD. The Contact record is still a row. The status field is still a string. The rules your business runs on are still not in the data model.

When Salesforce launched in 2000, Marc Benioff's pitch was "No Software." The subtext was "same paradigm, less maintenance." The data model didn't evolve. The computing delivery model did.

**The Integration Tangle**

By 2015, the average mid-size company was running 80+ SaaS applications. Each one a CRUD silo. Each one storing its own version of what a "customer" or "deal" or "project" meant. Zapier and similar tools emerged to stitch these silos together: when a Deal is marked Won in Salesforce, create a Project in Asana, create an Invoice in QuickBooks, create a Customer in Stripe.

These integrations are heroic efforts to reconstruct process from CRUD events. They watch for field changes and react. They are, in essence, a distributed BPM system built out of webhooks and if-this-then-that rules.

They break constantly. They go out of sync. They create the worst kind of data integrity problem: two systems each confidently maintaining their own contradictory version of business reality.

The integration tangle is what happens when you spend 30 years papering over a paradigm problem instead of addressing it.

---

## The Stagnation Problem

Here's the number that should bother everyone who builds software for a living:

Moore's Law gave us roughly a million-fold increase in computing power between 1990 and 2020. Databases handle billions of records. Networks move terabytes per second. Smartphones have more power than the mainframes that ran the original CRUD systems.

And the modeling technique we use to represent business entities in software is structurally identical to what Oracle 6 did in 1988.

That is stagnation.

Not in the infrastructure. Not in the UX. Not in the delivery model. But in the fundamental way we represent what business software *does* — how it models the things businesses care about and the processes those things move through — nothing has changed.

This isn't controversial, by the way. If you talk to any experienced enterprise software architect, they will tell you the same thing: we are better at *running* CRUD, but we are still running CRUD. The paper by Abhishek Parolkar, ["Implementing Human+AI Collaboration Using Finite Object State Machines"](https://www.parolkar.com/fosm), makes exactly this argument: that business software stagnated for 30 years in the CRUD paradigm, digitizing paper forms rather than modeling business reality.

The cost of this stagnation is paid every day, in every company, in forms that are hard to see because they're normalized:

- Shadow spreadsheets that track "the real status" of things because the system of record can't be trusted
- Expensive compliance efforts to reconstruct audit trails from logs and email archives because the system never recorded transitions
- Integration maintenance as a full-time job category, employing thousands of developers worldwide to keep CRUD silos in sync
- Re-keying data between systems because every system has its own noun model
- Endless "configuration" projects where someone tries to wrangle a CRUD system into enforcing actual business rules

The cost is in the friction. In the meetings to discuss what the data "really means." In the consultants hired to explain why the ERP isn't doing what everyone thought it would. In the decade-long SAP implementations that routinely fail or dramatically overshoot budget.

---

## Real Business Processes Are State Machines

Here is a truth that every business person knows, even if they can't articulate it in technical terms:

Business objects don't just *have* properties. They move through *stages*. And how they move through those stages is exactly what business rules describe.

An **Invoice** doesn't just exist with a status field. It starts as a draft. Someone sends it, which moves it to Sent. The client views it — Viewed. They pay a portion — Partially Paid. They pay the remainder — Paid. Or thirty days pass and nobody pays — Overdue. Or there's a dispute — Disputed. Or we decide to cancel it — Cancelled.

Each of those transitions is a business event. Each has preconditions (you can only move an Invoice to Paid if the amount received equals the amount due). Each has consequences (moving to Paid should trigger a receipt to the client, update cash flow projections, close the associated deal). Each has an actor (a human approved it, or an automated system detected payment confirmation).

This is not a workflow. This is the *nature* of the business object. An Invoice is not a passive bag of data. It is an entity with a lifecycle.

The same is true for every meaningful object in business software:

- A **job application** moves from Applied → Phone Screen → Interview → Offer → Accepted/Rejected. You can't make an offer before an interview. You can't hire someone before they accept.
- A **vendor** moves from Prospect → Qualified → Contracted → Active → Suspended/Terminated. An Active vendor can be suspended for non-compliance; a suspended vendor can't receive new purchase orders.
- A **leave request** moves from Submitted → Manager Approved → HR Approved/Rejected → Completed. Both approvals are required. The order matters.

State machines. All of them. The business people have always known this. The CRUD model just ignores it.

<div class="callout callout-why">
<strong>The Gap</strong>
Business people think in state machines. They draw boxes and arrows on whiteboards. They say "first this, then that, unless this condition." But when they hand that whiteboard sketch to a developer, it gets translated into a CRUD form with a status dropdown. The boxes and arrows disappear. The process lives only in the heads of the people who were in the room.
</div>

---

## Why State Machines Lost to CRUD

If state machines better represent business reality, why did CRUD win?

This is the most important question in the book, because the answer reveals both the problem and the solution.

**The specification problem.**

Building a state machine requires knowing, up front, all the states your object will pass through, all the valid transitions between them, all the guards that must be satisfied before a transition is allowed, and all the side effects that a transition should trigger.

That's a lot. For a real business object — an Invoice in a consulting firm with retainers, milestones, disputes, and multiple approval levels — the complete specification might require days of whiteboard sessions, input from finance, legal, and operations, and multiple rounds of revision.

And then, six months later, the business adds a new payment structure and the state machine needs revision. Which requires another whiteboard session. Which requires gathering everyone back in the room. Which is expensive and slow.

CRUD has no such requirement. You create a table, you add fields, you build forms. If the business changes, you add a new field or a new dropdown value. It's cheap to start and cheap to change. The cost of that flexibility is paid later — in data inconsistency, in missing business logic, in the status column that lies — but those costs are invisible at the start.

**The tooling problem.**

Even if you wanted to build a state machine, the tooling was poor. Early FSM libraries were low-level. Drawing the state diagram was easy; implementing it correctly in code was not. The gap between the whiteboard and the working system was wide.

CRUD, by contrast, had world-class tooling. Rails, Django, and similar frameworks made CRUD not just possible but joyful. Scaffold a resource, get forms, validation, and persistence in minutes. The productivity advantage of CRUD tooling over state machine tooling was, for most of the 2000s and 2010s, enormous.

**The education problem.**

Computer science taught object-oriented programming with nouns and methods. It did not teach business domain modeling with state machines. The developer who graduated in 2005 knew how to build a User model with CRUD operations. They did not know how to model a business lifecycle. They weren't trained to think that way.

So the entire industry defaulted to what it knew. And the entire industry trained the next generation of developers in the same way.

CRUD won not because it was better. CRUD won because it was easier — easier to start, easier to staff, easier to teach, and easier to change (in the short term). The true costs were externalized to operations, compliance, and data quality teams who spent their careers cleaning up after a model that was never designed for what it was being asked to do.

---

## The Analogy That Makes It Click

Here's an analogy I use with every executive team I talk to.

Imagine your HR department runs on paper. When someone applies for a job, their application physically moves from inbox to desk to meeting room to offer letter. You can look at a physical folder and see exactly where it is in the process. The folder is the audit trail. The movement is the process.

Now imagine someone "digitizes" this by creating a spreadsheet with one row per applicant and a Status column. Every column value is writable by anyone with spreadsheet access.

You've lost everything. You've lost the physical location that told you where things were. You've lost the chain of custody. You've lost the process. You've replaced it with a field that stores a string that someone typed.

This is what happened to business software in the 1990s. We digitized the paper without digitizing the process. We stored the nouns but threw away the verbs — the real verbs, the ones that describe how things *move* and what rules govern that movement.

The filing cabinet knew more about business process than Salesforce does.

---

## Something Has Changed

For thirty years, the specification problem was a hard wall. Designing a complete state machine for a real business object required domain expertise, time, and the kind of careful thinking that was expensive to produce and expensive to revise.

Something has changed.

Large language models — the AI systems that power tools like Claude, GPT-4, and their successors — can reason about business domains with remarkable fluency. They know what invoices are, how hiring works, how vendor contracts flow, what compliance means. They can take a description of a business object and generate a complete state machine specification in minutes.

This is not a marginal improvement. This is a phase transition.

The specification bottleneck that kept state machines from being practical for everyday business software has been removed. Not reduced. Removed.

What we now have — for the first time in the history of business software — is a combination of:

1. A principled modeling technique (Finite Object State Machines) that matches how business processes actually work
2. An AI system that can generate complete specifications for that technique in minutes, in plain language
3. A mature development framework (Rails 8) with the tooling needed to implement those specifications efficiently

The CRUD era is not over because someone decreed it. It's over because the excuse for CRUD — that better alternatives were too expensive to specify — no longer holds.

In the chapters ahead, we'll build the alternative. But first, let's understand exactly what that alternative is.

---

## Chapter Summary

CRUD modeled the filing cabinet, not the business. Every enterprise system — SAP, Salesforce, Oracle, the 47 SaaS tools your company pays for — is built on the same 1988 data model. Status columns lie. Audit trails are reconstructed from logs. Process lives in people's heads, not in the software.

State machines were always the right model. Real business processes — invoice lifecycles, hiring pipelines, vendor contracts — are naturally expressed as objects moving through explicit states with guarded transitions. Business people have always known this. We just couldn't afford to specify state machines completely.

AI removes that bottleneck. The [FOSM paper](https://www.parolkar.com/fosm) argues that this creates a virtuous cycle: AI makes FOSM practical by automating specification, and FOSM makes AI safe by providing guardrails. That's the paradigm we're going to build.

---

*In Chapter 2, we formalize the FOSM model — its six primitives, how they relate, and how to design a complete lifecycle for any business object.*
