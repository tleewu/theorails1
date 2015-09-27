require 'active_support'
require 'active_support/core_ext'
require 'erb'

require_relative './session'
require_relative './params'
require_relative './route'
require_relative './flash'

class ControllerBase

  attr_reader :req, :res, :params

  def initialize(req,res, route_params = {})
    @req = req
    @res = res
    @params = Params.new(@req, route_params)
  end

  def controller_name
    self.class.to_s.underscore
  end

  def render(template_name)
    content = ERB.new(File.read("views/#{controller_name}/#{template_name}.html.erb")).result(binding)
    #All of the controller's variables within scope are evalulated
    #They are then substituted into our HTML
    render_content(content, "text/html")
  end

  def already_built_response?
    @already_built_response ||= false
  end

  def redirect_to(url)
    raise "Invalid authenticity token" unless verify_authenticity_token
    raise "Render has already been built" if already_built_response?
    @res.status = 302
    @res['location'] = url

    session.store_session(@res)
    flash.store_flash(@res)

    @already_built_response = true
  end

  def render_content(content,content_type)
    raise "Invalid authenticity token" unless verify_authenticity_token
    raise "Render has already been built" if already_built_response?
    @res.content_type = content_type
    @res.body = content

    session.store_session(@res)
    flash.store_flash(@res)

    @already_built_response = true
  end

  def session
    @session ||= Session.new(@req)
  end

  def flash
    @flash ||= Flash.new(@req)
  end

  def invoke_action(name)
    send(name)
    # variables from the controller class method is now available in scope
    render(name) unless already_built_response?
  end

  def form_authenticity_token
    @token = SecureRandom.base64
    session["auth_token"] = @token
    #TODO: potentially need to save this cookie.
    @token
  end

  def verify_authenticity_token
    method = @req.request_method
    if (method == "POST") || (method == "PATCH") || (method == "DESTROY")
      return false unless @params["authenticity_token"] && session["auth_token"]
      return false unless @params["authenticity_token"] == session["auth_token"]
    end
    true
  end
end
