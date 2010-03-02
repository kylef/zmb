class Quote
  attr_accessor :quotes, :autoindex
  
  def initialize(sender, settings={})
    @quotes = Hash.new
    @quotes = settings['quotes'] if settings.has_key?('quotes')
    @autoindex = 1
    @autoindex = settings['autoindex'] if settings.has_key?('autoindex')
  end
  
  def to_json(*a)
    {
      'plugin' => 'quote',
      'quotes' => @quotes,
      'autoindex' => @autoindex,
    }.to_json(*a)
  end
  
  def add(quote, username=nil)
    @quotes["#{@autoindex}"] = {
      'quote' => quote,
      'time' => Time.now,
      'username' => username,
    }
    
    @autoindex += 1
    @autoindex - 1
  end
  
  def count
    @quotes.keys.count
  end
  
  def commands
    require 'zmb/commands'
    {
      'quote' => Command.new(self, :quote_command, 1, 'Show a random quote or the quote with matching id'),
      'quote-add' => Command.new(self, :add_command, 1, 'Add a quote'),
      'quote-del' => PermCommand.new('quote', self, :del_command, 1, 'Delete a quote by id'),
      'quote-count' => Command.new(self, :count_command, 0, 'Show amount of quotes'),
      'quote-last' => Command.new(self, :last_command, 0, 'Show the last quote'),
      'quote-search' => Command.new(self, :search_command, 1, 'Search to find a quote'),
    }
  end
  
  def quote_command(e, id=nil)
    return "quote \##{id} not found" if id and not @quotes.has_key?(id)
    return "\"#{@quotes[id]['quote']}\" by #{@quotes[id]['username']} at #{@quotes[id]['time']}" if id
    return "no quotes" if count < 1
    
    id = "#{rand(autoindex - 1) + 1}"
    while not @quotes.has_key?(id)
      id = "#{rand(autoindex - 1) + 1}"
    end
    
    "\"#{@quotes[id]['quote']}\" by #{@quotes[id]['username']} at #{@quotes[id]['time']}"
  end
  
  def add_command(e, quote)
    if e.user and e.user.respond_to?('authenticated?') and e.user.authenticated? then
      "quote added \##{add(quote, e.user.username)}"
    else
      'permission denied'
    end
  end
  
  def del_command(e, id)
    if @quotes.has_key?(id) then
      @quotes.delete id
      "quote #{id} deleted"
    else
      "no quote found with id=#{id}"
    end
  end
  
  def count_command(e)
    "#{count} quotes"
  end
  
  def last_command(e)
    return "no quotes" if count < 1
    quote_command(e, @quotes.keys.sort.reverse[0])
  end
  
  def search_command(e, search)
    result = @quotes.map{ |id, quote| "#{id}: #{quote['quote']}" if quote['quote'].include?(search) }.reject{ |q| not q }
    
    if result.count then
      result.join("\n")
    else
      "no quotes found"
    end
  end
end

Plugin.define do
  name "quote"
  description "quote database"
  object Quote
end