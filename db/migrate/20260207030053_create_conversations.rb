class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :session_id
      t.string :title
      t.string :status, default: "active"
      t.string :working_directory
      t.integer :pid
      t.json :todos

      t.timestamps
    end
  end
end
