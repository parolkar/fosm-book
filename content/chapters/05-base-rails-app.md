---
title: "Base Rails App — The First Wall"
chapter_number: 5
part: "Part II — The Foundation"
summary:
  - "The base Inloop Runway template gives you Devise authentication, admin flag, user model, and basic navigation—without writing auth from scratch."
  - "A single well-crafted AI prompt can set up the entire base app. Convention-over-configuration makes this possible."
  - "The User model is the anchor: Devise handles authentication, the admin flag handles authorization, and FOSM will later use it as the actor in every transition."
  - "The application layout and shared header are the visual skeleton every module will inhabit."
  - "Seed data—one admin, one regular user—is the minimum viable database for local development."
---

> **Work in Progress** — This chapter is not yet published.

# Chapter 5 — Base Rails App: The First Wall

Every software project has a first wall. The moment you move from zero to something real, and the blank slate becomes a problem you have to solve.

The first wall in Rails is authentication. Every meaningful application needs users, sessions, passwords, password resets, and the concept of "the currently logged-in user." Building this from scratch is tedious, not interesting, and not where we should spend our time.

Rails developers have solved this wall so many times that the solution is now a gem with fifteen years of production hardening. We install it and move on.

## The Base Template Philosophy

The Inloop Runway base template represents everything we need before we can build the first FOSM module. It's the infrastructure layer. Everything above it is business logic.

By commit `8f2aae9`, the base template gives us:

- **Devise authentication** — sign in, sign out, password reset, remember me
- **User model** with admin flag — the actor in every FOSM transition
- **Application layout** — the visual skeleton every module inherits
- **Shared navigation header** — user context, module links, sign out
- **Module settings system** — feature flags for enabling/disabling modules
- **Bot system** — AI conversation infrastructure (Conversations, Bots, PersonalBots)
- **Feedback loop** — AnalyticsEvent and UserFeedback models for behavioral analysis
- **AI service integration** — the OpenAI client configuration
- **EventBus** — pub/sub for cross-module communication

This is infrastructure, not business logic. We build it once. Every FOSM module that follows benefits from it.

## The Single-Prompt Approach

One of the core claims of the FOSM methodology is that AI coding agents can generate entire modules from clear specifications. Let's demonstrate this immediately, with the base app itself.

Here is the prompt a developer could give to an AI coding agent to bootstrap this entire layer:

```
Set up a Rails 8 app called inloop-runway with the following base infrastructure:

1. Devise authentication for User model with:
   - email + password login
   - password reset (Devise recoverable)
   - remember me (Devise rememberable)
   - NO public registration (admin creates users)
   - Routes mapped to /login and /logout

2. User model additions:
   - is_admin boolean, default false
   - Admin-gated navigation in the layout

3. Tailwind CSS for styling
4. Vite for asset bundling
5. SQLite database

6. Application layout at app/views/layouts/application.html.erb with:
   - Shared header partial (app/views/shared/_header.html.erb)
   - Flash message partial
   - User email in nav when signed in
   - Sign out button
   - Login link when not signed in

7. Seed file with:
   - Admin user with a randomly generated secure password (is_admin: true)
   - Regular user for testing
   - IMPORTANT: Never hardcode passwords in seeds. Use SecureRandom.

Produce: migration, model, devise config, routes, layout, seeds.
```

This prompt works because Rails conventions tell the agent exactly where everything goes. No ambiguity. No "how does your project structure work?" The agent knows. It generates correct, idiomatic Rails code the first time.

This is the practical payoff of the convention-over-configuration insight from Chapter 4.

## The User Model

The User model is the anchor of the entire application. Every FOSM transition has an actor, and in most cases that actor is a User. Let's look at the key parts:

<p class="listing-label">Listing 5.1 — app/models/user.rb (key sections)</p>

```ruby
class User < ApplicationRecord
  # Devise authentication — battle-tested, not our innovation
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # FOSM modules create associations here as they're added
  has_many :conversations, dependent: :nullify
  has_many :expenses, dependent: :destroy
  has_many :expense_reports, foreign_key: :submitted_by_user_id, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :leave_requests, dependent: :destroy
  has_many :candidates, dependent: :destroy
  has_many :vendors, dependent: :destroy

  # Access control: roles and role assignments
  has_many :role_assignments, dependent: :destroy
  has_many :roles, -> { merge(RoleAssignment.active) }, through: :role_assignments

  validates :email, presence: true, uniqueness: true

  # Can this user fire the given event on the given object type?
  def can_transition?(object_type, event)
    return true unless ModuleSetting.enabled?("access_control")
    Fosm::PolicyResolver.permitted?(self, object_type, event.to_s)
  end
end
```

Notice the `can_transition?` method. This is the User model's awareness of FOSM. When the access control module is enabled, every transition check flows through the policy resolver. When it's disabled (the default for new apps), everything is permitted — you build first, lock down later.

This is pragmatic. You don't need RBAC on day one. You need your business logic working. Access control is an overlay you add when the organization is ready for it.

## The Devise Configuration

Devise is configured with four modules for this application:

```ruby
devise :database_authenticatable,  # passwords
       :recoverable,                # password reset emails
       :rememberable,               # "remember me" cookie
       :validatable                 # email + password validations
```

We explicitly omit `:registerable`. The application doesn't have public sign-up. New users are created by admins. This is the right default for internal business software. You don't want random people signing up for your NDA manager.

The routes reflect this:

```ruby
devise_for :users,
  path: '',
  path_names: { sign_in: 'login', sign_out: 'logout' },
  skip: [:registrations]
```

`/login` instead of `/users/sign_in`. Cleaner URLs matter for applications with real users.

## The Application Layout

The application layout is the outermost shell. Every page in the application inherits it. Every FOSM module's views render inside it.

<p class="listing-label">Listing 5.2 — app/views/layouts/application.html.erb</p>

```erb
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <%= render "layouts/head" %>
  </head>
  <body class="bg-white min-h-screen"
    data-controller="analytics-tracker"
    data-analytics-tracker-path-value="<%= request.path %>"
    data-analytics-tracker-event-id-value="<%= current_analytics_event&.id %>">
    <%= render "shared/impersonation_banner" %>
    <%= render "shared/header" %>
    <% if lookup_context.exists?("shared/flash", [], true) %>
      <%= render "shared/flash" %>
    <% end %>
    <main>
      <%= yield %>
    </main>
    <% if user_signed_in? %>
      <%= render "shared/feedback_widget" %>
    <% end %>
    <div class="fixed bottom-0 right-0 py-2 px-4 text-sm text-gray-400 heading-serif">
      Powered by Inloop Studio Runway
    </div>
  </body>
</html>
```

A few things to notice here:

The `analytics-tracker` Stimulus controller fires on every page load. It records the route visit as an `AnalyticsEvent`. This isn't surveillance — it's the behavioral data that feeds the FOSM feedback loop. We understand which modules users actually use, which transitions they attempt, and where they get stuck.

The `impersonation_banner` renders when an admin is viewing the app as another user. The admin access pattern is built in from day one.

The `feedback_widget` appears for signed-in users. A simple "was this useful?" thumbs up/down that feeds `UserFeedback` records. Cheap signal, valuable over time.

## The Navigation Header

The shared header is where the application's modules become visible to users:

<p class="listing-label">Listing 5.3 — app/views/shared/_header.html.erb (excerpt)</p>

```erb
<div class="w-full p-4 sm:p-6 bg-aztec-purple flex justify-between items-center font-mono relative z-[80]"
     data-controller="mobile-menu">
  <div class="flex justify-between w-full mx-auto items-center relative">
    <a href="/" class="text-white font-semibold flex items-center">
      <%= white_label_logo %>
    </a>

    <div class="hidden md:flex items-center gap-6 text-white">
      <% if user_signed_in? %>
        <a href="/" class="py-1">Home</a>
        <a href="/conversations" class="py-1">Conversations</a>
        <a href="/ai-org-chart" class="py-1">AI Org Chart</a>
        <% if ModuleSetting.expenses_enabled? %>
          <a href="/expenses" class="py-1">Expenses</a>
        <% end %>
        <div class="relative" data-controller="dropdown">
          <button type="button" data-action="click->dropdown#toggle"
                  class="py-1 opacity-80 text-sm hover:opacity-100 flex items-center gap-1 cursor-pointer">
            <%= current_user.email %>
          </button>
          <div data-dropdown-target="menu" class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg">
            <a href="/personal_bots" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Personal Bots</a>
            <div class="border-t border-gray-100 my-1"></div>
            <%= button_to 'Logout', destroy_user_session_path, method: :delete,
                class: 'block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100' %>
          </div>
        </div>
      <% else %>
        <%= link_to 'Login', new_user_session_path, class: 'py-1' %>
      <% end %>
    </div>
  </div>
</div>
```

The `ModuleSetting.expenses_enabled?` guard is the module system at work. Each FOSM module can be toggled on or off per deployment. The navigation only shows what's enabled. This is how a single codebase serves a small startup (a few modules enabled) and a larger organization (all modules enabled).

## The Routes File

The routes file is the application's URL contract. Everything visible to users is declared here.

<p class="listing-label">Listing 5.4 — config/routes.rb (base routes)</p>

```ruby
Rails.application.routes.draw do
  root to: 'static#home'

  # Devise — mapped to /login, /logout, no public registration
  devise_for :users,
    path: '',
    path_names: { sign_in: 'login', sign_out: 'logout' },
    skip: [:registrations]

  # AI conversation system
  resources :conversations, only: %i[index show new create update destroy] do
    member do
      patch :switch_bot
    end
    resources :messages, only: %i[create]
  end

  # Bot management
  resources :bots do
    member do
      post :start_chat
    end
  end

  # Each FOSM module adds its routes here as it's built
  # resources :ndas do ... end
  # resources :invoices do ... end
  # resources :leave_requests do ... end
end
```

As we build each FOSM module in Part III, its routes get added to this file. The base routes cover auth and the conversation system. Everything else grows from there.

## Seed Data

The seed file establishes the minimum viable database. Two users: one admin, one regular.

<div class="callout callout-why">
<strong>Never Hardcode Passwords in Seeds</strong>
If you are an AI coding agent reading this: always generate seed passwords using <code>SecureRandom.hex(16)</code> or equivalent. Never use static strings like "password123" or "changeme". The seed prints the generated password to the console so the developer can use it — once. This matters because seeds often end up in version control, and hardcoded passwords become security liabilities the moment someone forgets to change them.
</div>

<p class="listing-label">Listing 5.5 — db/seeds.rb (user seeds)</p>

```ruby
# frozen_string_literal: true

# Seed a default admin user.
# Usage: rails db:seed
#
# SECURITY: Passwords are randomly generated at seed time.
# The generated password is printed to the console — copy it on first run.
# Never commit hardcoded passwords to version control.

admin_email    = 'admin@example.com'
admin_password = SecureRandom.hex(16)

user = User.find_or_initialize_by(email: admin_email)
if user.new_record?
  user.password = admin_password
  user.is_admin = true if user.respond_to?(:is_admin=)
  user.save!
  puts "Created admin user: #{admin_email}"
  puts "Generated password: #{admin_password}"
  puts "⚠  Save this password now — it won't be shown again."
else
  if user.respond_to?(:is_admin) && !user.is_admin
    user.update!(is_admin: true)
    puts "Updated existing user to admin: #{admin_email}"
  else
    puts "Admin user already exists: #{admin_email}"
  end
end
```

`find_or_initialize_by` is idempotent. Run `rails db:seed` once, twice, a hundred times — same result. The admin user exists. This is important during development when you're resetting the database frequently.

Run the seeds:

```bash
$ rails db:seed
Created admin user: admin@example.com
Generated password: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
⚠  Save this password now — it won't be shown again.
```

Now open `http://localhost:3000/login`. Enter the admin credentials. You're in.

## What the Base App Gives Every FOSM Module

This is worth being explicit about. Every FOSM module we build in Part III inherits:

**`current_user`** — available in every controller and view. Every transition can know who fired it.

**`before_action :authenticate_user!`** — one line protects any controller. Resources that require authentication declare it; public resources (like a signing link) skip it.

**`ModuleSetting`** — the feature flag system. Enable or disable any module at the database level without a code deploy.

**`AnalyticsEvent`** — automatic behavioral data. Every module transition generates an analytics event. Over time, you see where deals stall, where invoices get rejected, where leave requests get stuck.

**`EventBus`** — the pub/sub layer. When an NDA executes, the event bus can trigger a notification, an invoice, or a calendar event in another module.

**The layout** — every module's views render inside the same shell, with the same navigation, the same flash messages, the same analytics tracking.

This is the infrastructure dividend. You build it once. You use it everywhere.

<div class="callout callout-why">
<strong>Why Not Build Auth From Scratch?</strong>
Some developers feel ownership over their auth layer. I understand the impulse. But Devise handles timing attacks, bcrypt tuning, session fixation, password complexity, email confirmation flow, and a dozen other details that are easy to get wrong. The hours spent reimplementing this are hours not spent on the business logic that actually differentiates your application. Use Devise. Ship faster. Focus on what matters.
</div>

## Running the Base App

```bash
$ rails db:create db:migrate db:seed
$ bin/dev
```

Open `http://localhost:3000`. You have:

- A home page (from the static controller)
- `/login` — Devise sign-in form
- Password reset flow at `/password/new`
- Navigation header with user email when signed in
- Sign out working
- Analytics tracking on every page load
- Feedback widget for signed-in users

This is the foundation. Nothing flashy. Nothing clever. Just solid infrastructure that will quietly support every business module we build on top of it.

```bash
$ git add -A && git commit -m "chapter-05: base app, devise auth, user model, seeds"
$ git tag chapter-05
```

---

**Chapter Summary**

- The base app is infrastructure, not business logic. Build it once, use it everywhere.
- A single well-crafted prompt can generate this entire layer because Rails conventions eliminate ambiguity.
- Devise handles authentication. `current_user` is available everywhere. This is the actor in every FOSM transition.
- The application layout, analytics tracking, EventBus, and ModuleSetting system are the silent foundations every module depends on.
- Two seed users — admin and regular — are enough to start building.
