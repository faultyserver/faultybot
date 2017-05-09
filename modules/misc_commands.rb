require 'yaml/store'

class MiscCommands
  include Cinch::Plugin
  set :prefix, /^!/


  def initialize(*args)
    super

    @commandsdb = YAML::Store.new('commands')
    # Ensure the required fields exist in the database
    @commandsdb.transaction do
      # Create separate storage for each channel
      $channels.keys.each do |channel_name|
        @commandsdb[channel_name.to_s] ||= {}
      end
    end
  end


  # !addcommand <name> <response>
  #
  # Add a new text command to reply with the given response. Commands can
  # be invoked with `!name`, where `name` is the name of the command.
  #
  # Commands can only be added by channel admins.
  match /addcommand (\w+) (.+)/,     method: :add_command
  def add_command m, name, response
    channel = m.channel.to_s
    return unless user_is_admin(channel, m.user)

    @commandsdb.transaction do
      channel_commands = @commandsdb[channel]

      channel_commands[name] = response
      m.reply("Added command '!#{name}'.")
    end
  end


  # !delcommand <name>
  # !removecommand <name>
  #
  # Remove the given command from the database.
  #
  # Commands can only be added by channel admins.
  match /(?:del|remove)command (\w+)/, method: :remove_command
  def remove_command m, name
    channel = m.channel.to_s
    return unless user_is_admin(channel, m.user)

    @commandsdb.transaction do
      command = @commandsdb[channel].delete(name)
      # Confirm the removal if the command existed, or say that the command did
      # not exist.
      if command
        m.reply("Removed command '!#{name}'.")
      else
        m.reply("There is no command '!#{name}'.")
      end
    end
  end

  # !commands
  # !listcommands
  #
  # Return the list of registered commands. This only returns the custom
  # commands defined through !addcommand.
  match /commands/, method: :list_commands
  match /listcommands/, method: :list_commands
  def list_commands m
    channel = m.channel.to_s
    @commandsdb.transaction do
      commands = @commandsdb[channel].keys

      if commands.empty?
        m.reply("There are no custom commands registered for this channel.")
      else
        m.reply("Available commands: " + commands.map{ |c| "!#{c}" }.join(", "))
      end
    end
  end

  # !<command>
  #
  # Attempt to perform the given command. This matches any single-word command,
  # and can be called by anyone.
  #
  # If no command is found, a simple "command not found" is returned.
  match /!((?!addcommand|delcommand|removecommand|commands)\w+)/, method: :attempt_command, use_prefix: false
  def attempt_command m, command
    channel = m.channel.to_s

    @commandsdb.transaction do
      response = @commandsdb[channel][command]

      if response
        m.reply(response)
      else
        m.reply("Command '!#{command}' not found.")
      end
    end
  end

  private

    def user_is_admin channel, user
      $channels[channel][:admins].include?(user.to_s)
    end
end
