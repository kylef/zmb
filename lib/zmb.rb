require 'socket'

require 'lib/zmb/plugin'
require 'lib/zmb/settings'
require 'lib/zmb/event'
require 'lib/zmb/commands'

class Zmb
  attr_accessor :plugins, :plugin_sources
  
  def initialize(config_dir)
    @plugin_manager = PluginManager.new
    @settings = Settings.new(config_dir)
    
    @instances = {'core/zmb' => self}
    @sockets = Hash.new
    
    @settings.get('core/zmb', 'plugin_sources', []).each{|source| @plugin_manager.add_plugin_source source}
    @settings.get('core/zmb', 'plugin_instances', []).each{|instance| load instance}
  end
  
  def to_json(*a)
    {
      'plugin_sources' => @plugin_manager.plugin_sources,
      'plugin_instances' => @instances.keys,
    }.to_json(*a)
  end
  
  def save
    @instances.each{ |k,v| @settings.save(k, v) }
  end
  
  def load(key)
    return true if @instances.has_key?(key)
    
    if p = @settings.get(key, 'plugin') then
      object = @plugin_manager.plugin(p)
      @instances[key] = object.new(self, @settings.setting(key))
      post! :plugin_loaded, key, @instances[key]
      true
    else
      false
    end
  end
  
  def unload(key)
    return false if not @instances.has_key?(key)
    instance = @instances.delete(key)
    @settings.save key, instance
    socket_delete instance
    post! :plugin_unloaded, key, instance
  end
  
  def run
    begin
      while 1
        socket_select(timeout)
      end
    rescue Interrupt
      return
    end
  end
  
  def timeout
    60.0
  end
  
  def socket_add(delegate, socket)
    @sockets[socket] = delegate
  end
  
  def socket_delete(item)
    if @sockets.include?(item) then
      @sockets.select{|sock, delegate| delegate == item}.each{|key, value| @sockets.delete(key)}
    end
    
    if @sockets.has_key?(item) then
      @sockets.delete(item)
    end
  end
  
  def socket_select(timeout)
    result = select(@sockets.keys, nil, nil, timeout)
    
    if result != nil then
      result[0].select{|sock| @sockets.has_key?(sock)}.each do |sock|
        if sock.eof? then
          @sockets[sock].disconnected(self, sock) if @sockets[sock].respond_to?('disconnected')
          socket_delete sock
        else
          @sockets[sock].received(self, sock, sock.gets()) if @sockets[sock].respond_to?('received')
        end
      end
    end
  end
  
  def post(signal, *args)
    results = Array.new
    
    @instances.select{|name, instance| instance.respond_to?(signal)}.each do |name, instance|
      results << instance.send(signal, *args) rescue nil
    end
    
    results
  end
  
  def post!(signal, *args) # This will exclude the plugin manager
    @instances.select{|name, instance| instance.respond_to?(signal) and instance != self}.each do |name, instance|
      instance.send(signal, *args) rescue nil
    end
  end
  
  def event(sender, e)
    post! :pre_event, self, e
    post! :event, self, e
  end
  
  def commands
    {
      'reload' => PermCommand.new('admin', self, :reload_command),
      'unload' => PermCommand.new('admin', self, :unload_command),
      'load' => PermCommand.new('admin', self, :load_command),
      'save' => PermCommand.new('admin', self, :save_command, 0),
      'loaded' => PermCommand.new('admin', self, :loaded_command, 0),
      'wizard' => PermCommand.new('admin', self, :wizard_command, 2),
      'set' => PermCommand.new('admin', self, :set_command, 3),
      'get' => PermCommand.new('admin', self, :get_command, 2),
      'clone' => PermCommand.new('admin', self, :clone_command, 2),
      'reset' => PermCommand.new('admin', self, :reset_command),
      'addsource' => PermCommand.new('admin', self, :addsource_command),
    }
  end
  
  def reload_command(e, instance)
    if @instances.has_key?(instance) then
      unload(instance)
      @plugin_manager.reload_plugin(@settings.get(instance, 'plugin'))
      load(instance)
      "#{instance} reloaded"
    else
      "No such instance #{instance}"
    end
  end
  
  def unload_command(e, instance)
    if @instances.has_key?(instance) then
      unload(instance)
      "#{instance} unloaded"
    else
      "No such instance #{instance}"
    end
  end
  
  def load_command(e, instance)
    if not @instances.has_key?(instance) then
      load(instance) ? "#{instance} loaded" : "#{instance} did not load correctly"
    else
      "Instance already #{instance}"
    end
  end
  
  def save_command(e)
    save
    'settings saved'
  end
  
  def loaded_command(e)
    @instances.keys.join(', ')
  end
  
  def wizard_command(e, plugin, instance)
    object = @plugin_manager.plugin plugin
    
    return "plugin not found" if not object
    return "no wizard availible" if not object.respond_to? 'wizard'
    
    settings = Hash.new
    settings['plugin'] = plugin
    d = object.wizard
    d.each{ |k,v| settings[k] = v['default'] if v.has_key?('default') and v['default'] }
    @settings.save instance, settings
    
    values = d.map{ |k,v| "#{k} - #{v['help']} (default=#{v['default']})" }
    
    "Instance saved, please use the set command to override the default configuration for this instance.\n"+
    values.join("\n")
  end
  
  def set_command(e, instance, key, value)
    settings = @settings.setting(instance)
    settings[key] = value
    @settings.save(instance, settings)
    "#{key} set to #{value} for #{instance}"
  end
  
  def get_command(e, instance, key)
    if value = @settings.get(instance, key) then
      "#{key} is #{value} for #{instance}"
    else
      "#{instance} or #{instance}/#{key} not found."
    end
  end
  
  def clone_command(e, instance, new_instance)
    if (settings = @settings.setting(instance)) != {} then
      @settings.save(new_instance, settings)
      "The settings for #{instance} were copied to #{new_instance}"
    else
      "No settings for #{instance}"
    end
  end
  
  def reset_command(e, instance)
    @settings.save(instance, {})
    "Settings for #{instance} have been deleted."
  end
  
  def addsource_command(e, source)
    @plugin_manager.add_plugin_source source
    "#{source} added to plugin manager"
  end
end