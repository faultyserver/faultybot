require 'yaml/store'

class ScheduleBot
  include Cinch::Plugin
  set :prefix, /^!/


  attr_accessor :schedules


  def initialize(*args)
    super

    @scheduledb = YAML::Store.new('events')
    # Ensure the required fields exist in the database
    @scheduledb.transaction do
      # Create separate storage for each channel
      $channels.keys.each do |channel_name|
        @scheduledb[channel_name.to_s] ||= {
          # `:events` is the actual hash of events, keyed by id
          events: {},
          # `:next_id` is the ID that will be assigned to the next quote
          next_id: 0
        }
      end
    end
  end


  # !quote [id]
  # !getquote [id]
  #
  # Get a quote from the database. If `id` is not given, pick one at random.
  match /schedule ?(.+)?/, method: :get_quote
  def get_schedule m, id=nil
    @scheduledb.transaction do
      debug m.channel.to_s
      channel_quotes = @scheduledb[m.channel.to_s]
      id ||= channel_quotes[:quotes].keys.sample
      quote = channel_quotes[:quotes][id.to_i]

      # Only reply if the quote exists
      if quote
        m.reply("(##{id}) \"#{quote[:text]}\" - #{quote[:author]} #{quote[:date].year}")
      else
        if id
          m.reply("There is no quote ##{id}.")
        else
          m.reply("There are no quotes :( Mods should add some with `!addquote`.")
        end
      end
    end
  end
end
