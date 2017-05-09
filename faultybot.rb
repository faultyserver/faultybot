require 'cinch'

$channels = YAML.load_file(".channels")
$passwords = YAML.load_file(".passwords")

require_relative 'modules/quote_bot'
require_relative 'modules/schedule_bot'
require_relative 'modules/misc_commands'

bot = Cinch::Bot.new do
  configure do |c|
    c.server          = "irc.chat.twitch.tv"
    c.channels        = $channels.keys
    c.nick            = "faultybot"
    c.password        = $passwords['oauth']
    c.verbose         = true

    c.plugins.plugins = [
      QuoteBot,
      MiscCommands
    ]
  end
end

bot.start
