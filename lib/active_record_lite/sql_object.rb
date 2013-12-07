require_relative './associatable'
require_relative './db_connection' # use DBConnection.execute freely here.
require_relative './mass_object'
require_relative './searchable'

class SQLObject < MassObject
  extend Searchable
  extend Associatable

  # sets the table_name
  def self.set_table_name(table_name)
    @table_name = table_name
  end

  # gets the table_name
  def self.table_name
    @table_name || self.to_s.underscore.pluralize
  end

  # querys database for all records for this type. (result is array of hashes)
  # converts resulting array of hashes to an array of objects by calling ::new
  # for each row in the result. (might want to call #to_sym on keys)
  def self.all
    objects = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    self.parse_all(objects)
  end

  # querys database for record of this type with id passed.
  # returns either a single object or nil.
  def self.find(id)
    object = DBConnection.execute(<<-SQL, :id => id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = :id
    SQL
    return nil if object.empty?
    self.new(object.first)
  end

  # call either create or update depending if id is nil.
  def save
    if self.id.nil?
      create
    else
      update
    end
  end

  private

  # helper method to return values of the attributes.
  def attribute_hash
    instance_vars = self.send(:instance_variables)
    values = {}
    instance_vars.each do |var|
      values[(var.to_s.delete('@')).to_sym] = self.instance_variable_get(var)
    end
    values
  end


  # executes query that creates record in db with objects attribute values.
  # use send and map to get instance values.
  # after, update the id attribute with the helper method from db_connection
  def create
    values = attribute_hash
    DBConnection.execute(<<-SQL, values)
    INSERT INTO
      #{self.class.table_name} (#{values.keys.join(', ')})
    VALUES
      (:#{values.keys.join(', :')})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  # executes query that updates the row in the db corresponding to this instance
  # of the class. use "#{attr_name} = ?" and join with ', ' for set string.
  def update
    values = attribute_hash
    DBConnection.execute(<<-SQL, values)
    UPDATE
      #{self.class.table_name}
    SET
      #{values.map do |key, v|
        "#{key}=:#{key}" unless key == :id
        end[1..-1].join(',')}
    WHERE
    id=:id
    SQL
    self.id = DBConnection.last_insert_row_id
  end
end
