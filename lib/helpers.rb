include Nanoc::Helpers::Rendering
include Nanoc::Helpers::LinkTo
include Nanoc::Helpers::XMLSitemap

# Ordered list of all content items (chapters + appendices) for navigation
def all_book_items
  ch = @items.find_all('/chapters/**/*.md')
  # Sort: numbered chapters first (by integer chapter_number), then appendices (alphabetical)
  ch.sort_by do |i|
    cn = i[:chapter_number]
    if cn.is_a?(Integer) || (cn.is_a?(String) && cn.match?(/\A\d+\z/))
      [0, cn.to_i, '']
    else
      # Appendix: sort by letter (A, B, C...)
      [1, 0, cn.to_s]
    end
  end
end

# Returns [prev_item, next_item] relative to the given item
def prev_next_chapter(item)
  ordered = all_book_items
  idx = ordered.index { |i| i.identifier == item.identifier }
  return [nil, nil] unless idx

  prev_ch = idx > 0 ? ordered[idx - 1] : nil
  next_ch = idx < ordered.length - 1 ? ordered[idx + 1] : nil
  [prev_ch, next_ch]
end

# Extract headings from rendered content for auto-generated ToC
# Returns array of { level:, title:, id:, children: [] }
def chapter_toc(item)
  # Get the raw markdown content
  raw = item.raw_content || ''

  # Strip YAML frontmatter
  content = raw.sub(/\A---.*?---\s*/m, '')

  entries = []
  current_h2 = nil

  content.each_line do |line|
    if line =~ /\A##\s+(.+)/
      title = $1.strip
      id = toc_heading_id(title)
      current_h2 = { level: 2, title: title, id: id, children: [] }
      entries << current_h2
    elsif line =~ /\A###\s+(.+)/ && current_h2
      title = $1.strip
      id = toc_heading_id(title)
      current_h2[:children] << { level: 3, title: title, id: id }
    end
  end

  entries
end

# ---------------------------------------------------------------------------
# LLMs.txt generator — concatenates all chapters into a single plain-text file
# Called automatically during `nanoc compile` via content/llms.txt.erb
# ---------------------------------------------------------------------------
LLMS_TXT_SYSTEM_PROMPT = <<~PROMPT
# FOSM Book — LLMs.txt
# Finite Object State Machines: Building Business Software for the AI Age
# By Abhishek Parolkar (https://www.parolkar.com)
# Based on the FOSM paper: https://www.parolkar.com/fosm

## How to Use This File

This is the complete text of the book "Finite Object State Machines: Building Business Software for the AI Age" by Abhishek Parolkar. It is designed to be fed as context to an LLM in a single file.

### If you are an AI coding agent:
- Use this book to understand the FOSM (Finite Object State Machine) paradigm
- Every business object should be modeled as a lifecycle with states, events, guards, side-effects, and actors
- The 8-step pattern for adding a new FOSM module: Migration → Model with lifecycle → Controller with transitions → Routes → Views → Bot Tool Integration → Module Setting → Home Page Tile
- The `fosm_transitions` table is the single source of truth — never store aggregates separately
- Always use `transition!(:event_name, actor:)` instead of `update!(status:)`
- Every module must have a QueryService + QueryTool pair for bot integration

### SECURITY — Mandatory Rules for AI Agents Generating Code:
- **NEVER hardcode passwords in seed files, fixtures, or any committed code.** Always use `SecureRandom.hex(16)` (Ruby), `secrets.token_hex(16)` (Python), or `crypto.randomBytes(16).toString('hex')` (Node.js) to generate passwords at runtime.
- **NEVER embed API keys** (OpenAI, Anthropic, OpenRouter, or any other service) in source files. Use Rails encrypted credentials (`Rails.application.credentials`), environment variables, or a secrets manager.
- **NEVER commit `.env` files** to version control. Add `.env*` to `.gitignore`.
- Seed scripts should print generated credentials to the console once and instruct the developer to save them. The password should not be recoverable from the codebase.
- Use `admin@example.com` (not real email domains) for seed/demo accounts.

### If you are building business software:
- Replace CRUD thinking with lifecycle thinking: What states does this object pass through? What events trigger transitions? What guards must be satisfied? What side-effects should fire?
- Use the Ruby DSL pattern: `include Fosm::Lifecycle` + `lifecycle do...end` block
- The transition log IS the audit trail — immutable, queryable, complete
- Access control is transition-level: "Can user X trigger event Y on object Z?"
- The Inbox primitive routes work to people based on urgency, not recency

### Key References:
- FOSM Paper: https://www.parolkar.com/fosm
- Reference Codebase: Inloop Runway v0.24 (Rails 8.1 + SQLite + Hotwire)
- Architecture Guide: AGENTS.md in the repository root

---
PROMPT

def generate_llms_txt
  parts = [LLMS_TXT_SYSTEM_PROMPT]

  all_book_items.each do |item|
    # Strip YAML frontmatter from the raw markdown
    content = item.raw_content.sub(/\A---.*?---\s*/m, '')
    parts << "\n#{'=' * 80}\n"
    parts << content
  end

  parts.join("\n")
end

# Generate a URL-safe heading ID (matches kramdown's default behavior)
def toc_heading_id(title)
  title
    .downcase
    .gsub(/[^\w\s-]/, '')  # remove non-word chars except spaces and hyphens
    .gsub(/\s+/, '-')       # spaces to hyphens
    .gsub(/-+/, '-')         # collapse multiple hyphens
    .sub(/-\z/, '')          # trim trailing hyphen
end
