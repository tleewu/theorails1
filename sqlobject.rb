require_relative 'db_connection'
require_relative 'assocoptions'
require 'active_support/inflector'

class SQLObject

  attr_accessor :table_name, :attributes, :assoc_options

  def initialize(params = {})
    params.keys.each do |key|
      #key should represent the column
      raise "unknown attribute '#{key}'" unless self.class.columns.include?(key.to_sym)
      self.class.finalize!
      send("#{key}=", params[key])
    end
  end

  def self.columns
    columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    columns.first.map{|column| column.to_sym}
    #In SQL queries, the first row identifies the columns. The following rows will
    #be stored in hashes representing the remaining data in our tables.
  end

  def self.finalize!

    self.columns.each do |column|
      #The each statement creates attr_accessors for every column in our table.

      define_method("#{column}") do
        attributes[column]
      end

      define_method("#{column}=") do |variable|
        attributes[column] = variable
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name.to_s
  end

  def self.table_name
    @table_name ||= self.to_s.downcase.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{self.table_name}.*
      FROM
        #{self.table_name}
    SQL
    results.map do |result|
      self.new(result)
    end
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL)
      SELECT
        #{self.table_name}.*
      FROM
        #{self.table_name}
      WHERE
        id = #{id}
    SQL

    return nil if result.empty?
    self.new(result.first)
    #Result will be an array with ONE hash. Calling .first will set up our
    #initializing params.
  end

  def attributes
    @attributes ||= {:id => nil}
  end

  def attribute_values
    attribute_values = []
    attributes.map do |key, value|
      attribute_values << value
    end
    attribute_values
  end

  def insert
    insert_values = attribute_values
    insert_values.shift
    #When we insert a new object into the database, the ID will be nil by default.
    #We don't want to insert that value into our database, so we are deleting it.

    DBConnection.execute(<<-SQL)
      INSERT INTO
        #{self.class.table_name} (#{self.class.columns.drop(1).join(', ')})
      VALUES
        ('#{insert_values.join("','")}')
    SQL

    last_id = DBConnection.last_insert_row_id
    attributes[:id] = last_id
    #Making sure when object is saved into database, we record its ID attribute.
  end

  def update
    DBConnection.execute(<<-SQL)
      UPDATE
        #{self.class.table_name}
      SET
        #{self.class.columns.map do |col|
          col.to_s + " = " + "'" + attributes[col].to_s + "'"
        end.join(', ')}
      WHERE
        id = #{attributes[:id]}
    SQL
  end

  def save
    if self.attributes[:id].nil?
      self.insert
    else
      self.update
    end
  end

  def where(params)
    where_params = []
    params.each do |key, value|
      where_params << "#{key.to_s} = '#{value.to_s}'"
    end

    result_db = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_params.join(" AND ")}
    SQL

    result_db.map do |result|
      self.new(result)
    end
  end

  # Remaining code pertains to SQL objects and their associations properties

  def belongs_to(name, options = {})
    association = BelongsToOptions.new(name.to_s, options)
    #Variable 'name' is a symbol. This needs to be converted to string.

    define_method("#{name}") do

      foreign_key_value = send(association.foreign_key)
      # association.foreign.key is the foreign key symbol, not the value.
      # As a result, we use the 'send' method to fetch the foreign key's value
      # We will then use this value in our 'where'

      result = association.model_class.where(id: foreign_key_value).first
      # We use the .first method because where returns an array of objects.
      # Belongs_to associations should only return ONE object.
    end
    assoc_options[name] = association

  end

  def has_many(name, options = {})
    define_method("#{name}") do
      association = HasManyOptions.new(name.to_s, self.class.to_s, options)
      foreign_key_value = send(association.primary_key)
      result = association.model_class.send(:where, ({association.foreign_key => foreign_key_value}))
    end
  end

  def assoc_options
    @assoc_options ||= {}
  end

  def has_one_through(name, through_name, source_name)

    define_method("#{name}") do

      through_options = self.class.assoc_options[through_name]
      # NOTE: self.class because this is not a class method.
      # through_options will return a BelongsToOption object
      foreign_key_value = send(through_options.foreign_key)

      source_options = through_options.model_class.assoc_options[source_name]
      # source_options will return a BelongsToOption object
      # BelongsToOptions objects between house and owner

      result = DBConnection.execute(<<-SQL)
        SELECT
          #{source_options.table_name}.*
        FROM
          #{through_options.table_name}
        JOIN
          #{source_options.table_name}
          ON #{source_options.table_name}.#{source_options.primary_key} =
          #{through_options.table_name}.#{source_options.foreign_key}
        WHERE
          #{through_options.table_name}.#{through_options.primary_key} = #{foreign_key_value}
      SQL

      # SELECT houses.* FROM humans JOIN humans ON humans.id = houses.owner_id WHERE humans.id = ?
      # Trick was that both source_option's foreign and primary key were used in
      # SQL query.

      source_options.model_class.new(result.first)
    end
  end
end
