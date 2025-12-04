# frozen_string_literal: true

class Admin::BotController < ApplicationController
  before_action :require_logged_in_admin
  before_action :load_bot_user

  def show
    @title = "AI Agent Settings"
    @recent_submissions = @bot_user.stories.order(created_at: :desc).limit(20)
    @daily_stats = {
      submissions_today: @bot_user.daily_submission_count,
      pending: @bot_user.stories.pending_approval.count,
      approved_today: @bot_user.stories.approved_stories.where("approved_at > ?", 24.hours.ago).count,
      rejected_today: @bot_user.stories.rejected_stories.where("updated_at > ?", 24.hours.ago).count
    }
  end

  def update
    if @bot_user.update(bot_params)
      # Update bot_settings separately
      if params[:bot_settings].present?
        new_settings = @bot_user.bot_settings || {}
        new_settings["auto_submit_enabled"] = params[:bot_settings][:auto_submit_enabled] == "1"
        new_settings["max_daily_submissions"] = params[:bot_settings][:max_daily_submissions].to_i
        new_settings["relevance_threshold"] = params[:bot_settings][:relevance_threshold].to_f
        @bot_user.update!(bot_settings: new_settings)
      end

      flash[:success] = "Bot settings updated successfully."
    else
      flash[:error] = "Failed to update bot settings: #{@bot_user.errors.full_messages.join(", ")}"
    end
    redirect_to admin_bot_path
  end

  def toggle
    @bot_user.update!(bot_enabled: !@bot_user.bot_enabled)
    status = @bot_user.bot_enabled? ? "enabled" : "disabled"
    flash[:success] = "AI Agent #{status}."
    redirect_to admin_bot_path
  end

  private

  def load_bot_user
    @bot_user = User.ai_agent
    unless @bot_user
      flash[:error] = "AI Agent user not found. Please run database seeds."
      redirect_to root_path
    end
  end

  def bot_params
    params.require(:user).permit(:bot_enabled)
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
