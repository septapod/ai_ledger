# frozen_string_literal: true

class AddSubmissionApprovalSystem < ActiveRecord::Migration[8.0]
  def change
    # User-level setting: whether this user's submissions require approval
    add_column :users, :requires_submission_approval, :boolean, default: false, null: false
    add_index :users, :requires_submission_approval

    # Story approval status
    add_column :stories, :approval_status, :string, limit: 20, default: "approved", null: false
    add_column :stories, :approved_at, :datetime
    add_column :stories, :approved_by_user_id, :bigint, unsigned: true
    add_column :stories, :rejection_reason, :text

    add_index :stories, :approval_status
    add_index :stories, [:approval_status, :created_at]
    add_foreign_key :stories, :users, column: :approved_by_user_id
  end
end
