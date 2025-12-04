# frozen_string_literal: true

# User settings for submission approval
module UserApprovalSettings
  extend ActiveSupport::Concern

  # Check if this user's submissions require approval
  def submissions_require_approval?
    requires_submission_approval? || is_bot_user?
  end

  # Toggle approval requirement for a user (admin action)
  def toggle_approval_requirement!(moderator)
    new_status = !requires_submission_approval

    transaction do
      update!(requires_submission_approval: new_status)

      action = new_status ? "enabled submission approval" : "disabled submission approval"
      Moderation.create!(
        moderator_user_id: moderator.id,
        user_id: id,
        action: action
      )
    end

    new_status
  end
end
