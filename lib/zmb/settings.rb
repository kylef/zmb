require 'json'

class Settings
  def initialize(directory)
    if not File.exist?(directory) then
      FileUtils.makedirs(directory)
    end
    
    if not File.directory?(directory) and not File.owned?(directory) then
      raise
    end
    
    @directory = directory
  end
  
  def setting_path(key)
    File.join(@directory, key.gsub('/', '_') + '.json')
  end
  
  def setting(key)
    JSON.parse(File.read(setting_path(key)))
  end
  
  def get(object, name, default=nil)
    s = setting(object)
    
    if s.respond_to?('has_key?') and s.has_key?(name) then
      s[name]
    else
      default
    end
  end
  
  def save(key, data)
    #File.write(config_path(key), data.to_json)
  end
end