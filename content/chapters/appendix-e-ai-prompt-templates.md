---
title: "Appendix E: AI Prompt Templates"
chapter_number: "E"
part: "Appendices"
author: "Abhishek Parolkar"
---

> **Work in Progress** — This appendix is not yet published.

# Appendix E: AI Prompt Templates

The prompts in this appendix have been tested against current LLMs (GPT-4o, Claude 3.5 Sonnet, Gemini 1.5 Pro) to produce useful FOSM lifecycle specifications, AGENTS.md files, and supporting code. They are starting points, not finished products — every AI output requires human review for domain accuracy, guard completeness, and side-effect correctness.

The core insight: an LLM given a well-structured FOSM prompt will produce a lifecycle specification faster and more completely than a human writing from scratch. Your job after the AI runs is to validate, refine, and fill in the domain knowledge the AI does not have.

---

## The General FOSM Lifecycle Design Prompt

Use this prompt as your baseline whenever you are designing a new FOSM model from scratch.

### Prompt

```
You are an expert in Finite Object State Machine (FOSM) design. FOSM models business objects
as state machines where every state change is explicit, auditable, and actor-typed.

Design a FOSM lifecycle for: [BUSINESS OBJECT NAME AND DESCRIPTION]

Your output must be a Ruby lifecycle block following this DSL structure:

  lifecycle do
    process_doc "[One paragraph describing what this object represents and its purpose]"

    state :[state_name], initial: true, label: "[Human label]", color: "[hex color]",
      doc: "[One sentence describing what this state means]"
    state :[state_name], label: "[Human label]", color: "[hex color]",
      doc: "[One sentence]"
    state :[state_name], terminal: true, label: "[Human label]", color: "[hex color]",
      doc: "[One sentence]"

    event :[event_name] do
      transition from: :[from_state], to: :[to_state], actors: [:[human|ai|system]]
      guard :[guard_method_name]
      side_effect :[side_effect_method_name]
      doc "[One sentence describing what this event represents in business terms]"
    end
  end

Requirements:
1. Include ALL possible states, including multiple terminal states for different outcomes
2. Name events as imperative verbs from the business domain (submit, approve, reject, not update_status)
3. Name states as adjectives or past participles (draft, submitted, approved, not status_submitted)
4. Include at least one guard per event where a business rule applies
5. Include side effects for events that trigger downstream actions
6. Use actor types: :human (explicit human decision), :ai (automated AI action), :system (background job)
7. Add process_doc and doc: for every state and event
8. Suggest appropriate hex colors: grey for draft/initial, blue for in-progress, green for positive
   terminal, red for negative terminal, yellow/amber for warning states
9. After the lifecycle block, list the guard methods with their signatures and a one-line description
10. After the guards, list the side_effect methods with their signatures and a one-line description

Business object: [DESCRIBE THE OBJECT AND ITS BUSINESS CONTEXT]
```

### Notes on What to Validate

After receiving AI output:

1. **State completeness** — Does the AI cover all the ways this process can end? Most processes have at least two terminal states (success and failure/cancellation). Complex processes have three or more.

2. **Guard accuracy** — AI-generated guards are syntactically correct but semantically generic. Replace placeholder names like `sufficient_budget?` with the actual method you intend to implement.

3. **Actor assignment** — Verify that `:ai` actors are assigned only to transitions where you are genuinely comfortable with automated execution. When in doubt, require `:human`.

4. **Side-effect order** — The AI lists side-effects but does not sequence them. Consider whether any side-effects have dependencies (e.g., you must create a PDF before you can email it).

5. **Missing events** — AI tends to omit administrative events like `cancel`, `archive`, and `reopen`. Add them explicitly.

---

## Domain-Specific Prompts

### HR Domain

#### Employee Onboarding Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for EmployeeOnboarding. This object tracks the onboarding process
for a new hire from the moment their hire date is confirmed until they have completed all
required orientation activities and are fully productive.

Key business context:
- HR owns the process; the hiring manager co-owns specific steps
- IT must provision equipment and accounts; this can be a system-triggered action
- Compliance training must be completed before the employee is marked fully onboarded
- Onboarding can be cancelled if the offer is rescinded or the employee does not start

Include states for: documents pending, equipment pending, training in progress, and complete.
Include a reopen path for compliance remediation.

Output: Ruby lifecycle do...end block with full process documentation.
```

**Sample AI Output:**

```ruby
lifecycle do
  process_doc "Manages the full onboarding journey for a new hire, from offer acceptance
  through completion of all compliance, equipment, and administrative requirements."

  state :initiated, initial: true, label: "Initiated", color: "#94A3B8",
    doc: "Onboarding record created upon confirmed start date; awaiting document collection."

  state :documents_pending, label: "Documents Pending", color: "#F59E0B",
    doc: "Employee has been prompted to submit required documents (ID, tax forms, contracts)."

  state :equipment_pending, label: "Equipment Pending", color: "#3B82F6",
    doc: "Documents received; IT is provisioning hardware and software access."

  state :training_in_progress, label: "Training In Progress", color: "#6366F1",
    doc: "Equipment ready; employee is completing mandatory orientation and compliance training."

  state :complete, terminal: true, label: "Complete", color: "#10B981",
    doc: "All onboarding requirements fulfilled; employee is fully productive."

  state :cancelled, terminal: true, label: "Cancelled", color: "#EF4444",
    doc: "Onboarding cancelled due to rescinded offer or no-show."

  state :remediation, label: "Compliance Remediation", color: "#F97316",
    doc: "Employee must redo one or more compliance training modules."

  event :request_documents do
    transition from: :initiated, to: :documents_pending, actors: [:human, :system]
    doc "HR triggers document collection; employee receives onboarding portal invitation."
  end

  event :confirm_documents do
    transition from: :documents_pending, to: :equipment_pending, actors: [:human, :ai]
    guard :all_required_documents_received?
    side_effect :notify_it_for_provisioning
    doc "HR confirms all required documents are present and valid."
  end

  event :confirm_equipment_ready do
    transition from: :equipment_pending, to: :training_in_progress, actors: [:human, :system]
    guard :all_accounts_provisioned?
    side_effect :assign_training_modules
    doc "IT confirms hardware delivered and all system accounts are active."
  end

  event :complete_onboarding do
    transition from: :training_in_progress, to: :complete, actors: [:human, :system]
    guard :all_training_modules_passed?
    side_effect :notify_hiring_manager
    side_effect :activate_payroll_record
    doc "All training modules passed; employee is marked fully onboarded."
  end

  event :flag_remediation do
    transition from: :training_in_progress, to: :remediation, actors: [:system]
    doc "A compliance training module has been failed; employee must retake."
  end

  event :resubmit_training do
    transition from: :remediation, to: :training_in_progress, actors: [:human, :system]
    side_effect :reassign_failed_modules
    doc "Employee has been re-enrolled in the failed modules."
  end

  event :cancel do
    transition from: :initiated,         to: :cancelled, actors: [:human]
    transition from: :documents_pending, to: :cancelled, actors: [:human]
    transition from: :equipment_pending, to: :cancelled, actors: [:human]
    doc "Onboarding cancelled. IT access is revoked if provisioned."
    side_effect :revoke_system_access
  end
end
```

**Validation Notes:**
- Add a `training_deadline_date` column and a `:system` `expire` event if your compliance rules have hard deadlines.
- The `all_accounts_provisioned?` guard needs to integrate with your IT ticketing system — stub it initially.
- Consider whether `cancel` from `training_in_progress` should be allowed and what the workflow implications are.

---

#### Performance Review Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for PerformanceReview. Annual or mid-year performance review for an
individual employee. The process involves: self-assessment by the employee, manager assessment,
calibration by HR, and final delivery to the employee. Reviews can be disputed by the employee
after delivery. Use actor types appropriately — self-assessment is always human, calibration
may involve AI analysis of peer feedback.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Manages the annual/mid-year performance review from self-assessment through
  final delivery and optional dispute resolution."

  state :pending_self_assessment, initial: true, label: "Pending Self-Assessment",
    color: "#94A3B8", doc: "Employee has been notified to complete self-assessment."

  state :pending_manager_review, label: "Pending Manager Review",
    color: "#F59E0B", doc: "Self-assessment submitted; awaiting manager evaluation."

  state :calibration, label: "In Calibration",
    color: "#6366F1", doc: "HR is calibrating scores across peer group."

  state :pending_delivery, label: "Pending Delivery",
    color: "#3B82F6", doc: "Calibrated; manager to schedule delivery conversation."

  state :delivered, label: "Delivered", color: "#10B981",
    doc: "Review delivered to employee in 1:1 conversation."

  state :disputed, label: "Disputed", color: "#F97316",
    doc: "Employee has formally disputed the rating."

  state :finalised, terminal: true, label: "Finalised", color: "#10B981",
    doc: "Review process complete; rating is final."

  event :submit_self_assessment do
    transition from: :pending_self_assessment, to: :pending_manager_review, actors: [:human]
    guard :self_assessment_complete?
    doc "Employee submits completed self-assessment form."
  end

  event :submit_manager_review do
    transition from: :pending_manager_review, to: :calibration, actors: [:human]
    guard :manager_review_complete?
    doc "Manager submits evaluation; record enters HR calibration queue."
  end

  event :complete_calibration do
    transition from: :calibration, to: :pending_delivery, actors: [:human, :ai]
    side_effect :notify_manager_to_schedule_delivery
    doc "HR finalises calibrated rating; manager is prompted to book delivery."
  end

  event :deliver do
    transition from: :pending_delivery, to: :delivered, actors: [:human]
    guard :delivery_conversation_logged?
    doc "Manager marks delivery conversation as completed."
  end

  event :finalise do
    transition from: :delivered, to: :finalised, actors: [:human, :system]
    doc "Employee acknowledges receipt; review is finalised."
  end

  event :dispute do
    transition from: :delivered, to: :disputed, actors: [:human]
    guard :dispute_within_window?
    doc "Employee formally disputes the rating within the dispute window."
  end

  event :resolve_dispute do
    transition from: :disputed, to: :finalised, actors: [:human]
    doc "HR resolves dispute; final rating confirmed."
  end
end
```

---

#### Training Program Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for TrainingEnrollment. Tracks an individual employee's enrollment
in a specific training program. The employee enrolls, attends (or completes async modules),
is assessed, and receives a completion certificate or is marked as failed. Include withdrawal
and no-show paths.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Tracks a single employee's journey through one training program,
  from enrollment to certification or failure."

  state :enrolled,        initial: true,  label: "Enrolled",           color: "#94A3B8"
  state :in_progress,                     label: "In Progress",        color: "#3B82F6"
  state :assessment,                      label: "Under Assessment",   color: "#6366F1"
  state :certified,       terminal: true, label: "Certified",          color: "#10B981"
  state :failed,          terminal: true, label: "Failed",             color: "#EF4444"
  state :withdrawn,       terminal: true, label: "Withdrawn",          color: "#6B7280"
  state :no_show,         terminal: true, label: "No Show",            color: "#F97316"

  event :begin_training do
    transition from: :enrolled,    to: :in_progress, actors: [:human, :system]
  end

  event :submit_for_assessment do
    transition from: :in_progress, to: :assessment, actors: [:human, :system]
    guard :minimum_attendance_met?
  end

  event :certify do
    transition from: :assessment, to: :certified, actors: [:human, :system]
    guard :assessment_score_passing?
    side_effect :issue_certificate
    side_effect :update_employee_training_record
  end

  event :fail do
    transition from: :assessment, to: :failed, actors: [:human, :system]
    side_effect :notify_manager
  end

  event :withdraw do
    transition from: :enrolled,    to: :withdrawn, actors: [:human]
    transition from: :in_progress, to: :withdrawn, actors: [:human]
  end

  event :mark_no_show do
    transition from: :enrolled, to: :no_show, actors: [:system, :human]
    doc "Employee did not attend and did not withdraw in advance."
  end
end
```

---

### Finance Domain

#### Purchase Order Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for PurchaseOrder. A PO is raised by a department, reviewed by
finance, and approved (or rejected) based on budget availability. Approved POs are sent
to the vendor. Goods are received and the PO is matched to an invoice before being closed.
Include a partial receipt state for orders where goods arrive in multiple shipments.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Manages a purchase order from creation through vendor fulfillment and
  invoice matching."

  state :draft,            initial: true,  label: "Draft",            color: "#94A3B8"
  state :pending_approval,                 label: "Pending Approval", color: "#F59E0B"
  state :approved,                         label: "Approved",         color: "#3B82F6"
  state :sent_to_vendor,                   label: "Sent to Vendor",   color: "#6366F1"
  state :partially_received,               label: "Partially Received", color: "#8B5CF6"
  state :fully_received,                   label: "Fully Received",   color: "#10B981"
  state :closed,           terminal: true, label: "Closed",           color: "#10B981"
  state :rejected,         terminal: true, label: "Rejected",         color: "#EF4444"
  state :cancelled,        terminal: true, label: "Cancelled",        color: "#6B7280"

  event :submit_for_approval do
    transition from: :draft, to: :pending_approval, actors: [:human]
    guard :line_items_present?
  end

  event :approve do
    transition from: :pending_approval, to: :approved, actors: [:human]
    guard :budget_available?
    side_effect :reserve_budget
  end

  event :reject do
    transition from: :pending_approval, to: :rejected, actors: [:human]
    side_effect :notify_requester_with_reason
  end

  event :send_to_vendor do
    transition from: :approved, to: :sent_to_vendor, actors: [:human, :system]
    side_effect :email_vendor_po
  end

  event :record_partial_receipt do
    transition from: :sent_to_vendor,      to: :partially_received, actors: [:human]
    transition from: :partially_received,  to: :partially_received, actors: [:human]
    side_effect :update_received_quantity
  end

  event :record_full_receipt do
    transition from: :sent_to_vendor,     to: :fully_received, actors: [:human]
    transition from: :partially_received, to: :fully_received, actors: [:human]
    guard :all_line_items_received?
    side_effect :trigger_invoice_matching
  end

  event :close do
    transition from: :fully_received, to: :closed, actors: [:human, :system]
    guard :invoice_matched_and_paid?
  end

  event :cancel do
    transition from: :draft,            to: :cancelled, actors: [:human]
    transition from: :pending_approval, to: :cancelled, actors: [:human]
    transition from: :approved,         to: :cancelled, actors: [:human]
    side_effect :release_reserved_budget
  end
end
```

---

#### Budget Approval Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for BudgetRequest. A department head requests a budget allocation
for a specific project or quarter. Finance reviews the request, may request revisions, and
either approves or rejects it. Large requests (above a configurable threshold) require a
second approval from the CFO. Output a complete Ruby lifecycle block.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Manages departmental budget requests from submission through finance and
  executive approval."

  state :draft,              initial: true,  label: "Draft"
  state :submitted,                          label: "Submitted"
  state :under_review,                       label: "Under Review"
  state :revision_requested,                 label: "Revision Requested"
  state :approved,                           label: "Approved"
  state :pending_cfo,                        label: "Pending CFO Approval"
  state :fully_approved,     terminal: true, label: "Fully Approved"
  state :rejected,           terminal: true, label: "Rejected"

  event :submit do
    transition from: :draft, to: :submitted, actors: [:human]
    guard :justification_present?
  end

  event :begin_review do
    transition from: :submitted, to: :under_review, actors: [:human]
  end

  event :request_revision do
    transition from: :under_review, to: :revision_requested, actors: [:human]
    side_effect :notify_requester_with_feedback
  end

  event :resubmit do
    transition from: :revision_requested, to: :submitted, actors: [:human]
    guard :revision_notes_addressed?
  end

  event :approve do
    transition from: :under_review, to: :approved, actors: [:human]
    guard :within_finance_approval_limit?
    side_effect :notify_requester
  end

  event :approve do
    transition from: :under_review, to: :pending_cfo, actors: [:human]
    guard :exceeds_finance_approval_limit?
    side_effect :notify_cfo_for_review
  end

  event :cfo_approve do
    transition from: :pending_cfo, to: :fully_approved, actors: [:human]
    side_effect :allocate_budget
    side_effect :notify_requester
  end

  event :finalise_approval do
    transition from: :approved, to: :fully_approved, actors: [:system]
    side_effect :allocate_budget
  end

  event :reject do
    transition from: :under_review, to: :rejected, actors: [:human]
    transition from: :pending_cfo,  to: :rejected, actors: [:human]
    side_effect :notify_requester_with_reason
  end
end
```

---

### Operations Domain

#### Service Ticket Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for ServiceTicket. An internal service desk ticket raised by any
employee for IT support, facilities, or HR services. The ticket is triaged, assigned to
a specialist, worked on, and resolved. Include escalation to a senior specialist. Include
SLA breach detection via a system actor. Output a complete Ruby lifecycle block.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Manages internal service desk tickets from submission through resolution,
  with SLA monitoring and escalation support."

  state :open,        initial: true,  label: "Open",        color: "#94A3B8"
  state :triaged,                     label: "Triaged",     color: "#F59E0B"
  state :assigned,                    label: "Assigned",    color: "#3B82F6"
  state :in_progress,                 label: "In Progress", color: "#6366F1"
  state :escalated,                   label: "Escalated",   color: "#F97316"
  state :resolved,                    label: "Resolved",    color: "#10B981"
  state :closed,      terminal: true, label: "Closed",      color: "#10B981"
  state :cancelled,   terminal: true, label: "Cancelled",   color: "#6B7280"

  event :triage do
    transition from: :open, to: :triaged, actors: [:human, :ai]
    side_effect :set_priority_and_sla
  end

  event :assign do
    transition from: :triaged, to: :assigned, actors: [:human, :ai]
    side_effect :notify_assignee
  end

  event :begin_work do
    transition from: :assigned, to: :in_progress, actors: [:human]
  end

  event :escalate do
    transition from: :in_progress, to: :escalated, actors: [:human, :system]
    side_effect :notify_senior_specialist
    side_effect :notify_requester_of_escalation
  end

  event :resolve do
    transition from: :in_progress, to: :resolved, actors: [:human]
    transition from: :escalated,   to: :resolved, actors: [:human]
    guard :resolution_description_present?
    side_effect :notify_requester
  end

  event :close do
    transition from: :resolved, to: :closed, actors: [:human, :system]
    side_effect :send_satisfaction_survey
  end

  event :reopen do
    transition from: :resolved, to: :triaged, actors: [:human, :system]
    doc "Requester confirms issue not resolved; ticket re-enters the queue."
  end

  event :cancel do
    transition from: :open,    to: :cancelled, actors: [:human]
    transition from: :triaged, to: :cancelled, actors: [:human]
  end
end
```

---

#### Asset Management Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for AssetAssignment. Tracks the assignment of a physical or
digital asset (laptop, software license, vehicle) to an employee. The asset is requested,
approved, issued, and eventually returned. Include a lost/damaged terminal state.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Tracks asset assignment from request through issuance and return,
  with loss and damage handling."

  state :requested,   initial: true,  label: "Requested"
  state :approved,                    label: "Approved"
  state :issued,                      label: "Issued"
  state :overdue,                     label: "Overdue for Return"
  state :returned,    terminal: true, label: "Returned"
  state :lost,        terminal: true, label: "Lost"
  state :damaged,     terminal: true, label: "Damaged"
  state :rejected,    terminal: true, label: "Rejected"

  event :approve do
    transition from: :requested, to: :approved, actors: [:human]
    guard :asset_available?
  end

  event :reject do
    transition from: :requested, to: :rejected, actors: [:human]
  end

  event :issue do
    transition from: :approved, to: :issued, actors: [:human]
    side_effect :update_asset_inventory
    side_effect :set_expected_return_date
  end

  event :flag_overdue do
    transition from: :issued, to: :overdue, actors: [:system]
    side_effect :notify_employee_and_manager
  end

  event :return do
    transition from: :issued,   to: :returned, actors: [:human]
    transition from: :overdue,  to: :returned, actors: [:human]
    side_effect :update_asset_inventory
  end

  event :report_lost do
    transition from: :issued,  to: :lost, actors: [:human]
    transition from: :overdue, to: :lost, actors: [:human]
    side_effect :create_incident_report
  end

  event :report_damaged do
    transition from: :issued,    to: :damaged, actors: [:human]
    transition from: :returned,  to: :damaged, actors: [:human]
    side_effect :create_incident_report
  end
end
```

---

### CRM Domain

#### Customer Onboarding Lifecycle

**Prompt:**

```
Design a FOSM lifecycle for CustomerOnboarding. Triggered when a deal is won. Tracks the
process of getting a new customer live on the product: kickoff call scheduled, kickoff
completed, data migration, configuration, training, and go-live. Include a churn-risk path
if the customer goes silent during onboarding.
```

**Sample AI Output (abbreviated):**

```ruby
lifecycle do
  process_doc "Guides a new customer from deal-won through product go-live,
  with churn-risk detection for at-risk onboardings."

  state :initiated,          initial: true,  label: "Initiated"
  state :kickoff_scheduled,                  label: "Kickoff Scheduled"
  state :in_setup,                           label: "In Setup"
  state :training,                           label: "In Training"
  state :at_risk,                            label: "At Risk"
  state :live,               terminal: true, label: "Live"
  state :churned_in_onboard, terminal: true, label: "Churned During Onboarding"

  event :schedule_kickoff do
    transition from: :initiated, to: :kickoff_scheduled, actors: [:human, :ai]
    side_effect :send_calendar_invite
  end

  event :complete_kickoff do
    transition from: :kickoff_scheduled, to: :in_setup, actors: [:human]
    side_effect :create_project_plan
  end

  event :begin_training do
    transition from: :in_setup, to: :training, actors: [:human, :system]
    guard :configuration_complete?
  end

  event :go_live do
    transition from: :training, to: :live, actors: [:human]
    guard :training_sign_off_received?
    side_effect :notify_account_manager
    side_effect :trigger_first_invoice
  end

  event :flag_at_risk do
    transition from: :kickoff_scheduled, to: :at_risk, actors: [:human, :system]
    transition from: :in_setup,          to: :at_risk, actors: [:human, :system]
    transition from: :training,          to: :at_risk, actors: [:human, :system]
    side_effect :notify_customer_success_manager
  end

  event :recover do
    transition from: :at_risk, to: :in_setup, actors: [:human]
    doc "Customer re-engages; onboarding resumes from setup stage."
  end

  event :mark_churned do
    transition from: :at_risk, to: :churned_in_onboard, actors: [:human]
    side_effect :trigger_cancellation_workflow
  end
end
```

---

## Meta-Prompts

### AGENTS.md Generation Prompt

Use this to generate an `AGENTS.md` file for any Rails application that follows the FOSM pattern. `AGENTS.md` is the document that tells an AI coding assistant how the codebase is structured.

**Prompt:**

```
Write an AGENTS.md file for a Rails 8.1 application that uses the Finite Object State Machine
(FOSM) pattern. The application is called [APP NAME] and includes the following FOSM models:
[LIST MODELS].

The AGENTS.md should cover:

1. Project overview — what the app does and who uses it
2. Architecture overview — Rails 8.1 with SQLite3, Vite, Hotwire, Solid Queue
3. FOSM pattern explanation — how lifecycle blocks work, what FosmDefinition is,
   how the Transition Service works (the 5-step pipeline)
4. The three actor types (:human, :ai, :system) and when each is used
5. The fosm_transitions table structure and why it is append-only
6. File layout conventions — where models, concerns, policies, and services live
7. How to add a new event to an existing lifecycle
8. How to add a new FOSM model from scratch
9. Testing conventions — what to test, how to set up guard and side-effect stubs
10. A model-by-model reference listing each model's states and events

Format as a well-structured Markdown document with code examples. Be specific and opinionated
about conventions — do not leave things ambiguous. This document will be read by AI coding
assistants and junior developers alike.
```

---

### Process Documentation Prompt

Use this to add inline process documentation to an existing lifecycle block that was written without it.

**Prompt:**

```
The following is a Ruby FOSM lifecycle block without process documentation:

[PASTE LIFECYCLE BLOCK]

Add process_doc, doc: keywords (on states), and doc blocks (inside events) throughout this
lifecycle. Follow these rules:

- process_doc: One paragraph summarizing the lifecycle's purpose and the business object it
  governs. Write it as if explaining to a new employee why this process exists.

- doc: on states: One sentence describing what it means for a record to be in this state.
  Write from the perspective of someone looking at a list of records — what does this status
  tell them?

- doc inside events: One sentence describing what business action this event represents and
  who typically triggers it. Include any important consequences.

Output the complete lifecycle block with all documentation added. Do not change any existing
declarations.
```

---

### QueryService and QueryTool Generation Prompt

Use this to generate the bot integration triple for an existing FOSM model.

**Prompt:**

```
Generate a QueryService and QueryTool pair for the following FOSM model in a Rails
application. The QueryService should expose: find(id), list(filters), available_transitions(
record, actor), and process_documentation. The QueryTool should expose these as JSON
schema-compatible tool definitions for OpenAI function calling.

Model name: [MODEL NAME]
States: [LIST STATES]
Events: [LIST EVENTS]
Actor types in use: [human, ai, system or subset]

Also generate the ToolExecutor routing entry for this model, showing how to add it to the
main ToolExecutor class.

Follow these conventions:
- QueryService is a plain Ruby class in app/services/[model_name]_query_service.rb
- QueryTool is in app/tools/[model_name]_query_tool.rb
- Method names match the event names in the lifecycle
- The ToolExecutor authenticates the actor as type :ai before delegating

Include error handling for: record not found, transition not available, guard failures.
Output complete Ruby files for each class.
```

---

### Lifecycle Review and Gap Analysis Prompt

Use this after you have drafted a lifecycle to catch missing states, events, and guard cases before implementation.

**Prompt:**

```
Review the following FOSM lifecycle block for a [BUSINESS OBJECT] and identify:

1. Missing terminal states — are there all realistic ways this process can end?
2. Missing events — are there administrative actions (cancel, archive, reopen, expire)
   that should be included?
3. Guards without implementations — are all guard method names defined somewhere?
4. Side effects without error handling — which side effects are critical path vs.
   acceptable-to-fail?
5. Actor assignment gaps — are there transitions where you have not considered whether
   AI should or should not be permitted?
6. States with no outgoing transitions — every non-terminal state should have at least
   one event that can leave it
7. States reachable only from one source — verify these are correct and not a sign of
   a missing transition

For each finding, state: what is missing, why it matters, and a suggested fix.

Lifecycle block:
[PASTE LIFECYCLE BLOCK]
```

---

## Tips for Working With AI-Generated Lifecycles

**Start with the terminal states.** Ask yourself: what are all the ways this process can end? Positive outcomes, negative outcomes, and abandonment. Define those first. The AI will fill in the middle.

**Use the gap analysis prompt before implementing.** Run the review prompt on every AI-generated lifecycle before writing a single line of implementation code. It catches structural issues cheaply.

**Lock actor assignments early.** Resist the temptation to mark everything as `actors: [:human, :ai]`. Be conservative initially. You can always add `:ai` later; removing it after deployment is a behaviour change.

**Name things from the business domain.** If your AI output contains states like `status_1` or events like `update_record`, reject the entire output and re-run with a more specific prompt. State and event names are the API of your lifecycle; they must be domain-accurate from the start.

**The process documentation is for both humans and AI.** Write it as if a new team member will read it on day one, and as if an AI agent will read it at runtime to decide what to do. Both audiences benefit from precise, jargon-free descriptions.
