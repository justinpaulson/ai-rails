module MessagesHelper
  def message_container_classes(message)
    case message.role
    when "user"
      "flex justify-end"
    when "assistant"
      "flex justify-start"
    else
      "flex justify-center"
    end
  end

  def message_bubble_classes(message)
    base = "rounded-lg p-4 max-w-full md:max-w-2xl break-words"

    case message.role
    when "user"
      "#{base} bg-blue-600 text-white"
    when "assistant"
      "#{base} bg-gray-100 text-gray-900"
    else
      "#{base} bg-gray-50 text-gray-600"
    end
  end

  def grouped_messages(messages)
    result = []
    tool_results_by_id = messages.select(&:tool_result?).index_by(&:tool_use_id)

    messages.each do |message|
      next if message.tool_result?

      if message.tool_use?
        result << {
          type: :tool_call,
          tool_use: message,
          tool_result: tool_results_by_id[message.tool_use_id]
        }
      else
        result << { type: :message, message: message }
      end
    end

    result
  end

  def tool_status_icon(has_result)
    if has_result
      '<svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
      </svg>'.html_safe
    else
      '<svg class="w-4 h-4 text-amber-600 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>'.html_safe
    end
  end

  def format_tool_input(tool_use)
    input = tool_use.tool_input_parsed
    return "" if input.blank?

    case tool_use.tool_name
    when "Read"
      input["file_path"] || JSON.pretty_generate(input)
    when "Bash"
      input["command"] || JSON.pretty_generate(input)
    when "Write", "Edit"
      "#{input['file_path']}\n\n#{input['content'] || input['new_string']}".truncate(500)
    when "Glob"
      input["pattern"] || JSON.pretty_generate(input)
    when "Grep"
      "#{input['pattern']} #{input['path']}".strip
    else
      JSON.pretty_generate(input)
    end
  rescue
    tool_use.tool_input.to_s
  end

  def tool_context_preview(tool_use)
    input = tool_use.tool_input_parsed
    return nil if input.blank?

    preview = case tool_use.tool_name
    when "Read", "Write", "Edit"
      shorten_path(input["file_path"])
    when "Bash"
      input["command"]&.truncate(60)
    when "Glob"
      input["pattern"]
    when "Grep"
      input["pattern"]&.truncate(40)
    when "Task"
      input["description"]&.truncate(50)
    when "TodoWrite"
      count = input["todos"]&.length || 0
      "#{count} item#{'s' if count != 1}"
    when "WebFetch", "WebSearch"
      input["url"] || input["query"]
    end

    preview.presence
  rescue
    nil
  end

  def shorten_path(path)
    return nil unless path
    parts = path.split("/")
    return path if parts.length <= 3
    ".../" + parts.last(2).join("/")
  end

  def first_user_message?(message)
    return false unless message.user? && message.text?
    message.conversation.messages.where(role: :user, message_type: :text).order(:created_at).first&.id == message.id
  end
end
