# frozen_string_literal: true

class Mod::QueueController < Mod::ModController
  before_action :set_story, only: [:approve, :reject]

  def index
    @title = "Approval Queue"
    @cur = "queue"
    @pending_stories = Story.pending_approval
      .includes(:user, :tags, :domain)
      .order(created_at: :asc)
      .page(params[:page])
      .per(25)

    @counts = {
      pending: Story.pending_approval.count,
      approved_today: Story.approved_stories.where("approved_at > ?", 24.hours.ago).count,
      rejected_today: Story.rejected_stories.where("updated_at > ?", 24.hours.ago).count
    }
  end

  def approve
    @story.approve!(@user)

    flash[:success] = "Story \"#{@story.title.truncate(50)}\" approved and now visible."
    redirect_to mod_queue_index_path
  end

  def reject
    reason = params[:reason].presence || "Does not meet submission guidelines"

    @story.reject!(@user, reason: reason)

    flash[:success] = "Story rejected."
    redirect_to mod_queue_index_path
  end

  # Bulk approve multiple stories
  def bulk_approve
    story_ids = params[:story_ids] || []
    approved_count = 0

    Story.pending_approval.where(short_id: story_ids).find_each do |story|
      story.approve!(@user)
      approved_count += 1
    end

    flash[:success] = "#{approved_count} stories approved."
    redirect_to mod_queue_index_path
  end

  private

  def set_story
    @story = Story.find_by!(short_id: params[:story_id])
  end
end
