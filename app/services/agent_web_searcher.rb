# frozen_string_literal: true

# Searches the web for content matching an Agent's criteria
# Uses Claude for intelligent web searching
class AgentWebSearcher
  def initialize(agent, agent_run)
    @agent = agent
    @agent_run = agent_run
    @queries = agent.web_search_queries
  end

  def search
    return 0 if @queries.empty?

    Rails.logger.info "[AgentWebSearcher] Searching with #{@queries.size} queries..."

    total_candidates = 0

    @queries.each do |query|
      results = search_query(query)
      candidates_created = process_results(results)
      total_candidates += candidates_created

      Rails.logger.info "[AgentWebSearcher] Query '#{query}': #{candidates_created} candidates"

      # Small delay between queries to be polite
      sleep(1)
    end

    total_candidates
  rescue => e
    Rails.logger.error "[AgentWebSearcher] Error: #{e.message}"
    0
  end

  private

  def search_query(query)
    # Use Anthropic Claude to search the web
    # This leverages Claude's web search capabilities
    client = anthropic_client
    return [] unless client

    begin
      response = client.messages.create(
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        messages: [
          {
            role: "user",
            content: search_prompt(query)
          }
        ]
      )

      parse_search_response(response)
    rescue => e
      Rails.logger.error "[AgentWebSearcher] Claude search error: #{e.message}"
      []
    end
  end

  def search_prompt(query)
    <<~PROMPT
      Search the web for recent news articles and blog posts about: #{query}

      Focus on:
      - Articles from the last 7 days
      - Authoritative sources (industry publications, major news outlets, company blogs)
      - Content that would be valuable for professionals in the credit union and financial services industry

      Return up to 10 results in this exact JSON format:
      [
        {
          "url": "https://example.com/article",
          "title": "Article Title",
          "description": "Brief description of the article content"
        }
      ]

      Only return the JSON array, no other text.
    PROMPT
  end

  def parse_search_response(response)
    text = response.content.first.text

    # Extract JSON from response
    json_match = text.match(/\[[\s\S]*\]/)
    return [] unless json_match

    results = JSON.parse(json_match[0])

    # Validate results
    results.select do |r|
      r["url"].present? && r["title"].present?
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[AgentWebSearcher] JSON parse error: #{e.message}"
    []
  end

  def process_results(results)
    count = 0

    results.each do |result|
      url = result["url"]
      next if already_candidate?(url)
      next if already_posted?(url)

      AgentCandidate.create_from_web_result!(
        agent: @agent,
        agent_run: @agent_run,
        url: url,
        title: result["title"],
        content: result["description"]
      )
      count += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[AgentWebSearcher] Failed to create candidate: #{e.message}"
    end

    count
  end

  def already_candidate?(url)
    AgentCandidate.exists_for_agent?(agent: @agent, url: url)
  end

  def already_posted?(url)
    normalized = Utils.normalize_url(url)
    Story.where(normalized_url: normalized).exists?
  rescue
    false
  end

  def anthropic_client
    @client ||= begin
      api_key = Rails.application.credentials.dig(:anthropic, :api_key) ||
                ENV["ANTHROPIC_API_KEY"]
      return nil unless api_key

      Anthropic::Client.new(access_token: api_key)
    end
  end
end
