require_relative './db_connection'

class Relation
  attr_reader :table_name, :where_params, :where_string, :object_class

  def initialize(type, table_name, object_class, params)
    @object_class = object_class
    @table_name = table_name
    @where_string = ""
    @where_params = {}
    self.send(type, params)
  end

  def where(params)
    @where_string.concat(" AND ") unless @where_string.empty?
    new_query = params.map{ |key, v| "#{key}=:#{key}"}.join(' AND ')
    @where_string.concat(new_query)
    @where_params.merge!(params)
    self
  end

  def evaluate
    results = DBConnection.execute(<<-SQL, self.where_params)
    SELECT
      *
    FROM
      #{self.table_name}
    WHERE
      #{self.where_string}
    SQL

    self.object_class.parse_all(results)
  end

  def method_missing(method, *args, &block)
    self.evaluate.send(method, *args, &block)
  end


end

module Searchable
  # takes a hash like { :attr_name => :search_val1, :attr_name2 => :search_val2 }
  # map the keys of params to an array of  "#{key} = ?" to go in WHERE clause.
  # Hash#values will be helpful here.
  # returns an array of objects

  def where(params)
    Relation.new(:where, self.table_name, self, params)
  end

end