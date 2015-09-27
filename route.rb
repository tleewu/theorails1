class Route

  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern = pattern
    @http_method = http_method
    @controller_class = controller_class
    @action_name = action_name
  end

  def matches?(req)
    req.path.match(@pattern) && @http_method == req.request_method.downcase.to_sym
  end

  def run(req,res)
    route_params = {}

    regex = Regexp.new(@pattern)
    match_data = regex.match(req.path)

    match_data.names.each do |key|
      route_params[key] = match_data[key]
    end

    controller = @controller_class.new(req,res,route_params)
    controller.invoke_action(@action_name)
    # variable 'controller' is no longer referring to the controller base
    # it is now referring to the "specific" controller ie. UsersController, CatsController
    # invoking the action will store all the variables in scope, to be used on render
  end
end

class Router

  attr_reader :routes

  def initialize
    @routes = []
  end

  def add_route(pattern,method,controller_class,action_name)
    @routes = Route.new(pattern,method,controller_class,action_name)
  end

  def draw(&proc)
    instance_eval(&proc)
  end

  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern,controller_class,action_name|
      add_route(pattern,http_method,controller_class,action_name)
    end
  end

  def match(req)
    @routes.each do |route|
      return route if route.matches?(req)
    end
    nil
  end

  def run(req,res)
    if match(req)
      match(req).run(req,res)
    else
      res.status = 404
    end
  end
end
