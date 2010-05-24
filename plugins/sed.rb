class Sed
  def initialize(sender, settings)
    @messages = Hash.new
  end
  
  def event(sender, e)
    if e.message =~ /^s\/(\S+)\/(\S+)\/$/ then
      e.reply("#{e.name} meant " + @messages[e.userhost].sub($1, $2))
    else
      @messages[e.userhost] = e.message if e.message?
    end
  end
end

Plugin.define do
  name 'sed'
  object Sed
end
