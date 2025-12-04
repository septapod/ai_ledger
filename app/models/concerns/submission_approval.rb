# frozen_string_literal: true

# Submission approval functionality for stories
module SubmissionApproval
  extend ActiveSupport::Concern

  included do
    belongs_to :approved_by,
      class_name: "User",
      foreign_key: "approved_by_user_id",
      inverse_of: :approved_stories,
      optional: true

    # Approval status scopes
    scope :pending_approval, -> { where(approval_status: "pending") }
    scope :approved_stories, -> { where(approval_status: "approved") }
    scope :rejected_stories, -> { where(approval_status: "rejected") }

    # Visible stories are approved and not deleted
    scope :visible, -> { approved_stories.where(is_deleted: false) }

    before_create :set_initial_approval_status

    validates :approval_status, inclusion: {in: %w[pending approved rejected]}
  end

  # Check if story is pending approval
  def approval_pending?
    approval_status == "pending"
  end

  # Check if story is approved
  def approval_approved?
    approval_status == "approved"
  end

  # Check if story is rejected
  def approval_rejected?
    approval_status == "rejected"
  end

  # Approve the story
  def approve!(moderator)
    transaction do
      update!(
        approval_status: "approved",
        approved_at: Time.current,
        approved_by_user_id: moderator.id
      )

      Moderation.create!(
        story: self,
        moderator_user_id: moderator.id,
        user_id: user_id,
        action: "approved submission"
      )
    end
  end

  # Reject the story
  def reject!(moderator, reason: nil)
    transaction do
      update!(
        approval_status: "rejected",
        rejection_reason: reason
      )

      Moderation.create!(
        story: self,
        moderator_user_id: moderator.id,
        user_id: user_id,
        action: "rejected submission",
        reason: reason
      )

      # Notify the submitting user
      if user && reason.present?
        Message.create!(
          author_user_id: moderator.id,
          recipient_user_id: user_id,
          subject: "Your submission was not approved",
          body: "Your story \"#{title}\" was not approved.\n\nReason: #{reason}"
        )
      end
    end
  end

  private

  def set_initial_approval_status
    if user&.submissions_require_approval? || user&.is_bot_user?
      self.approval_status = "pending"
    else
      self.approval_status = "approved"
      self.approved_at = Time.current
    end
  end
end
