# frozen_string_literal: true

# Seed data for AI Agents
# Run with: bin/rails runner db/seeds/agents.rb

puts "Creating AI Agents..."

# Define 3 agents with different configurations
agents_config = [
  {
    username: "agent_daily_digest",
    email: "daily@ailedger.local",
    name: "Daily AI Digest",
    description: "Curates top AI in finance and credit union stories. Runs once daily to provide a comprehensive overview of the most important news.",
    schedule_interval: "daily",
    posts_per_run: 20,
    max_daily_posts: 25,
    trust_level: "trusted",
    search_config: {
      "rss_feeds" => [],  # Will be populated with all active feeds
      "web_search_enabled" => true,
      "web_search_queries" => [
        "AI in banking 2025",
        "machine learning credit union",
        "artificial intelligence financial services",
        "fintech AI innovation"
      ],
      "required_keywords" => ["ai", "machine learning", "artificial intelligence"],
      "excluded_keywords" => ["crypto", "nft", "bitcoin", "meme"],
      "max_age_hours" => 48
    },
    quality_config: {
      "relevance_threshold" => 0.5,
      "llm_vetting_enabled" => true,
      "llm_min_score" => 0.65,
      "max_candidates_for_llm" => 30,
      "trusted_domains" => ["ieee.org", "acm.org", "ncua.gov", "cuna.org", "nafcu.org"]
    }
  },
  {
    username: "agent_breaking_news",
    email: "breaking@ailedger.local",
    name: "Breaking News Bot",
    description: "Fast-moving AI news tracker. Runs hourly to catch breaking announcements and product launches in the AI space.",
    schedule_interval: "hourly",
    posts_per_run: 5,
    max_daily_posts: 50,
    trust_level: "review",
    search_config: {
      "rss_feeds" => [],
      "web_search_enabled" => true,
      "web_search_queries" => [
        "ChatGPT announcement today",
        "AI news today",
        "OpenAI news",
        "Google AI announcement",
        "Microsoft AI update"
      ],
      "required_keywords" => ["ai", "chatgpt", "gpt", "llm", "claude", "gemini"],
      "excluded_keywords" => ["crypto", "nft", "dating"],
      "max_age_hours" => 24
    },
    quality_config: {
      "relevance_threshold" => 0.4,
      "llm_vetting_enabled" => false,
      "llm_min_score" => 0.7,
      "max_candidates_for_llm" => 10,
      "trusted_domains" => ["theverge.com", "techcrunch.com", "wired.com", "arstechnica.com"]
    }
  },
  {
    username: "agent_deep_dives",
    email: "deepdives@ailedger.local",
    name: "Deep Dives Curator",
    description: "In-depth technical AI content for practitioners. Runs every 6 hours focusing on research papers, technical blogs, and detailed analysis.",
    schedule_interval: "6_hours",
    posts_per_run: 10,
    max_daily_posts: 30,
    trust_level: "review",
    search_config: {
      "rss_feeds" => [],
      "web_search_enabled" => true,
      "web_search_queries" => [
        "machine learning research paper 2025",
        "AI architecture deep dive",
        "transformer model technical",
        "LLM fine-tuning guide",
        "AI system design"
      ],
      "required_keywords" => ["research", "paper", "technical", "architecture", "model"],
      "excluded_keywords" => ["crypto", "advertisement", "sponsored"],
      "max_age_hours" => 168  # One week for research content
    },
    quality_config: {
      "relevance_threshold" => 0.6,
      "llm_vetting_enabled" => true,
      "llm_min_score" => 0.75,
      "max_candidates_for_llm" => 15,
      "trusted_domains" => ["arxiv.org", "github.com", "huggingface.co", "deepmind.com", "openai.com"]
    }
  }
]

# Get all active RSS feeds for assignment
active_feed_ids = RssFeed.active.pluck(:id)

agents_config.each do |config|
  puts "  Creating agent: #{config[:name]}..."

  # Find or create the bot user
  user = User.find_or_initialize_by(username: config[:username])
  if user.new_record?
    user.email = config[:email]
    user.password = SecureRandom.hex(32)
    user.is_bot = true
    user.bot_enabled = true
    user.save!
    puts "    Created user: @#{user.username}"
  else
    puts "    Found existing user: @#{user.username}"
  end

  # Find or create the agent
  agent = Agent.find_or_initialize_by(user: user)

  # Update search config with actual feed IDs
  search_config = config[:search_config].dup
  search_config["rss_feeds"] = active_feed_ids

  agent.assign_attributes(
    name: config[:name],
    description: config[:description],
    enabled: false,  # Start disabled - admin must enable
    schedule_interval: config[:schedule_interval],
    posts_per_run: config[:posts_per_run],
    max_daily_posts: config[:max_daily_posts],
    trust_level: config[:trust_level],
    search_config: search_config.to_json,
    quality_config: config[:quality_config].to_json
  )

  if agent.new_record?
    agent.save!
    puts "    Created agent: #{agent.name}"

    # Assign RSS feeds
    active_feed_ids.each do |feed_id|
      AgentRssFeed.create!(agent: agent, rss_feed_id: feed_id)
    end
    puts "    Assigned #{active_feed_ids.count} RSS feeds"
  else
    agent.save!
    puts "    Updated agent: #{agent.name}"
  end
end

puts "\nAgent seeding complete!"
puts "Created #{Agent.count} agents."
puts "\nNOTE: Agents are created DISABLED. Enable them via the admin dashboard:"
puts "  /admin/agents"
puts "\nTo enable an agent, click 'Enable' on the agents list."
