pwd = SecureRandom.base58
User.create!(
  username: "inactive-user",
  email: "inactive-user@example.com",
  password: pwd,
  password_confirmation: pwd
)

User.create!(
  username: "test",
  email: "test@example.com",
  password: "test",
  password_confirmation: "test",
  is_admin: true,
  is_moderator: true,
  karma: [
    User::MIN_KARMA_TO_SUGGEST,
    User::MIN_KARMA_TO_FLAG,
    User::MIN_KARMA_TO_SUBMIT_STORIES,
    User::MIN_KARMA_FOR_INVITATION_REQUESTS
  ].max,
  created_at: User::NEW_USER_DAYS.days.ago
)

c = Category.create!(category: "Category")
Tag.create!(category: c, tag: "test")

Rails.logger.debug "created:"
Rails.logger.debug "  * an admin with username/password of test/test"
Rails.logger.debug "  * inactive-user for disowned comments by deleted users"
Rails.logger.debug "  * a test tag"
Rails.logger.debug
Rails.logger.debug "If this is a dev environment, you probably want to run `rails fake_data`"
Rails.logger.debug "If this is production, you want to run `rails console` to rename your admin. Edit your category, and tag on-site."

# ============================================
# AI Ledger: Additional seeds
# ============================================

# Create AI Agent bot user
bot_pwd = SecureRandom.base58(32)
ai_agent = User.find_or_create_by!(username: "ai_agent") do |u|
  u.email = Rails.application.config.ai_ledger&.bot_email || "bot@theailedger.com"
  u.password = bot_pwd
  u.password_confirmation = bot_pwd
  u.is_bot = true
  u.bot_enabled = true
  u.requires_submission_approval = true
  u.karma = 100
  u.created_at = User::NEW_USER_DAYS.days.ago
end
# Update bot settings separately
ai_agent.update_column(:bot_settings, {
  "auto_submit_enabled" => true,
  "max_daily_submissions" => 50,
  "relevance_threshold" => 0.5,
  "preferred_tags" => ["machine-learning", "generative-ai", "fintech"],
  "excluded_domains" => []
}.to_json)
Rails.logger.debug "  * AI Agent bot user: #{ai_agent.username}"

# Create AI Ledger categories and tags
ai_category = Category.find_or_create_by!(category: "AI-Technology")
cu_category = Category.find_or_create_by!(category: "Credit-Union")
news_category = Category.find_or_create_by!(category: "Industry-News")
community_category = Category.find_or_create_by!(category: "Community")

ai_tags = [
  { tag: "machine-learning", description: "ML algorithms and models" },
  { tag: "generative-ai", description: "LLMs, ChatGPT, image generation" },
  { tag: "automation", description: "Process automation and RPA" },
  { tag: "nlp", description: "Natural language processing" },
  { tag: "computer-vision", description: "Image and video analysis" }
]

cu_tags = [
  { tag: "member-services", description: "Member experience and support" },
  { tag: "lending", description: "Loan processing and underwriting" },
  { tag: "fraud-detection", description: "Security and fraud prevention" },
  { tag: "compliance", description: "Regulatory and compliance" },
  { tag: "core-systems", description: "Core banking platforms" }
]

news_tags = [
  { tag: "fintech", description: "Financial technology" },
  { tag: "vendor", description: "Vendor announcements" },
  { tag: "regulation", description: "Regulatory updates" },
  { tag: "case-study", description: "Implementation stories" },
  { tag: "research", description: "Studies and reports" }
]

community_tags = [
  { tag: "ask", description: "Questions for the community", privileged: false },
  { tag: "show", description: "Show off your work", privileged: false },
  { tag: "meta", description: "About The AI Ledger", privileged: true }
]

[
  [ai_category, ai_tags],
  [cu_category, cu_tags],
  [news_category, news_tags],
  [community_category, community_tags]
].each do |category, tags|
  tags.each do |tag_attrs|
    Tag.find_or_create_by!(tag: tag_attrs[:tag]) do |t|
      t.category = category
      t.description = tag_attrs[:description]
      t.privileged = tag_attrs[:privileged] || false
    end
  end
end
Rails.logger.debug "  * AI Ledger categories and tags"

# Create initial RSS feeds
if defined?(RssFeed)
  feeds = [
    { name: "CU Today", url: "https://www.cutoday.info/rss", category: "credit_union" },
    { name: "Credit Union Times", url: "https://www.cutimes.com/feed/", category: "credit_union" },
    { name: "Finextra AI", url: "https://www.finextra.com/rss/channel.aspx?channel=AI", category: "fintech" },
    { name: "American Banker Tech", url: "https://www.americanbanker.com/feed?rss=true", category: "banking" },
    { name: "MIT Tech Review AI", url: "https://www.technologyreview.com/topic/artificial-intelligence/feed", category: "ai" },
    { name: "VentureBeat AI", url: "https://venturebeat.com/category/ai/feed/", category: "ai" },
    { name: "The Financial Brand", url: "https://thefinancialbrand.com/feed/", category: "banking" }
  ]

  feeds.each do |feed_data|
    RssFeed.find_or_create_by!(url: feed_data[:url]) do |f|
      f.name = feed_data[:name]
      f.category = feed_data[:category]
      f.active = true
    end
  end
  Rails.logger.debug "  * #{RssFeed.count} RSS feeds"
end

Rails.logger.debug
Rails.logger.debug "AI Ledger setup complete!"
