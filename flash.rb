require 'json'
require 'webrick'

class Flash
  def initialize(req)
    cookie = req.cookies.find{|cookie| cookie.name == '_flash_cookie'}

    if cookie
      @value = JSON.parse(cookie.value)
    else
      @value = {}
    end

    @now = {}
    #TODO: each Rails App gets ONE consolidated cookie app name
  end

  def [](key)
    result = []
    result << @value[key] if @value[key]
    result << @value[key] if @value[key]
    result
  end

  def []=(key,value)
    @value[key]=value
  end

  def now
    @now
  end

  def store_flash(res)
    new_cookie = WEBrick::Cookie.new('_flash_cookie', @value.to_json)
    new_cookie.path = "/"
    #TODO: still need to figure out exactly what is the point of this

    res.cookies << new_cookie
  end
end
