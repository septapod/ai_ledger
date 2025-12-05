class AddImageUrlToStories < ActiveRecord::Migration[8.0]
  def change
    add_column :stories, :image_url, :string, limit: 500
    add_index :stories, :image_url
  end
end
