---
title: "Process Documentation — Code as the Living Document"
chapter_number: 17
part: "Part IV — The FOSM Primitives"
summary:
  - "External wikis rot. Confluence pages drift. The only documentation that stays true is the code — so FOSM makes the code self-documenting by design."
  - "Three documentation mechanisms: process_doc at the lifecycle level, doc: inline on states/events/guards/side-effects, and standalone doc methods for long-form explanation."
  - "Documentation is stored in fosm_definitions.documentation (JSON) and fosm_definitions.process_description (text) — queryable, versionable, and diffable."
  - "Admin Process Docs hub at /admin/fosm/docs renders human-readable process pages with state diagrams for every FOSM object."
  - "GET /admin/fosm/docs.txt exports the entire process corpus as a flat llms.txt file — one source of truth for developers, business architects, and LLM agents."
  - "Git tracks documentation alongside business logic. When a guard changes, the doc changes in the same commit. Drift is structurally impossible."
---

> **Work in Progress** — This chapter is not yet published.

# Chapter 17 — Process Documentation: Code as the Living Document

There is a Confluence page somewhere in your organization that says "Invoice Approval Process — Last Updated: November 2022." Nobody has touched it since. The actual invoice approval process was changed three times since then: once when the company moved to a 3-way match, once when the CFO added a second sign-off for anything over $50,000, and once when the AP team discovered that the guard that was supposed to prevent double-payment wasn't actually being enforced.

None of those changes made it back to Confluence.

This is not a people problem. It's a structural problem. Documentation lives in a different place from the code, so it takes extra effort to keep them in sync. Under deadline pressure, "update the wiki" is always the last item on the list — and it never gets done. The documentation drifts, then becomes wrong, then becomes actively misleading, then gets ignored, then stops being maintained at all, then gets deleted in a cleanup sweep, and the process knowledge lives in someone's head until they leave.

FOSM solves this structurally, not culturally.

**The code IS the documentation.** The lifecycle block IS the specification. Every state has a name and a `doc`. Every event has a description. Every guard explains what it's checking. The lifecycle block in the model file is simultaneously the specification, the implementation, and the documentation — and there is only one of them, in one place, tracked by Git.

This chapter builds the mechanics of that system: the DSL, the storage layer, the admin Process Docs hub, and the `llms.txt` export that makes the entire process corpus queryable by LLM agents.

## The Problem With External Documentation

Let's be precise about what goes wrong with wikis and why "we'll be more disciplined about updating docs" never works.

The fundamental issue is **distance**. When documentation lives in a separate system from the code:

- Writing a guard takes 10 minutes. Opening Confluence, finding the right page, updating the process flow, and saving takes another 15 minutes. Under deadline pressure, the second step gets skipped.
- Code review catches guard logic errors. Code review does not catch Confluence drift.
- CI/CD validates that tests pass. CI/CD does not validate that the wiki matches the code.
- Git blame tells you who changed a guard and why. Git blame does not help you with the Confluence page that was never updated.

The distance creates a synchronization problem, and synchronization problems always resolve toward entropy. The code stays current because it has to — the system breaks if it's wrong. The documentation doesn't have to stay current, so it doesn't.

FOSM's answer is to eliminate the distance. Documentation goes inside the lifecycle block. The lifecycle block IS the code. Same file, same review, same commit, same Git history.

<div class="callout callout-why">
<strong>Why Not Just Write Good Comments?</strong>
Comments are better than external wikis but still have the drift problem — they're free text with no structure and no enforced relationship to the logic they describe. FOSM's <code>doc:</code> keyword is structured: it's attached to a specific state, event, guard, or side-effect. It's extracted by the documentation system, stored in the database, rendered in the admin UI, and exported to the LLM context file. A code comment can silently lie. A <code>doc:</code> attached to a guard that no longer exists raises a warning at lifecycle parse time.
</div>

## The Three Documentation Mechanisms

### Mechanism 1: process_doc

The top-level description of the entire lifecycle. One paragraph or a few sentences that explain what this process does, why it exists, and what business problem it solves.

```ruby
lifecycle do
  process_doc "Manages the full lifecycle of vendor invoices from receipt through payment. " \
              "Enforces 3-way match (PO, receipt, invoice) before approval is allowed. " \
              "Requires dual sign-off for invoices above $50,000. " \
              "Integrates with the payment run process — approved invoices queue for the next run."
  # ...
end
```

This is the equivalent of the first paragraph of a Confluence page — but it lives in the model file, it's version-controlled, and it's impossible to forget to update because the description is literally inside the method that defines the process.

### Mechanism 2: doc: Keyword

Inline documentation on individual elements. Every state, event, guard, and side-effect can carry a `doc:` value.

```ruby
lifecycle do
  state :awaiting_approval,
        doc: "Invoice has been submitted and is waiting for an approver to act. " \
             "SLA: 2 business days. Escalation triggers on day 3."

  event :approve do
    doc         "Approver has reviewed and approved the invoice for payment."
    from        :awaiting_approval
    to          :approved
    guards      [:three_way_match_verified?, :within_approval_authority?]
    side_effects [:queue_for_payment, :notify_submitter_of_approval]
  end
end
```

The `doc:` on a state explains what that state *means* — not just its name, but its business significance, any SLAs attached to it, and what actions are available from it. The `doc:` on an event explains the business semantics of triggering it.

### Mechanism 3: Standalone doc Method

For long-form explanations — process history, rationale, edge cases, exception handling — a standalone `doc` method provides a home for prose that doesn't belong on a single element:

```ruby
lifecycle do
  doc :three_way_match_policy,
      "Three-way match requires PO number, goods receipt confirmation, and invoice amount " \
      "to align within 2% tolerance before approval is permitted. This policy was implemented " \
      "in Q2 2025 after an audit found that 12% of invoices were being approved without " \
      "corresponding purchase orders, creating off-PO spend that couldn't be reconciled " \
      "against budget. Exception process: Finance Director can override with written justification."
end
```

These standalone docs are named — you can reference them from event descriptions, from guards, and from the admin UI.

## The Full Documented NDA Lifecycle

Let's go back to the NDA from Chapter 7 and show what it looks like with full documentation applied. This is the same lifecycle — same states, same events, same guards — but now every element carries its business meaning.

<p class="listing-label">Listing 17.1 — app/models/nda.rb (fully documented lifecycle)</p>

```ruby
class Nda < ApplicationRecord
  include Fosm::HasLifecycle

  belongs_to :owner,        class_name: "User"
  belongs_to :counterparty, class_name: "User"
  has_one_attached :document

  lifecycle do
    process_doc "Manages the signing lifecycle of Non-Disclosure Agreements between the " \
                "company and external parties (vendors, partners, candidates). " \
                "Enforces signing order flexibility — either party may sign first — " \
                "while ensuring both signatures are captured before execution. " \
                "Integrates with the Contact module: counterparties must be active Contacts " \
                "before an NDA can be sent. Executed NDAs are retained for 7 years per " \
                "legal hold policy."

    states :draft, :sent, :partially_signed, :executed, :expired, :cancelled

    state :draft,
          doc: "NDA has been created but not yet sent. The owner may attach a document, " \
               "edit terms, and designate the counterparty. No signatures collected."

    state :sent,
          doc: "Invitation has been sent to the counterparty. The signing window is open. " \
               "Default expiry: 30 days from send date. Either party may sign first."

    state :partially_signed,
          doc: "One of the two required signatures has been collected. The NDA cannot " \
               "be executed until both the owner and counterparty have signed. " \
               "The system tracks which signature was captured first."

    state :executed,
          doc: "Both parties have signed. The NDA is legally binding. " \
               "Execution date recorded. Document locked — no further changes permitted.",
          terminal: true

    state :expired,
          doc: "The signing window closed without both signatures being captured. " \
               "Distinct from cancellation — expiry is automatic and time-triggered. " \
               "Expired NDAs can be re-sent if the business relationship is still active.",
          terminal: true

    state :cancelled,
          doc: "Explicitly terminated by either party or by an admin. " \
               "Cancellation reason required. Preserved in audit trail indefinitely.",
          terminal: true

    # ─── Events ──────────────────────────────────────────────────────────

    event :send_invitation do
      doc         "Send the NDA to the counterparty. Sets the signing window. " \
                  "Generates a unique signing link valid for expiry_days."
      from        :draft
      to          :sent
      guards      [:document_attached?, :counterparty_is_active_contact?]
      side_effects [:set_expiry_date, :send_invitation_email, :create_audit_entry]
    end

    event :sign_by_owner do
      doc         "Owner's signature captured. Can occur before or after counterparty signs. " \
                  "Records signature timestamp and IP address."
      from        :draft, :sent, :partially_signed
      to          :partially_signed
      guards      [:not_already_signed_by_owner?]
      side_effects [:record_owner_signature]
    end

    event :sign_by_counter do
      doc         "Counterparty signature captured via signing link. " \
                  "Records signature timestamp and IP address."
      from        :sent, :partially_signed
      to          :partially_signed
      guards      [:not_already_signed_by_counter?]
      side_effects [:record_counter_signature]
    end

    event :execute do
      doc         "Both signatures confirmed — mark NDA as legally binding. " \
                  "Execution timestamp recorded. Document hash stored for tamper detection."
      from        :partially_signed
      to          :executed
      guards      [:both_parties_signed?]
      side_effects [:set_execution_date, :lock_document, :notify_both_parties, :create_audit_entry]
    end

    event :expire do
      doc         "Triggered automatically by ExpireNdasJob when current time exceeds expiry_date. " \
                  "Not a human action — do not expose this event in the UI."
      from        :sent, :partially_signed
      to          :expired
      side_effects [:send_expiry_notification]
    end

    event :cancel do
      doc         "Explicitly cancel the NDA. Cancellation reason is stored in the metadata field. " \
                  "Available to the NDA owner and to admins. Not reversible."
      from        :draft, :sent, :partially_signed
      to          :cancelled
      side_effects [:send_cancellation_notification, :create_audit_entry]
    end

    # ─── Guards ──────────────────────────────────────────────────────────

    guard :document_attached? do
      doc "NDA document must be attached before invitation can be sent. " \
          "Accepted formats: PDF only. Maximum size: 10MB."
    end

    guard :counterparty_is_active_contact? do
      doc "Counterparty must exist as an active Contact in the system. " \
          "This ensures the signing invitation reaches a verified email address."
    end

    guard :both_parties_signed? do
      doc "Both owner_signed_at and counter_signed_at must be non-null. " \
          "This is the critical execution guard — partial signatures cannot execute."
    end

    # ─── Side Effects ─────────────────────────────────────────────────────

    side_effect :set_expiry_date do
      doc "Sets expiry_date to (Time.current + expiry_days.days). " \
          "Default expiry_days: 30. Configurable per NDA."
    end

    side_effect :lock_document do
      doc "Sets document_locked: true. Prevents attachment replacement post-execution. " \
          "Also stores document_sha256 hash for tamper detection."
    end

    # ─── Long-form documentation ──────────────────────────────────────────

    doc :signing_order_policy,
        "Either party may sign first. This is intentional — requiring counterparty to sign " \
        "before the owner creates unnecessary back-and-forth. The partially_signed state " \
        "tracks which signature has been collected via owner_signed_at and counter_signed_at. " \
        "The execute event guard (both_parties_signed?) enforces that both are present."

    doc :re_send_policy,
        "Expired NDAs can be re-sent by creating a new NDA record. We do not reuse expired " \
        "NDAs because the expiry creates a clean audit break. The original expired record " \
        "is preserved. A new NDA starts from draft with a fresh signing window."
  end
end
```

This is the same code that runs the business logic. The `doc:` annotations aren't comments — they're structured data that gets extracted, stored, and rendered.

## The Storage Layer

Documentation is extracted from the lifecycle DSL and stored in the `fosm_definitions` table. We're adding two columns to the existing table:

<p class="listing-label">Listing 17.2 — db/migrate/20260302300000_add_documentation_to_fosm_definitions.rb</p>

```ruby
class AddDocumentationToFosmDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :fosm_definitions, :process_description, :text
    add_column :fosm_definitions, :documentation,       :jsonb, default: {}
  end
end
```

The `documentation` JSON structure:

```json
{
  "states": {
    "draft": "NDA has been created but not yet sent...",
    "sent":  "Invitation has been sent to the counterparty..."
  },
  "events": {
    "send_invitation": "Send the NDA to the counterparty...",
    "execute":         "Both signatures confirmed..."
  },
  "guards": {
    "document_attached?":              "NDA document must be attached...",
    "counterparty_is_active_contact?": "Counterparty must exist as..."
  },
  "side_effects": {
    "set_expiry_date": "Sets expiry_date to (Time.current + expiry_days.days)...",
    "lock_document":   "Sets document_locked: true..."
  },
  "named_docs": {
    "signing_order_policy": "Either party may sign first...",
    "re_send_policy":       "Expired NDAs can be re-sent..."
  }
}
```

The extraction happens in the lifecycle DSL parser:

<p class="listing-label">Listing 17.3 — lib/fosm/lifecycle_dsl.rb (documentation extraction)</p>

```ruby
module Fosm
  class LifecycleDsl
    # ... existing DSL parser ...

    def process_doc(text)
      @process_description = text
    end

    def doc(name, text)
      (@named_docs ||= {})[name.to_s] = text
    end

    def build_fosm_definition(model_class)
      definition = FosmDefinition.find_or_initialize_by(
        object_type: model_class.name
      )

      definition.assign_attributes(
        states:              @states.map(&:name),
        events:              serialize_events,
        process_description: @process_description,
        documentation:       build_documentation_hash
      )

      definition.save!
      definition
    end

    private

    def build_documentation_hash
      {
        states:       doc_hash_for(@states),
        events:       doc_hash_for(@events),
        guards:       doc_hash_for(collect_guards),
        side_effects: doc_hash_for(collect_side_effects),
        named_docs:   @named_docs || {}
      }
    end

    def doc_hash_for(elements)
      elements.each_with_object({}) do |el, hash|
        hash[el.name.to_s] = el.doc if el.respond_to?(:doc) && el.doc.present?
      end
    end
  end
end
```

Run the migration:

```
$ rails db:migrate
```

Reload all lifecycle definitions to extract documentation:

```
$ rails fosm:reload_definitions
```

## The Fully Documented Invoice Lifecycle

The Invoice is the most business-critical object in most deployments. Here's the full documented version:

<p class="listing-label">Listing 17.4 — app/models/invoice.rb (documented lifecycle excerpt)</p>

```ruby
class Invoice < ApplicationRecord
  include Fosm::HasLifecycle

  belongs_to :vendor
  belongs_to :submitter, class_name: "User"
  belongs_to :approver,  class_name: "User", optional: true
  has_many   :line_items, dependent: :destroy

  lifecycle do
    process_doc "Manages the full lifecycle of vendor invoices from receipt through payment. " \
                "Enforces three-way match (PO, goods receipt, invoice) before approval. " \
                "Dual sign-off required for invoices above $50,000 (configurable via " \
                "InvoicePolicy.high_value_threshold). Approved invoices are queued " \
                "automatically for the next payment run."

    state :draft,
          doc: "Invoice has been entered but not submitted. Editable. " \
               "Not yet validated against PO or goods receipt."

    state :submitted,
          doc: "Invoice submitted for approval. 3-way match validated at submission. " \
               "SLA: 2 business days for first approver action."

    state :awaiting_second_approval,
          doc: "High-value invoice (above threshold) has received first approval " \
               "and is awaiting CFO or delegate sign-off."

    state :approved,
          doc: "All required approvals received. Invoice is queued for the next payment run. " \
               "Vendor will be paid within terms (net-30 default)."

    state :rejected,
          doc: "Approval denied. Rejection reason is required and stored. " \
               "Vendor is notified. Invoice may be resubmitted after correction.",
          terminal: false

    state :paid,
          doc: "Payment processed. Transaction reference stored. " \
               "Closing entry created in GL.",
          terminal: true

    state :voided,
          doc: "Invoice cancelled — not paid, no GL entry. " \
               "Void reason required. Preserves full history.",
          terminal: true

    event :submit do
      doc         "Submit invoice for approval. Triggers 3-way match validation."
      from        :draft, :rejected
      to          :submitted
      guards      [:three_way_match_verified?, :all_line_items_present?]
      side_effects [:notify_approvers, :set_submission_date]
    end

    event :approve do
      doc         "First approver confirms invoice is correct and approved for payment. " \
                  "High-value invoices route to awaiting_second_approval instead of approved."
      from        :submitted
      to          ->(inv) { inv.requires_second_approval? ? :awaiting_second_approval : :approved }
      guards      [:within_approval_authority?]
      side_effects [:record_first_approval, :notify_on_routing]
    end

    event :second_approve do
      doc         "CFO or delegate provides second sign-off on high-value invoice."
      from        :awaiting_second_approval
      to          :approved
      guards      [:is_senior_approver?]
      side_effects [:record_second_approval, :queue_for_payment_run]
    end

    event :reject do
      doc         "Approver rejects invoice. Rejection reason stored in metadata. " \
                  "Vendor notified. Invoice returns to rejected state for correction."
      from        :submitted, :awaiting_second_approval
      to          :rejected
      side_effects [:notify_submitter_of_rejection, :notify_vendor]
    end

    event :mark_paid do
      doc         "Payment run has processed this invoice. Transaction reference stored."
      from        :approved
      to          :paid
      side_effects [:create_gl_closing_entry, :notify_vendor_of_payment]
    end

    event :void do
      doc         "Cancel invoice without payment. Void reason required in metadata."
      from        :draft, :submitted, :awaiting_second_approval, :approved, :rejected
      to          :voided
      side_effects [:reverse_any_gl_entries, :notify_affected_parties]
    end

    guard :three_way_match_verified? do
      doc "PO number must be present and match an approved PO. " \
          "Goods receipt must be confirmed. Invoice amount must be within 2% of PO amount. " \
          "Override available to Finance Director with written justification stored in metadata."
    end

    guard :within_approval_authority? do
      doc "Approver's authority limit must cover the invoice total. " \
          "Authority limits are set on User.invoice_approval_limit. " \
          "Default: $10,000. Configurable per user by HR Admin."
    end

    doc :high_value_policy,
        "Invoices above InvoicePolicy.high_value_threshold (default: $50,000) require " \
        "two approvals: first from any user with invoice approval authority, second from " \
        "a user with the :senior_approver role. The threshold is configurable without code " \
        "changes via the Admin → Invoice Policy settings page."
  end
end
```

## The Admin Process Docs Hub

The Process Docs hub renders human-readable process pages from the stored documentation. Every FOSM object in the system gets a page. No Confluence, no wiki — just `/admin/fosm/docs`.

<p class="listing-label">Listing 17.5 — app/controllers/admin/fosm/docs_controller.rb</p>

```ruby
class Admin::Fosm::DocsController < Admin::BaseController
  def index
    @definitions = FosmDefinition.all.order(:object_type)
  end

  def show
    @definition  = FosmDefinition.find_by!(object_type: params[:object_type])
    @doc         = @definition.documentation.with_indifferent_access
    @states      = @definition.states
    @events      = @definition.events
    @diagram_src = generate_mermaid(@definition)
  end

  # GET /admin/fosm/docs.txt
  def export_llms_txt
    @definitions = FosmDefinition.all.order(:object_type)
    render plain: LlmsTxtExporter.export(@definitions),
           content_type: "text/plain"
  end

  private

  def generate_mermaid(definition)
    lines = ["stateDiagram-v2"]
    lines << "    [*] --> #{definition.initial_state}"

    definition.events.each do |event|
      froms = Array(event["from"])
      to    = event["to"]
      next unless to.is_a?(String)

      froms.each do |from|
        lines << "    #{from} --> #{to} : #{event['name']}"
      end
    end

    # Terminal states
    (definition.terminal_states || []).each do |state|
      lines << "    #{state} --> [*]"
    end

    lines.join("\n")
  end
end
```

<p class="listing-label">Listing 17.6 — app/views/admin/fosm/docs/index.html.erb</p>

```erb
<div class="admin-header">
  <h1>Process Documentation</h1>
  <div class="admin-header__actions">
    <%= link_to "Export llms.txt", export_llms_txt_admin_fosm_docs_path,
                class: "btn btn-secondary",
                title: "Download all process docs as a flat text file for LLM context" %>
  </div>
</div>

<p class="admin-intro">
  This is the living documentation for every FOSM-managed process in the system.
  Documentation is generated from the model lifecycle definitions — it is always current.
</p>

<div class="docs-grid">
  <% @definitions.each do |defn| %>
    <div class="doc-card">
      <div class="doc-card__header">
        <h3><%= link_to defn.object_type, admin_fosm_doc_path(defn.object_type) %></h3>
        <span class="doc-card__meta">
          <%= defn.states.count %> states ·
          <%= defn.events.count %> events
        </span>
      </div>
      <% if defn.process_description.present? %>
        <p class="doc-card__description">
          <%= defn.process_description.truncate(200) %>
        </p>
      <% else %>
        <p class="doc-card__description doc-card__description--missing">
          No process description. Add <code>process_doc</code> to the lifecycle block.
        </p>
      <% end %>
      <div class="doc-card__coverage">
        <span title="States documented">
          States: <%= documented_count(defn, :states) %>/<%= defn.states.count %>
        </span>
        <span title="Events documented">
          Events: <%= documented_count(defn, :events) %>/<%= defn.events.count %>
        </span>
      </div>
    </div>
  <% end %>
</div>
```

<p class="listing-label">Listing 17.7 — app/views/admin/fosm/docs/show.html.erb</p>

```erb
<div class="admin-header">
  <h1><%= @definition.object_type %></h1>
  <%= link_to "← All Processes", admin_fosm_docs_path, class: "back-link" %>
</div>

<% if @definition.process_description.present? %>
  <div class="process-description">
    <p><%= @definition.process_description %></p>
  </div>
<% end %>

<div class="process-diagram">
  <h2>State Diagram</h2>
  <div class="mermaid">
    <%= @diagram_src %>
  </div>
</div>

<div class="process-docs-grid">
  <section class="doc-section">
    <h2>States</h2>
    <% @states.each do |state_name| %>
      <div class="doc-item">
        <div class="doc-item__name">
          <span class="state-badge"><%= state_name %></span>
          <% if @definition.terminal_states&.include?(state_name) %>
            <span class="badge badge-terminal">terminal</span>
          <% end %>
        </div>
        <% state_doc = @doc.dig(:states, state_name) %>
        <% if state_doc.present? %>
          <p class="doc-item__text"><%= state_doc %></p>
        <% else %>
          <p class="doc-item__text doc-item__text--missing">
            Not documented. Add <code>doc:</code> to this state.
          </p>
        <% end %>
      </div>
    <% end %>
  </section>

  <section class="doc-section">
    <h2>Events</h2>
    <% @events.each do |event| %>
      <div class="doc-item">
        <div class="doc-item__name">
          <span class="event-badge"><%= event['name'] %></span>
          <span class="doc-item__transition">
            <%= Array(event['from']).join(', ') %> → <%= event['to'] %>
          </span>
        </div>
        <% event_doc = @doc.dig(:events, event['name']) %>
        <p class="doc-item__text"><%= event_doc || "(not documented)" %></p>

        <% guards = Array(event['guards']) %>
        <% if guards.any? %>
          <div class="doc-item__guards">
            <strong>Guards:</strong>
            <% guards.each do |guard| %>
              <div class="guard-doc">
                <code><%= guard %></code>
                <% guard_doc = @doc.dig(:guards, guard) %>
                <span class="guard-doc__text"><%= guard_doc || "—" %></span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
  </section>

  <% if @doc[:named_docs].present? %>
    <section class="doc-section doc-section--full-width">
      <h2>Policy Notes</h2>
      <% @doc[:named_docs].each do |name, text| %>
        <div class="doc-item">
          <div class="doc-item__name"><%= name.humanize %></div>
          <p class="doc-item__text"><%= text %></p>
        </div>
      <% end %>
    </section>
  <% end %>
</div>
```

## The llms.txt Export

The `llms.txt` format is a flat text file that gives LLM agents structured context about a system. FOSM generates one automatically from the process documentation corpus.

<p class="listing-label">Listing 17.8 — app/services/llms_txt_exporter.rb</p>

```ruby
class LlmsTxtExporter
  def self.export(definitions)
    new(definitions).export
  end

  def initialize(definitions)
    @definitions = definitions
    @lines       = []
  end

  def export
    write_header
    @definitions.each { |d| write_definition(d) }
    @lines.join("\n")
  end

  private

  def write_header
    @lines << "# FOSM Process Documentation"
    @lines << "# Generated: #{Time.current.iso8601}"
    @lines << "# Source: #{Rails.application.class.module_parent_name}"
    @lines << "#"
    @lines << "# This file describes every state-machine-managed business process."
    @lines << "# It is generated from the model lifecycle definitions and is always current."
    @lines << "# Use this file to give an LLM agent context about business process rules."
    @lines << ""
    @lines << "---"
    @lines << ""
  end

  def write_definition(defn)
    doc = defn.documentation.with_indifferent_access

    @lines << "## #{defn.object_type}"
    @lines << ""

    if defn.process_description.present?
      @lines << defn.process_description
      @lines << ""
    end

    write_states(defn, doc)
    write_events(defn, doc)
    write_guards(doc)
    write_side_effects(doc)
    write_named_docs(doc)
    write_mermaid_diagram(defn)

    @lines << "---"
    @lines << ""
  end

  def write_states(defn, doc)
    return if defn.states.empty?

    @lines << "### States"
    @lines << ""
    defn.states.each do |state|
      terminal = defn.terminal_states&.include?(state) ? " [terminal]" : ""
      @lines << "**#{state}**#{terminal}"
      state_doc = doc.dig(:states, state)
      @lines << (state_doc || "(not documented)")
      @lines << ""
    end
  end

  def write_events(defn, doc)
    return if defn.events.empty?

    @lines << "### Events"
    @lines << ""
    defn.events.each do |event|
      froms = Array(event["from"]).join(", ")
      to    = event["to"]
      @lines << "**#{event['name']}** (#{froms} → #{to})"
      event_doc = doc.dig(:events, event["name"])
      @lines << (event_doc || "(not documented)")

      guards = Array(event["guards"])
      if guards.any?
        @lines << "Guards: #{guards.join(', ')}"
      end

      side_effects = Array(event["side_effects"])
      if side_effects.any?
        @lines << "Side effects: #{side_effects.join(', ')}"
      end
      @lines << ""
    end
  end

  def write_guards(doc)
    guards = doc[:guards] || {}
    return if guards.empty?

    @lines << "### Guard Conditions"
    @lines << ""
    guards.each do |guard, text|
      @lines << "**#{guard}**"
      @lines << text
      @lines << ""
    end
  end

  def write_side_effects(doc)
    effects = doc[:side_effects] || {}
    return if effects.empty?

    @lines << "### Side Effects"
    @lines << ""
    effects.each do |effect, text|
      @lines << "**#{effect}**"
      @lines << text
      @lines << ""
    end
  end

  def write_named_docs(doc)
    named = doc[:named_docs] || {}
    return if named.empty?

    @lines << "### Policy Notes"
    @lines << ""
    named.each do |name, text|
      @lines << "**#{name.to_s.humanize}**"
      @lines << text
      @lines << ""
    end
  end

  def write_mermaid_diagram(defn)
    @lines << "### State Diagram"
    @lines << ""
    @lines << "```mermaid"
    @lines << "stateDiagram-v2"
    @lines << "    [*] --> #{defn.initial_state}"

    defn.events.each do |event|
      froms = Array(event["from"])
      to    = event["to"]
      next unless to.is_a?(String)

      froms.each { |from| @lines << "    #{from} --> #{to} : #{event['name']}" }
    end

    (defn.terminal_states || []).each do |state|
      @lines << "    #{state} --> [*]"
    end

    @lines << "```"
    @lines << ""
  end
end
```

Call it:

```
$ curl https://yourapp.com/admin/fosm/docs.txt > llms.txt
```

Or from a rake task:

```
$ rails fosm:export_llms_txt > llms.txt
```

<p class="listing-label">Listing 17.9 — lib/tasks/fosm.rake (llms.txt export task)</p>

```ruby
namespace :fosm do
  desc "Export all process documentation as llms.txt"
  task export_llms_txt: :environment do
    definitions = FosmDefinition.all.order(:object_type)
    output_path = Rails.root.join("public", "llms.txt")

    File.write(output_path, LlmsTxtExporter.export(definitions))
    puts "Exported #{definitions.count} process definitions to #{output_path}"
  end

  desc "Reload all FOSM lifecycle definitions from model files"
  task reload_definitions: :environment do
    count = 0
    Dir[Rails.root.join("app/models/**/*.rb")].each do |file|
      model_name = File.basename(file, ".rb").camelize
      begin
        klass = model_name.constantize
        if klass.respond_to?(:fosm_lifecycle)
          klass.fosm_lifecycle.sync_to_database!
          count += 1
          puts "  ✓ #{model_name}"
        end
      rescue NameError, LoadError
        # Not a FOSM model
      end
    end
    puts "Reloaded #{count} FOSM definitions"
  end
end
```

## The Routes

<p class="listing-label">Listing 17.10 — config/routes.rb (process docs additions)</p>

```ruby
namespace :admin do
  namespace :fosm do
    resources :docs, param: :object_type, only: [:index, :show] do
      collection do
        get :export_llms_txt, path: "docs.txt"
      end
    end
  end
end
```

## Documentation Coverage as a Quality Metric

The admin index page shows documentation coverage for each FOSM object — how many states have `doc:` entries, how many events are documented. This is intentional. Undocumented states and events are a code smell, not just a documentation gap.

A helper:

<p class="listing-label">Listing 17.11 — app/helpers/fosm/docs_helper.rb</p>

```ruby
module Fosm
  module DocsHelper
    def documented_count(definition, section)
      doc = definition.documentation.with_indifferent_access
      items = doc[section] || {}
      items.count { |_, text| text.present? }
    end

    def documentation_coverage(definition)
      total   = definition.states.count + definition.events.count
      return 0 if total.zero?

      doc     = definition.documentation.with_indifferent_access
      documented = documented_count(definition, :states) +
                   documented_count(definition, :events)

      (documented.to_f / total * 100).round
    end

    def coverage_badge_class(pct)
      case pct
      when 80..100 then "badge-success"
      when 50..79  then "badge-warning"
      else              "badge-danger"
      end
    end
  end
end
```

Add a CI check to enforce minimum coverage:

<p class="listing-label">Listing 17.12 — spec/fosm/documentation_coverage_spec.rb</p>

```ruby
require "rails_helper"

RSpec.describe "FOSM documentation coverage" do
  MINIMUM_COVERAGE_PERCENT = 80

  FosmDefinition.all.each do |definition|
    describe "#{definition.object_type} lifecycle" do
      it "has a process_doc description" do
        expect(definition.process_description).to be_present,
          "#{definition.object_type} is missing a process_doc in its lifecycle block"
      end

      it "has states documented above #{MINIMUM_COVERAGE_PERCENT}%" do
        doc        = definition.documentation.with_indifferent_access
        total      = definition.states.count
        documented = (doc[:states] || {}).count { |_, t| t.present? }
        coverage   = total.zero? ? 100 : (documented.to_f / total * 100).round

        expect(coverage).to be >= MINIMUM_COVERAGE_PERCENT,
          "#{definition.object_type} has #{coverage}% state documentation " \
          "(#{documented}/#{total}). Add doc: to undocumented states."
      end

      it "has events documented above #{MINIMUM_COVERAGE_PERCENT}%" do
        doc        = definition.documentation.with_indifferent_access
        total      = definition.events.count
        documented = (doc[:events] || {}).count { |_, t| t.present? }
        coverage   = total.zero? ? 100 : (documented.to_f / total * 100).round

        expect(coverage).to be >= MINIMUM_COVERAGE_PERCENT,
          "#{definition.object_type} has #{coverage}% event documentation " \
          "(#{documented}/#{total}). Add doc: to undocumented events."
      end
    end
  end
end
```

Run it in CI:

```
$ bundle exec rspec spec/fosm/documentation_coverage_spec.rb
```

<div class="callout callout-ai">
<strong>AI Prompt: Audit Your Documentation</strong>
Download the llms.txt file and paste it into your LLM agent with this prompt: "You are auditing the process documentation for a business system. Review each process definition and identify: (1) states or events that appear underdocumented, (2) guard conditions that lack clear business rationale, (3) side effects whose behavior isn't explained. For each gap, suggest a doc: annotation that would close it." The model will read the entire corpus and return a prioritized list of documentation improvements. This turns documentation from a chore into a conversation.
</div>

## The Contact Lifecycle, Documented

To complete the picture, here's how the Contact module from Chapter 8 looks with full documentation applied:

<p class="listing-label">Listing 17.13 — app/models/contact.rb (lifecycle documentation excerpt)</p>

```ruby
lifecycle do
  process_doc "Manages the full lifecycle of external contacts: candidates, vendors, " \
              "partners, and customers. Contacts are the external party in NDA, hiring, " \
              "and vendor management workflows. The vetting process ensures due diligence " \
              "before a contact can be used in a business-critical context."

  state :prospect,
        doc: "Contact has been added to the system but not yet vetted. " \
             "Cannot be named as NDA counterparty or invoice vendor until approved. " \
             "Source tracked: referral, inbound, import, manual."

  state :active,
        doc: "Contact is fully vetted and usable across all modules. " \
             "Can be designated as NDA counterparty, invoice vendor, hire candidate."

  state :inactive,
        doc: "Contact has been deactivated — typically a departed employee, " \
             "terminated vendor relationship, or candidate no longer in pipeline. " \
             "Historical records preserved. Cannot be used in new workflows."

  event :vet do
    doc     "Transition from prospect to active after due diligence. " \
            "Records who vetted and when. Required for regulated vendor onboarding."
    from    :prospect
    to      :active
    guards  [:identity_verified?, :no_sanctions_match?]
  end

  guard :no_sanctions_match? do
    doc "Checks contact name and entity against OFAC/SDN list via SanctionsChecker service. " \
        "Required for vendor and partner contacts. Skipped for internal candidates " \
        "unless international flag is set."
  end
end
```

## Version Control as Documentation History

One final point that's easy to miss but impossible to overstate.

When you add `doc:` to a guard, that addition is in the same commit as the guard itself. When you change a guard's behavior, you're expected to change its `doc:` in the same commit. When a PR adds a new state, the reviewer sees immediately whether the state has a `doc:` entry.

Git log for a FOSM model file is simultaneously the business change log. You can look at the history of `app/models/invoice.rb` and see exactly when the high-value approval threshold was added, who added it, and what the code comment said about why. That's not a documentation system — that's the natural behavior of putting documentation in the same file as the code.

```
$ git log --follow -p app/models/invoice.rb | grep -A5 "process_doc\|doc:"
```

This command shows you every commit that changed a process description or documentation entry in the invoice lifecycle. Audit trail, change history, and business rationale — all from standard Git tooling.

<div class="callout callout-hood">
<strong>What Happens When a Guard Is Removed</strong>
If you delete a guard from a lifecycle event, the corresponding <code>doc:</code> entry for that guard is also gone — it was inside the guard block. There's no orphan documentation floating in a separate file. If you add a guard and forget to add <code>doc:</code>, the documentation coverage spec fails in CI. The system is structurally biased toward keeping documentation current.
</div>

## The Key Insight

Let's state the thesis explicitly, because it's the core argument of this chapter and it's worth being precise:

**FOSM makes the code self-documenting by design.** Every state has a name and a doc. Every event has a description. Every guard explains what it's checking. The lifecycle block is simultaneously the specification, the implementation, and the documentation.

When someone new joins the team and wants to understand the invoice approval process, they read `app/models/invoice.rb`. Not a Confluence page. Not a README. The model file. Because the model file has the process description at the top, documented states explaining each lifecycle phase, documented events explaining each transition trigger, documented guards explaining each business rule — and it is structurally impossible for that documentation to drift from the code, because it IS the code.

That's not just good engineering practice. It's a different philosophy about what documentation is for. Documentation isn't a record of what the code does. Documentation is the business knowledge that justifies why the code is written the way it is. Put that knowledge in the code, and you get the best of both worlds: executable specification and human-readable explanation, in one place, version-controlled, always current.

## What You Built

- **Three documentation mechanisms**: `process_doc` for lifecycle-level description, `doc:` keyword inline on states/events/guards/side-effects, and standalone `doc` method for named policy notes and long-form explanation.
- **Storage layer**: two new columns on `fosm_definitions` — `process_description` (text) and `documentation` (JSONB) — storing the extracted documentation corpus in a queryable, structured format.
- **Fully documented NDA lifecycle**: every state, event, guard, and side-effect carries its business explanation, including signing-order policy and re-send policy as named docs.
- **Fully documented Invoice lifecycle**: dual-approval policy, three-way match rationale, high-value threshold explanation, and rejection/void distinction all captured in the model file.
- **Admin Process Docs hub** at `/admin/fosm/docs`: index showing coverage metrics for every FOSM object, detail pages rendering state diagrams (Mermaid) and formatted documentation per element.
- **`LlmsTxtExporter`**: converts the entire process documentation corpus into a flat `llms.txt` file — one source of truth for developers, business architects, and LLM agents.
- **Rake tasks**: `rails fosm:reload_definitions` and `rails fosm:export_llms_txt` for CI/CD integration.
- **Documentation coverage RSpec suite**: enforces minimum 80% documentation coverage per lifecycle in CI — underdocumented objects fail the build.
- **Git as change history**: because documentation lives in the model file, `git log` is the business change log. No separate audit trail needed.
