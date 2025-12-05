# frozen_string_literal: true

# Uses Claude to analyze content quality and relevance
class LlmQualityAnalyzer
  PROMPT_TEMPLATE = <<~PROMPT
    Analyze this article for a credit union industry AI news site.

    Title: %{title}
    URL: %{url}
    Content: %{content}

    Rate from 0.0 to 1.0 on:
    - Relevance to AI/ML in financial services (0.0-1.0)
    - Quality and authority of source (0.0-1.0)
    - Novelty and timeliness (0.0-1.0)
    - Actionable insights for credit union professionals (0.0-1.0)

    Return ONLY a JSON object with this exact format:
    {
      "score": 0.75,
      "reasoning": "Brief explanation of the score",
      "relevance": 0.8,
      "quality": 0.7,
      "novelty": 0.6,
      "actionability": 0.9
    }
  PROMPT

  def initialize(candidate, agent)
    @candidate = candidate
    @agent = agent
  end

  def analyze
    Rails.logger.info "[LlmQualityAnalyzer] Analyzing: #{@candidate.truncated_title}"

    response = call_claude
    return default_result unless response

    parse_response(response)
  rescue => e
    Rails.logger.error "[LlmQualityAnalyzer] Error: #{e.message}"
    default_result
  end

  private

  def call_claude
    client = anthropic_client
    return nil unless client

    prompt = format(PROMPT_TEMPLATE,
      title: @candidate.title.to_s[0..200],
      url: @candidate.url,
      content: truncated_content)

    response = client.messages.create(
      model: "claude-3-5-haiku-20241022",
      max_tokens: 300,
      messages: [
        {role: "user", content: prompt}
      ]
    )

    response.content.first.text
  end

  def parse_response(text)
    # Extract JSON from response
    json_match = text.match(/\{[\s\S]*\}/)
    return default_result unless json_match

    result = JSON.parse(json_match[0])

    {
      score: result["score"].to_f,
      reasoning: result["reasoning"].to_s,
      relevance: result["relevance"].to_f,
      quality: result["quality"].to_f,
      novelty: result["novelty"].to_f,
      actionability: result["actionability"].to_f
    }
  rescue JSON::ParserError => e
    Rails.logger.error "[LlmQualityAnalyzer] JSON parse error: #{e.message}"
    default_result
  end

  def truncated_content
    content = @candidate.content.to_s
    # Limit to ~2000 chars to save tokens
    content[0..2000]
  end

  def default_result
    {
      score: 0.5,
      reasoning: "Analysis failed, using default score",
      relevance: 0.5,
      quality: 0.5,
      novelty: 0.5,
      actionability: 0.5
    }
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
