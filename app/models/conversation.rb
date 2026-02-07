class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  enum :status, { active: "active", completed: "completed", error: "error" }, default: :active

  validates :working_directory, presence: true

  before_create :set_defaults
  after_update_commit :broadcast_stop_button, if: :saved_change_to_pid?

  def display_title
    title.presence || "New Conversation"
  end

  def current_todos
    todos || []
  end

  def has_todos?
    current_todos.any?
  end

  def update_todos!(new_todos)
    update!(todos: new_todos)
    broadcast_todo_update
  end

  def broadcast_todo_update
    Turbo::StreamsChannel.broadcast_replace_to(
      self,
      target: "todo-list",
      partial: "conversations/todo_list",
      locals: { conversation: self }
    )
  end

  def broadcast_stop_button
    Turbo::StreamsChannel.broadcast_replace_to(
      self,
      target: "stop-button",
      partial: "conversations/stop_button",
      locals: { conversation: self }
    )
  end

  def running?
    pid.present?
  end

  private

  def set_defaults
    self.title ||= "New Conversation"
    self.todos ||= []
  end
end
