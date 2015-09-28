require_relative './sqlobject'
require 'active_support/inflector'

# Phase IIIa
class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.constantize
  end

  def table_name
    model_class.table_name ||= @class_name.downcase.pluralize
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @primary_key = options[:primary_key] ||= :id
    @class_name = options[:class_name] ||= name.camelize.titleize
    @foreign_key = options[:foreign_key] ||= name.foreign_key.to_sym
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @primary_key = options[:primary_key] ||= :id
    @class_name = options[:class_name] ||= name.singularize.titleize
    @foreign_key = options[:foreign_key] ||= self_class_name.foreign_key.to_sym
  end
end
