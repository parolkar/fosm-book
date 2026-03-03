---
title: "Rails 8 — The One-Person Framework"
chapter_number: 4
part: "Part II — The Foundation"
summary:
  - "Rails 8 is ideal for FOSM because convention-over-configuration gives LLMs exactly one right way to generate production-ready code."
  - "SQLite-first, Hotwire built-in, and Vite for assets means no separate processes, no tooling friction."
  - "DHH's one-person framework philosophy: a single developer can build and maintain meaningful, revenue-generating software."
  - "The generated Rails structure—app/, config/, db/, Gemfile, Procfile.dev—is the scaffold for everything that follows."
  - "bin/dev starts the entire stack with one command. That's the philosophy, not just a convenience."
---

> **Work in Progress** — This chapter is not yet published.

# Chapter 4 — Rails 8: The One-Person Framework

There's a moment when you set up a new Rails app and realize it already knows what you want. The directory is laid out. The conventions are in place. The tests have a home. The assets have a pipeline. Authentication has a well-worn path. Before you write a single line of business logic, the structure is there.

That's not an accident. That's thirty years of opinionated distillation. And it's exactly what makes Rails the right foundation for FOSM.

## Why Rails in 2026?

The enterprise world loves to ask this question. Kubernetes, microservices, Go, Rust — the gravitational pull of complexity is real. But ask yourself: what problem are you actually solving?

If your goal is to build business software — invoices, agreements, hiring pipelines, vendor management, project tracking — then the question isn't "which technology is most scalable?" The question is "which technology lets one person build something real?"

Rails answers that question decisively. [Shopify processes billions in GMV](https://www.shopify.com/blog/shopify-technology) on Rails. [GitHub serves millions of developers](https://github.blog/engineering/) on Rails. These are not legacy decisions that teams are embarrassed about. They are conscious choices made by founders who code and who chose Rails specifically because it gives you leverage.

DHH named Rails 8 the "one-person framework" explicitly. The claim is serious: a single developer using Rails 8 can build, deploy, and operate software that would have required a team of five in 2015. SQLite for the database, Solid Queue for background jobs, Solid Cache for caching, Kamal for deployment. No Redis. No separate Postgres instance. No container orchestration for a product that has 200 users.

The stack matches the problem.

## Rails is LLM-Ready

Here's something the AI tooling community is slowly waking up to, but practitioners already know: Rails is the best framework for working with AI coding agents.

Not because it has special AI tooling. Because of convention-over-configuration.

When a developer asks an AI coding agent to "add an expense report module with approval workflow," the agent needs to make hundreds of micro-decisions. Where does the model live? What does the migration look like? How does the controller route? Where do views go? What's the naming convention for the mailer?

In a convention-less framework, the agent guesses. Sometimes it guesses right. Often it doesn't, and the generated code doesn't integrate cleanly with what already exists.

In Rails, there's one right answer to every one of those questions. The model lives in `app/models/`. The migration uses `rails generate migration`. The controller inherits from `ApplicationController`. The views live in `app/views/expense_reports/`. The mailer lives in `app/mailers/`. The naming conventions are deterministic.

The AI doesn't guess. It applies the convention. And the generated code works.

Garry Tan put it simply: "Rails was designed for people who love syntactic sugar, and LLMs are sugar fiends." The conventions that feel like constraints to contrarian developers are, for AI agents, a north star. They produce consistent, idiomatic, mergeable code.

This is the insight behind the FOSM stack choice, articulated in [the FOSM paper](https://www.parolkar.com/fosm): the thinnest possible tech stack for rapid iteration across entire business systems. Rails conventions are not just ergonomic for humans. They are load-bearing structure for AI-assisted development.

When we define a lifecycle with `include Fosm::Lifecycle` and a `lifecycle do ... end` block, the AI agent can read that DSL and generate the controller, views, routes, and tests automatically. It knows exactly what to produce because the framework tells it exactly where everything lives.

That's not future vision. That's what we do in every chapter of this book.

## The One-Person Philosophy

DHH's design philosophy for Rails 8 is worth quoting directly: one person can build and operate a production application that serves real users and generates real revenue.

This isn't about startups. It's about leverage. A founder who wants to automate their operations. A senior engineer who wants to build the internal tool their company actually needs, not the one IT will approve in six months. A consultant who wants to deliver a working system, not a requirements document.

FOSM is an implementation of this philosophy at the business-logic layer. The framework gives you conventions for data, authentication, and deployment. FOSM gives you conventions for business processes. Together, they let one person encode real organizational workflows as working software.

## Creating the App

We'll use the `rails new` command to create the Inloop Runway app. This is the scaffolding from which every FOSM module grows.

```bash
$ rails new inloop-runway \
    --database=sqlite3 \
    --asset-pipeline=vite \
    --css=tailwind \
    --skip-jbuilder \
    --skip-action-mailbox \
    --skip-action-text
```

No `--api` flag. We want the full stack — HTML responses, Turbo, Stimulus. FOSM modules render in the browser. We want Hotwire's optimistic DOM updates without writing a single line of JavaScript framework code.

After this command runs, you have a working application. Let's understand what we have.

## The Generated Structure

```
inloop-runway/
├── app/
│   ├── assets/
│   ├── channels/
│   ├── controllers/
│   │   └── application_controller.rb
│   ├── helpers/
│   ├── javascript/       ← Vite entry point
│   ├── jobs/
│   ├── mailers/
│   ├── models/
│   │   └── application_record.rb
│   └── views/
│       └── layouts/
├── bin/
│   └── dev              ← starts everything
├── config/
│   ├── database.yml
│   ├── routes.rb
│   └── application.rb
├── db/
│   ├── migrate/
│   └── seeds.rb
├── Gemfile
├── Procfile.dev
└── Procfile
```

Each directory has one job. `app/models/` is models. `app/controllers/` is controllers. `app/views/` is views. Rails never lets these blur. When an AI agent generates code, it generates it into the right place because the right place is unambiguous.

Let's look at the key configuration files.

## The Gemfile

This is the Inloop Runway Gemfile. Every gem earns its place. We don't add things because they're popular.

<p class="listing-label">Listing 4.1 — Gemfile</p>

```ruby
source "https://rubygems.org"
ruby "~> 3.3"

gem "rails", "~> 8.0"
gem "sqlite3", "~> 2.1"
gem "puma", "~> 6.4"
gem "hotwire-rails"
gem "devise"
gem "ruby-openai", "~> 7"
gem "httparty"
gem "vite_rails", "~> 3.0"
gem "heroicon"
gem "cloudconvert", ">= 1.1"
gem "image_processing", "~> 1.13"
gem "commonmarker", "~> 0.23"
gem "pagy", "~> 6.4"
gem "sage-rails", require: "sage", github: "inloopstudio-team/sage", branch: "main"
gem "dotenv"

group :development, :test do
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.2"
end

group :development do
  gem "tidewave", github: "tidewave-ai/tidewave_rails"
end

gem "honeybadger", "6.2"
```

Walk through the key choices:

**`sqlite3 ~> 2.1`** — Not Postgres. Not MySQL. SQLite. This is the most controversial line in the file for developers who learned Rails in the Heroku era. Here's the reality: SQLite on modern hardware handles thousands of concurrent reads with ease. For a single-tenant business application — even one used by a company with 500 employees — SQLite is not just adequate. It's better. No separate process. No connection pooling to configure. No network round-trips. The database is a file. Backups are `cp`. This is the right call for 95% of the business software we build.

**`hotwire-rails`** — Not React. Not Vue. Not a single-page app. Hotwire gives us Turbo for fast HTML swaps and Stimulus for light JavaScript behavior. FOSM module views update in real time without a JSON API layer. When a transition fires, Turbo replaces the status badge without a full page reload. That's the entire frontend story.

**`devise`** — Authentication is solved. Devise has been solving it since 2009. We don't build auth. We install Devise and configure it. This is exactly the kind of leverage DHH's philosophy describes: don't innovate on commodity infrastructure.

**`ruby-openai`** — AI service integration for modules that need it. We'll use this in the conversation layer and in FOSM side effects that invoke LLM services.

**`vite_rails`** — Modern asset bundling. Fast HMR in development. Clean production builds. No Webpacker complexity.

**`tidewave`** — Only in development. Tidewave gives AI coding agents structured access to the Rails runtime — routes, models, schema — so they can generate accurate code without hallucinating your data model. Worth including from day one.

## The Procfile

We use two Procfiles. `Procfile` is for production deployment (Kamal uses this). `Procfile.dev` is for local development.

<p class="listing-label">Listing 4.2 — Procfile.dev</p>

```
web: bin/rails server -b 0.0.0.0 -p $PORT
vite: yarn dev
```

Two processes. That's the entire local development stack. The Rails server and the Vite asset watcher. No Redis. No background job daemon running separately. No message queue to spin up. When you run `bin/dev`, both start together.

This is intentional simplicity. Rails 8's Solid Queue runs background jobs in the same SQLite database. Solid Cache does caching in SQLite. The entire runtime is one process group.

## The Database Configuration

<p class="listing-label">Listing 4.3 — config/database.yml</p>

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: <%= ENV.fetch("DB_DEV_PATH", "db/development.sqlite3") %>

test:
  <<: *default
  database: <%= ENV.fetch("DB_TEST_PATH", "db/test.sqlite3") %>

production:
  <<: *default
  database: <%= ENV.fetch("DB_PROD_PATH", "db/production.sqlite3") %>
```

The database path is configurable via environment variable in all three environments. In production on a dedicated server, you point this at a persistent volume path. In development, it's a file in `db/`. In CI, it's a fresh file per test run.

Notice there's no `username`, `password`, `host`, or `port`. That's the point. SQLite has no network interface. That's a feature.

<div class="callout callout-why">
<strong>Why SQLite in Production?</strong>
The Postgres-by-default habit is a legacy of the Heroku era, when "real" apps needed a separate database service. Modern hardware and modern SQLite (WAL mode, concurrent reads) changes the calculus. DHH has been vocal: for most business apps, SQLite outperforms Postgres on a single server because there's no network round-trip. If you ever need to migrate, Active Record abstracts the difference. Start simple.
</div>

## Starting the Stack

```bash
$ bin/dev
```

One command. Everything starts. Rails server on port 3000. Vite watcher watching `app/javascript/`. Hit `http://localhost:3000` and you get the default Rails welcome page.

That's the blank canvas. From here, we add structure.

## The Stack Choices as a System

It's worth stepping back to see these choices as a coherent system, not a grab-bag of preferences.

**SQLite** eliminates the external database process. **Hotwire** eliminates the JavaScript framework. **Devise** eliminates custom auth code. **Vite** gives modern asset bundling without webpack complexity. **Tidewave** gives AI agents live access to the Rails runtime.

Every elimination matters. Every dependency we don't add is one fewer thing to configure, one fewer thing to break, one fewer thing the AI agent needs to reason about.

The FOSM approach — encoding business processes as Ruby objects with declared lifecycles — fits this philosophy perfectly. Business logic lives in model files. Transitions are method calls. Side effects are named, documented blocks. There's no orchestration service. No BPMN runtime. No workflow engine to deploy.

The framework and the pattern reinforce each other.

<div class="callout callout-ai">
<strong>AI Coding Agents and the Rails Stack</strong>
When you give an AI coding agent a Rails 8 codebase, it can navigate it without explanation. The conventions are baked into its training data. It knows that <code>app/models/nda.rb</code> contains the Nda model. It knows that <code>rails generate migration AddStatusToNdas</code> creates a timestamped migration file. It knows that Devise's <code>current_user</code> helper is available in controllers and views. This shared vocabulary between developer and agent is one of Rails' most underrated assets in the AI era.
</div>

## What We've Established

The application exists. The directory structure is in place. The conventions are active. The stack is running.

In Chapter 5, we'll add the base infrastructure — Devise authentication, the user model, the application layout — that every FOSM module will depend on. We'll use a single AI prompt to set up what would take a day of manual work.

```bash
$ git add -A && git commit -m "chapter-04: rails new, gemfile, db config, procfile"
$ git tag chapter-04
```

---

**Chapter Summary**

- Rails 8 is the right foundation for FOSM: conventions eliminate decisions, leaving space to focus on business logic.
- Convention-over-configuration is precisely what AI coding agents need. They generate idiomatic Rails code because the conventions are unambiguous.
- The stack choices — SQLite, Hotwire, Devise, Vite — each eliminate a category of operational complexity.
- DHH's one-person framework philosophy aligns exactly with FOSM's goal: one developer encoding real organizational workflows as working software.
- `bin/dev` starts everything. That's not just convenience — it's the philosophy made executable.
