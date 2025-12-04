# frozen_string_literal: true

class AddBotUserFields < ActiveRecord::Migration[8.0]
  def change
    # Bot user identification
    add_column :users, :is_bot, :boolean, default: false, null: false
    add_column :users, :bot_enabled, :boolean, default: false, null: false
    add_column :users, :bot_settings, :json, default: {}

    add_index :users, :is_bot
    add_index :users, :bot_enabled
  end
end
