---
title: "Appendix D: Setting Up the Development Environment"
chapter_number: "D"
part: "Appendices"
author: "Abhishek Parolkar"
---

> **Work in Progress** — This appendix is not yet published.

# Appendix D: Setting Up the Development Environment

This appendix walks you through a complete, clean setup for developing FOSM applications on macOS and Ubuntu Linux. Follow the steps in order; each section assumes the previous one has completed successfully.

The final result is a running Rails 8.1 application with SQLite3, Vite-powered assets, and all FOSM engine dependencies installed, accessible at `http://localhost:3000`.

---

## Prerequisites Overview

| Dependency | Version | Purpose |
|---|---|---|
| Ruby | 3.3+ | Language runtime |
| Rails | 8.1 | Web framework |
| SQLite3 | 3.39+ | Development database |
| Node.js | 20+ | Asset pipeline (Vite) |
| Yarn | 1.22+ | JavaScript package manager |
| Git | 2.x | Version control |
| rbenv or asdf | latest | Ruby version manager |

---

## macOS Setup

### 1. Install Homebrew

Homebrew is the standard macOS package manager. If you already have it, skip this step.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, follow the printed instructions to add Homebrew to your PATH. On Apple Silicon (M1/M2/M3), this typically means adding the following to `~/.zprofile`:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Restart your terminal after adding the PATH entry.

### 2. Install System Dependencies

```bash
brew install rbenv ruby-build sqlite3 node yarn git
```

Verify the installations:

```bash
sqlite3 --version    # should be 3.39 or higher
node --version       # should be v20.x or higher
yarn --version       # should be 1.22.x
git --version        # any recent version is fine
```

### 3. Install Ruby via rbenv

```bash
rbenv install 3.3.0
rbenv global 3.3.0
```

Add rbenv to your shell:

```bash
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc
```

If you use bash instead of zsh, replace `.zshrc` with `.bash_profile`. Verify:

```bash
ruby --version    # Ruby 3.3.0 (2023-12-25 revision ...)
which ruby        # should show a path under ~/.rbenv/shims/
```

### 4. Install Rails

```bash
gem install rails -v '~> 8.1'
```

This installs Rails 8.1.x (the latest patch release). Verify:

```bash
rails --version    # Rails 8.1.x
```

If `rails` is not found after installation, run `rbenv rehash` to regenerate shim binaries.

### 5. macOS-specific SQLite note

macOS ships with an older version of SQLite in `/usr/bin/sqlite3`. When you install SQLite3 via Homebrew, you get the newer version in `/opt/homebrew/bin/sqlite3`. The `sqlite3` gem used by Rails needs to link against the Homebrew version. Set the following before running `bundle install`:

```bash
export LDFLAGS="-L/opt/homebrew/opt/sqlite3/lib"
export CPPFLAGS="-I/opt/homebrew/opt/sqlite3/include"
```

For persistence, add these to your `~/.zshrc`. Alternatively, use the `--with-sqlite3-dir` flag when installing the gem:

```bash
gem install sqlite3 -- --with-sqlite3-dir=$(brew --prefix sqlite3)
```

---

## Ubuntu (22.04 / 24.04) Setup

### 1. Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Build Essentials and SQLite

```bash
sudo apt install -y \
  build-essential \
  libssl-dev \
  libreadline-dev \
  zlib1g-dev \
  libsqlite3-dev \
  sqlite3 \
  git \
  curl \
  wget \
  libffi-dev \
  libyaml-dev
```

Verify SQLite:

```bash
sqlite3 --version    # should be 3.37 or higher on Ubuntu 22.04
```

### 3. Install rbenv and ruby-build

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
```

### 4. Install Ruby

```bash
rbenv install 3.3.0
rbenv global 3.3.0
```

This takes several minutes as it compiles Ruby from source. Verify:

```bash
ruby --version    # Ruby 3.3.0
```

### 5. Install Rails

```bash
gem install rails -v '~> 8.1'
rbenv rehash
rails --version    # Rails 8.1.x
```

### 6. Install Node.js via nvm

The Node Version Manager (nvm) is the recommended way to install Node on Linux:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

nvm install 20
nvm use 20
nvm alias default 20
```

Verify:

```bash
node --version    # v20.x.x
npm --version     # 10.x.x
```

### 7. Install Yarn

```bash
npm install -g yarn
yarn --version    # 1.22.x
```

---

## Alternative: Using asdf

If you prefer a single version manager for both Ruby and Node, `asdf` is a strong alternative to rbenv + nvm.

```bash
# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
source ~/.bashrc

# Add plugins
asdf plugin add ruby
asdf plugin add nodejs

# Install versions
asdf install ruby 3.3.0
asdf install nodejs 20.11.0

# Set global versions
asdf global ruby 3.3.0
asdf global nodejs 20.11.0
```

Create a `.tool-versions` file in your project root for per-project pinning:

```
ruby 3.3.0
nodejs 20.11.0
```

---

## Project Setup

### 1. Clone the Repository

```bash
git clone <repo-url> inloop-runway
cd inloop-runway
```

If you are starting a fresh FOSM application from scratch rather than cloning an existing project, use:

```bash
rails new inloop-runway \
  --database=sqlite3 \
  --asset-pipeline=vite \
  --javascript=vite \
  --skip-jbuilder
cd inloop-runway
```

### 2. Install Ruby Gems

```bash
bundle install
```

The Gemfile includes:
- `rails ~> 8.1` — the framework
- `sqlite3` — database adapter
- `vite_rails` — asset pipeline integration
- Any FOSM engine gems specific to this project

If you encounter native extension errors, ensure you have the system dependencies from earlier steps installed and that your environment variables point to the correct library paths.

### 3. Install JavaScript Packages

```bash
yarn install
```

This installs Vite, Tailwind CSS, Stimulus, and any other frontend dependencies listed in `package.json`.

### 4. Set Up the Database

```bash
bin/rails db:setup
```

This command runs three operations in sequence:
1. `db:create` — Creates the SQLite3 database files
2. `db:schema:load` — Applies the schema
3. `db:seed` — Runs `db/seeds.rb` to load any seed data

If `db:schema:load` fails, try `db:migrate` instead:

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### 5. Start the Development Server

```bash
bin/dev
```

`bin/dev` uses Foreman (or Overmind if installed) to start multiple processes simultaneously:

- **Rails server** — `bin/rails server` on port 3000
- **Vite dev server** — `bin/vite dev` on port 3036 (handles hot-module replacement)
- **Solid Queue worker** — `bin/rails solid_queue:start` (processes background jobs)

Open your browser at `http://localhost:3000`. You should see the application home page.

---

## Troubleshooting

### SQLite version error

**Symptom:** `bundle install` fails with a message about incompatible SQLite3 version, or you see `SQLite3::Exception: incompatible library version` at runtime.

**Fix (macOS):**
```bash
gem uninstall sqlite3
gem install sqlite3 -- --with-sqlite3-dir=$(brew --prefix sqlite3)
```

**Fix (Ubuntu):** Ensure `libsqlite3-dev` is installed:
```bash
sudo apt install -y libsqlite3-dev
gem install sqlite3
```

---

### Node version mismatch

**Symptom:** `yarn install` fails or Vite errors mention unsupported Node features.

**Fix:**
```bash
# With nvm:
nvm use 20

# Verify the version in use:
node --version
```

Check that your shell's `PATH` resolves to the nvm-managed Node, not a system-installed version. Run `which node` — it should show a path under `~/.nvm/`.

---

### Vite port conflict

**Symptom:** `bin/dev` starts but the browser shows an asset loading error; Vite logs show `Error: listen EADDRINUSE :::3036`.

**Fix:** Something else is running on port 3036. Find and kill it, or change Vite's port in `config/vite.json`:

```json
{
  "development": {
    "autoBuild": true,
    "publicOutputDir": "vite",
    "port": 3037
  }
}
```

---

### `bin/dev` hangs or exits immediately

**Symptom:** The `bin/dev` process starts but immediately exits, or hangs without showing the server URL.

**Fix:** Run each process manually to identify the failure:
```bash
bin/rails server
# In a second terminal:
bin/vite dev
```

Check each output individually. The most common cause is a missing database — run `bin/rails db:setup` if you have not done so.

---

### `rbenv: command not found` after installation

**Fix:** Ensure your shell initialization file (`.zshrc` or `.bash_profile`) contains the rbenv init line and that you have sourced it:

```bash
source ~/.zshrc
# or
source ~/.bash_profile
```

Also run `rbenv rehash` after installing new gems that provide executables (like `rails`).

---

### Bundler version mismatch

**Symptom:** `bundle install` prints `Bundler X.X.X is running, but your lockfile was generated with Y.Y.Y`.

**Fix:**
```bash
gem install bundler -v 'X.X.X'  # version from the error message
bundle install
```

Or update the lockfile to use your current Bundler:
```bash
bundle update --bundler
```

---

### Permission errors during `gem install`

**Symptom:** `ERROR: While executing gem ... (Gem::FilePermissionError)`.

**Cause:** You are accidentally using the system Ruby instead of the rbenv-managed one.

**Fix:**
```bash
which ruby          # should show ~/.rbenv/shims/ruby, not /usr/bin/ruby
rbenv global 3.3.0
source ~/.zshrc
```

Never use `sudo gem install` with rbenv-managed Ruby. All gem operations should succeed without sudo.

---

## Editor Setup

### VS Code (Recommended)

Install these extensions from the VS Code Marketplace:

| Extension | Publisher | Purpose |
|---|---|---|
| Ruby LSP | Shopify | Language server: autocomplete, go-to-definition, inline errors |
| Tailwind CSS IntelliSense | Tailwind Labs | Autocomplete for Tailwind class names |
| ERB Formatter/Beautifier | Ali Hassan | Format `.html.erb` templates |
| Vite | antfu | Vite integration and config highlighting |
| GitLens | GitKraken | Enhanced git history in the editor |
| SQLite Viewer | Florian Klampfer | Browse SQLite databases (including `fosm_transitions`) directly |

**VS Code settings** — add these to your `settings.json` for the best Ruby experience:

```json
{
  "rubyLsp.enabledFeatures": {
    "diagnostics": true,
    "formatting": true,
    "hover": true,
    "inlayHints": true,
    "completion": true
  },
  "editor.formatOnSave": true,
  "[ruby]": {
    "editor.defaultFormatter": "Shopify.ruby-lsp"
  },
  "files.associations": {
    "*.erb": "erb"
  }
}
```

### RubyMine

RubyMine has first-class Rails support with no extensions required. Enable **Ruby > Code Quality > RuboCop** and point it at the project's `.rubocop.yml` for consistent linting.

### Neovim / Vim

Use `nvim-lspconfig` with the `ruby-lsp` server:

```lua
require('lspconfig').ruby_lsp.setup({})
```

---

## Verifying the Full Setup

Run the test suite to confirm everything is working:

```bash
bin/rails test
```

All tests should pass on a fresh clone. If any fail, check the error output against the troubleshooting section above. A clean test run is your confirmation that the environment is correctly configured.

To also run the system tests (browser-based integration tests):

```bash
bin/rails test:system
```

System tests require a headless browser. On macOS, `selenium-webdriver` uses the installed Chrome automatically. On Ubuntu, install Chromium:

```bash
sudo apt install -y chromium-browser
```
