require 'uri'

class Params
  def initialize(req, route_params={})
    @params = route_params
    parse_www_encoded_form(req.query_string) if req.query_string
    parse_www_encoded_form(req.body) if req.body
  end

  def [](key)
    JSON.parse(@params.to_json)[key.to_s]
  end

  def to_s
    @params.to_s
  end

  class AttributeNotFoundError < ArgumentError; end;
  # not exactly sure what this does??

  private

  def parse_www_encoded_form(www_encoded_form)
    www_encoded_form = URI.decode_www_form(www_encoded_form)

    www_encoded_form.each do |hash_combo|
      if hash_combo.join("").split("").include?("[")
        hash_combo = parse_key(hash_combo.join(""))
      end
      current_params = @params
      hash_combo.each_with_index do |key,idx|
        if idx == hash_combo.length - 2
          current_params[key] = hash_combo[-1]
          break
        else
          if current_params[key]
            current_params = current_params[key]
          else
            current_params[key] = {}
            current_params = current_params[key]
          end
        end
      end

    end
  end

  def parse_key(key)
    key.to_s.split(/\]\[|\[|\]/)
  end

end
