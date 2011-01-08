class Halt <Exception; end
class HaltCore <Halt; end

class Plugin
  attr_accessor :zmb, :timers

  class << self
    def self.attr_rw(*attrs)
      attrs.each do |attr|
        class_eval %Q{
          def #{attr}(val=nil)
            val.nil? ? @#{attr} : @#{attr} = val
          end
        }
      end
    end

    attr_rw :name, :description, :definition_file
  end

  def halt(*args)
    raise Halt.new(*args)
  end

  def haltcore(*args)
    raise HaltCore.new(*args)
  end

  def initialize(delegate, s)
    @timers = Array.new
  end

  def plugins
    @delegate.plugins
  end

  def debug(message, exception=nil)
    zmb.debug(self, message, exception) if @zmb
  end

  def post(signal, *args, &block)
    plugins.select{ |p| p.respond_to?(signal) }.each do |p|
      begin
        p.send(signal, *args)
      rescue HaltCore
        block.call if block
        return
      rescue Halt
        return
      rescue
        zmb.debug(p, "Sending signal `#{signal}` failed", $!)
      end
    end
  end

  # Timers

  def add_timer(symbol, interval, repeat=false, data=nil)
    t = Timer.new(self, symbol, interval, repeat, data)
    @timers << t
    t
  end

  def del_timer(t)
    @timers.delete(t)
  end
end
