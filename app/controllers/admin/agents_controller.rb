# frozen_string_literal: true

class Admin::AgentsController < ApplicationController
  before_action :require_logged_in_admin
  before_action :set_agent, only: [:show, :edit, :update, :destroy, :toggle, :run_now, :activity]

  def index
    @title = "Agent Management"
    @agents = Agent.includes(:user).order(enabled: :desc, name: :asc)
    @stats = {
      total: Agent.count,
      active: Agent.active.count,
      posts_today: Story.where(agent_id: Agent.pluck(:id))
                        .where("created_at > ?", 24.hours.ago).count,
      runs_today: AgentRun.where("created_at > ?", 24.hours.ago).count
    }
  end

  def show
    @title = @agent.name
    @recent_runs = @agent.agent_runs.order(created_at: :desc).limit(10)
    @recent_candidates = @agent.agent_candidates.order(created_at: :desc).limit(20)
    @agent_stats = {
      total_runs: @agent.run_count,
      total_posts: @agent.post_count,
      posts_today: @agent.daily_post_count,
      success_rate: @agent.success_rate
    }
  end

  def new
    @title = "Create New Agent"
    @agent = Agent.new(
      schedule_interval: "daily",
      posts_per_run: 10,
      max_daily_posts: 50,
      trust_level: "review"
    )
    @rss_feeds = RssFeed.active.order(:name)
  end

  def create
    @agent = build_agent_with_user
    if @agent.save
      assign_rss_feeds
      flash[:success] = "Agent \"#{@agent.name}\" created successfully."
      redirect_to admin_agent_path(@agent)
    else
      @title = "Create New Agent"
      @rss_feeds = RssFeed.active.order(:name)
      render :new
    end
  end

  def edit
    @title = "Edit #{@agent.name}"
    @rss_feeds = RssFeed.active.order(:name)
  end

  def update
    if @agent.update(agent_params)
      update_search_config
      update_quality_config
      assign_rss_feeds
      flash[:success] = "Agent updated successfully."
      redirect_to admin_agent_path(@agent)
    else
      @title = "Edit #{@agent.name}"
      @rss_feeds = RssFeed.active.order(:name)
      render :edit
    end
  end

  def destroy
    name = @agent.name
    @agent.destroy
    flash[:success] = "Agent \"#{name}\" deleted."
    redirect_to admin_agents_path
  end

  def toggle
    @agent.update!(enabled: !@agent.enabled?)
    status = @agent.enabled? ? "enabled" : "disabled"
    flash[:success] = "Agent \"#{@agent.name}\" #{status}."
    redirect_to admin_agents_path
  end

  def run_now
    if @agent.enabled?
      @agent.update!(next_run_at: Time.current)
      AgentExecutionJob.perform_later(@agent.id)
      flash[:success] = "Execution job queued for \"#{@agent.name}\"."
    else
      flash[:error] = "Cannot run disabled agent. Enable it first."
    end
    redirect_to admin_agent_path(@agent)
  end

  def activity
    @title = "#{@agent.name} - Activity"
    @runs = @agent.agent_runs.order(created_at: :desc).page(params[:page]).per(25)
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(
      :name, :description, :enabled, :schedule_interval,
      :posts_per_run, :max_daily_posts, :trust_level
    )
  end

  def build_agent_with_user
    agent = Agent.new(agent_params)

    # Create a bot user for this agent
    username = "agent_#{params[:agent][:username].presence || SecureRandom.hex(4)}"
    email = "#{username}@ailedger.local"

    user = User.create!(
      username: username,
      email: email,
      password: SecureRandom.hex(32),
      is_bot: true,
      bot_enabled: true
    )

    agent.user = user
    update_search_config(agent)
    update_quality_config(agent)
    agent
  end

  def update_search_config(agent = @agent)
    agent.search_config = {
      "rss_feeds" => (params[:rss_feed_ids] || []).map(&:to_i),
      "web_search_enabled" => params[:web_search_enabled] == "1",
      "web_search_queries" => (params[:web_search_queries].to_s.split("\n").map(&:strip).reject(&:blank?)),
      "required_keywords" => (params[:required_keywords].to_s.split(",").map(&:strip).reject(&:blank?)),
      "excluded_keywords" => (params[:excluded_keywords].to_s.split(",").map(&:strip).reject(&:blank?)),
      "max_age_hours" => (params[:max_age_hours].presence || 72).to_i
    }
  end

  def update_quality_config(agent = @agent)
    agent.quality_config = {
      "relevance_threshold" => (params[:relevance_threshold].presence || 0.5).to_f,
      "llm_vetting_enabled" => params[:llm_vetting_enabled] == "1",
      "llm_min_score" => (params[:llm_min_score].presence || 0.7).to_f,
      "max_candidates_for_llm" => (params[:max_candidates_for_llm].presence || 20).to_i,
      "trusted_domains" => (params[:trusted_domains].to_s.split("\n").map(&:strip).reject(&:blank?))
    }
  end

  def assign_rss_feeds
    feed_ids = (params[:rss_feed_ids] || []).map(&:to_i).reject(&:zero?)

    # Clear existing and add new
    @agent.agent_rss_feeds.destroy_all
    feed_ids.each do |feed_id|
      @agent.agent_rss_feeds.create(rss_feed_id: feed_id)
    end
  end

  def require_logged_in_admin
    if @user.nil?
      flash[:error] = "You must be logged in to access that."
      redirect_to login_path
    elsif !@user.is_admin?
      flash[:error] = "You must be an admin to access that."
      redirect_to root_path
    end
  end
end
