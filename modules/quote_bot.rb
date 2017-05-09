require 'yaml/store'

class QuoteBot
  include Cinch::Plugin
  set :prefix, /^!/


  attr_accessor :quotes


  def initialize(*args)
    super

    @quotedb = YAML::Store.new('quotes')
    # Ensure the required fields exist in the database
    @quotedb.transaction do
      # Create separate storage for each channel
      $channels.keys.each do |channel_name|
        @quotedb[channel_name.to_s] ||= {
          # `:quotes` is the actual hash of quotes, keyed by id
          quotes: {},
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
  match /quote ?(\d+)?/,     method: :get_quote
  match /getquote ?(\d+)?/,  method: :get_quote
  def get_quote m, id=nil
    @quotedb.transaction do
      channel_quotes = @quotedb[m.channel.to_s]
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


  # !addquote "<quote>" <author>
  #
  # Add a new quote to the database, optionally including who said the quote.
  # Quotes will automatically be timestamped with the current datetime.
  match /addquote "(.+)" (\w+)/, method: :add_quote
  def add_quote m, text, author
    @quotedb.transaction do
      channel_quotes = @quotedb[m.channel.to_s]
      # Determine the ID to use for the quote
      id = channel_quotes[:next_id]
      quote = {
        text: text,
        author: author,
        date: Date.today
      }
      # Add the quote to the database...
      channel_quotes[:quotes][id] = quote
      channel_quotes[:next_id] += 1
      # ...and confirm that it was added
      m.reply("Added quote (##{id}) \"#{quote[:text]}\" - #{quote[:author]} #{quote[:date].year}")
    end
  end

  # !delquote <id>
  #
  # Remove the quote with the given id from the database.
  match /(?:del|remove)quote (\d+)/, method: :remove_quote
  def remove_quote m, id
    @quotedb.transaction do
      quote = @quotedb[m.channel.to_s][:quotes].delete(id.to_i)
      # Confirm the removal if the quote existed, or say that the quote did
      # not exist.
      if quote
        m.reply("Removed quote (##{id}) \"#{quote[:text]}\" - #{quote[:author]} #{quote[:date]}")
      else
        m.reply("There is no quote ##{id}.")
      end
    end
  end
end
