require "open3"
require "json"

class ClaudeCodeService
  attr_reader :conversation, :allowed_tools

  def initialize(conversation, allowed_tools: nil)
    @conversation = conversation
    @allowed_tools = allowed_tools
  end

  def self.stop(conversation)
    return false unless conversation.pid.present?

    pid = conversation.pid

    begin
      Process.kill("TERM", -pid)
      Rails.logger.info "[ClaudeCode] Sent SIGTERM to process group #{pid}"

      sleep(0.5)
      begin
        Process.kill(0, pid)
        Process.kill("KILL", -pid)
        Rails.logger.info "[ClaudeCode] Sent SIGKILL to process group #{pid}"
      rescue Errno::ESRCH
        # Already dead
      end

      conversation.update!(pid: nil, status: :completed)
      conversation.messages.create!(
        role: :system,
        message_type: :text,
        content: "Session stopped by user"
      )
      true
    rescue Errno::ESRCH
      conversation.update!(pid: nil)
      false
    rescue Errno::EPERM => e
      Rails.logger.error "[ClaudeCode] Permission denied stopping process: #{e.message}"
      false
    end
  end

  def send_message(prompt)
    command = build_command(prompt)

    Rails.logger.info "[ClaudeCode] Executing: #{command.join(' ')}"

    working_dir = File.expand_path(conversation.working_directory)
    clean_env = ENV.to_h.except("BUNDLE_GEMFILE", "BUNDLE_LOCKFILE", "BUNDLE_PATH", "BUNDLE_APP_CONFIG")

    Open3.popen3(clean_env, *command, chdir: working_dir, pgroup: true, unsetenv_others: false) do |stdin, stdout, stderr, wait_thread|
      conversation.update!(pid: wait_thread.pid)
      Rails.logger.info "[ClaudeCode] Started process with PID #{wait_thread.pid}"

      stdin.close

      stdout.each_line do |line|
        process_stream_line(line.strip)
      end

      stderr_output = stderr.read
      if stderr_output.present?
        Rails.logger.error "[ClaudeCode] stderr: #{stderr_output}"
      end

      exit_status = wait_thread.value
      handle_completion(exit_status)
    end
  rescue => e
    Rails.logger.error "[ClaudeCode] Error: #{e.message}"
    handle_error(e)
  ensure
    conversation.update!(pid: nil) if conversation.pid.present?
  end

  private

  def build_command(prompt)
    tools = allowed_tools || default_allowed_tools

    cmd = [
      "claude",
      "--output-format", "stream-json",
      "--verbose",
      "--allowed-tools", tools
    ]

    if conversation.session_id.present?
      cmd += ["--resume", conversation.session_id]
    end

    cmd += ["-p", prompt]
    cmd
  end

  def default_allowed_tools
    [
      "Read", "Glob", "Grep", "Edit", "Write",
      "Bash(git:*,bundle:*,npm:*,yarn:*,pnpm:*,rails:*,rake:*,rspec:*,jest:*,pytest:*,cargo:*,go:test,docker:ps,docker:logs,gh:*)"
    ].join(" ")
  end

  def process_stream_line(line)
    return if line.blank?

    begin
      event = JSON.parse(line)
      handle_event(event)
    rescue JSON::ParserError => e
      Rails.logger.warn "[ClaudeCode] Failed to parse JSON: #{line}"
    end
  end

  def handle_event(event)
    case event["type"]
    when "system"
      handle_system_event(event)
    when "assistant"
      handle_assistant_event(event)
    when "user"
      handle_user_event(event)
    when "result"
      handle_result_event(event)
    else
      Rails.logger.debug "[ClaudeCode] Unknown event type: #{event['type']}"
    end
  end

  def handle_system_event(event)
    if event["subtype"] == "init"
      if event["session_id"].present?
        conversation.update!(session_id: event["session_id"])
      end

      conversation.messages.create!(
        role: :system,
        message_type: :system_init,
        content: "Session initialized",
        tool_input: { tools: event["tools"] }
      )
    end
  end

  def handle_assistant_event(event)
    message = event["message"]
    return unless message && message["content"]

    message["content"].each do |content_block|
      case content_block["type"]
      when "text"
        create_or_update_text_message(content_block["text"])
      when "tool_use"
        conversation.messages.create!(
          role: :assistant,
          message_type: :tool_use,
          content: "Using #{content_block['name']}",
          tool_name: content_block["name"],
          tool_use_id: content_block["id"],
          tool_input: content_block["input"]
        )
      end
    end
  end

  def handle_user_event(event)
    message = event["message"]
    return unless message && message["content"]

    message["content"].each do |content_block|
      if content_block["type"] == "tool_result"
        tool_use_msg = conversation.messages.find_by(tool_use_id: content_block["tool_use_id"])

        conversation.messages.create!(
          role: :user,
          message_type: :tool_result,
          content: truncate_content(content_block["content"]),
          tool_use_id: content_block["tool_use_id"],
          tool_name: tool_use_msg&.tool_name
        )
      end
    end
  end

  def handle_result_event(event)
    conversation.messages.create!(
      role: :system,
      message_type: :result,
      content: "Completed",
      tool_input: {
        cost_usd: event["cost_usd"],
        duration_ms: event["duration_ms"],
        num_turns: event["num_turns"],
        session_id: event["session_id"]
      }
    )

    if event["session_id"].present?
      conversation.update!(session_id: event["session_id"])
    end

    conversation.update!(status: :completed)
  end

  def create_or_update_text_message(text)
    last_msg = conversation.messages.where(role: :assistant, message_type: :text).last

    if last_msg && last_msg.created_at > 5.seconds.ago
      last_msg.update!(content: last_msg.content.to_s + text)
    else
      conversation.messages.create!(
        role: :assistant,
        message_type: :text,
        content: text
      )
    end
  end

  def truncate_content(content)
    return content unless content.is_a?(String)
    content.truncate(10_000)
  end

  def handle_completion(exit_status)
    if exit_status.success?
      conversation.update!(status: :completed)
    else
      conversation.update!(status: :error)
    end
  end

  def handle_error(error)
    conversation.messages.create!(
      role: :system,
      message_type: :text,
      content: "Error: #{error.message}"
    )
    conversation.update!(status: :error)
  end
end
