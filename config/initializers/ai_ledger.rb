# frozen_string_literal: true

# The AI Ledger - Site Branding Configuration
# AI news aggregator for credit union professionals

Rails.application.config.ai_ledger = ActiveSupport::OrderedOptions.new

# Site Identity
Rails.application.config.ai_ledger.site_name = "The AI Ledger"
Rails.application.config.ai_ledger.site_tagline = "AI News for Credit Union Professionals"
Rails.application.config.ai_ledger.site_domain = ENV.fetch("SITE_DOMAIN", "theailedger.com")

# Branding Colors
Rails.application.config.ai_ledger.colors = {
  primary: "#1E3A5F",      # Navy Blue - professional/financial
  secondary: "#C9A227",    # Gold - premium/trust
  accent: "#2E7D32",       # Green - growth/positive
  background: "#F5F5F5",   # Light gray
  text: "#333333"          # Dark gray
}

# Bot User Configuration
Rails.application.config.ai_ledger.bot_username = "ai_agent"
Rails.application.config.ai_ledger.bot_email = "bot@theailedger.com"

# RSS Scanning Configuration
Rails.application.config.ai_ledger.rss_scan_enabled = ENV.fetch("RSS_SCAN_ENABLED", "true") == "true"
Rails.application.config.ai_ledger.rss_scan_interval = ENV.fetch("RSS_SCAN_INTERVAL", "3600").to_i
Rails.application.config.ai_ledger.relevance_threshold = ENV.fetch("RELEVANCE_THRESHOLD", "0.5").to_f

# Feature Flags
Rails.application.config.ai_ledger.open_signups = ENV.fetch("OPEN_SIGNUPS", "false") == "true"
Rails.application.config.ai_ledger.bot_enabled = ENV.fetch("BOT_USER_ENABLED", "true") == "true"
Rails.application.config.ai_ledger.agents_enabled = ENV.fetch("AGENTS_ENABLED", "true") == "true"
