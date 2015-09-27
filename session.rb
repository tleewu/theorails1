require 'json'
require 'webrick'

class Session

  def initialize(req)
    cookie = req.cookies.find{|cookie| cookie.name == '_rails_lite_app'}
    if cookie
      @value = JSON.parse(cookie.value)
    else
      @value = {}
    end
  end

  def [](key)
    @value[key]
  end

  def []=(key,val)
    @value[key] = val
  end

  def store_session(res)
    res.cookies << WEBrick::Cookie.new('_rails_lite_app', @value.to_json)
  end
end
