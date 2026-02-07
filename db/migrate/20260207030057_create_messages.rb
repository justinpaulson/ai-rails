class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role
      t.string :message_type
      t.text :content
      t.string :tool_name
      t.string :tool_use_id
      t.json :tool_input

      t.timestamps
    end
  end
end
