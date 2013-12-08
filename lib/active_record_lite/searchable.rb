require_relative './db_connection'

class Relation
  attr_reader :table_name, :where_params, :where_string, :object_class,
              :joins_string, :select_string

  def initialize(type, table_name, object_class, params)
    @object_class = object_class
    @table_name = table_name
    @where_string = ""
    @select_string = ""
    @where_params = []
    @joins_string = []
    self.send(type, params)
  end

  def where(params)
    @where_string.concat(" AND ") unless @where_string.empty?
    if params.is_a?(Hash)
      new_query = params.map{ |key, v| "#{key}=?"}.join(' AND ')
      @where_string.concat(new_query)
      @where_params.concat(params.values)
    elsif params.is_a?(String)
      @where_string.concat(params)
    end
    self
  end

  def joins(param)
    if param.is_a?(Symbol)

    else
      @joins_string << param
    end
    self
  end

  def select(param)
    @select_string = param
  end

  def includes(association_name)
    name = association_name
    original_objects = self.evaluate
    assoc_params = @object_class.assoc_params[association_name]
    if assoc_params.type == :belongs_to
      orig_id, sub_id = assoc_params.foreign_key, assoc_params.primary_key
    else
      orig_id, sub_id = assoc_params.primary_key, assoc_params.foreign_key
    end
    ids = original_objects.map{ |obj| obj.send(orig_id) }
    sub_objects = assoc_params.other_class.where(
        "#{assoc_params.other_table}.#{sub_id} IN (#{ids.join(',')})")
        p sub_objects
    sub_objects = sub_objects.evaluate
    create_sub_variables(original_objects, sub_objects, orig_id, sub_id, name)
    original_objects
  end

  def create_sub_variables(orig_obj, sub_obj, orig_id, sub_id, name)
    sub_obj.each do |object|
      p_obj = orig_obj.find{ |obj| obj.send(orig_id) == object.send(sub_id) }
      assoc_objs = p_obj.instance_variable_get("@#{name}") || []
      assoc_objs << object
      p_obj.instance_variable_set("@#{name}", assoc_objs)
    end
  end


  def evaluate
    results = DBConnection.execute(<<-SQL, self.where_params)
    SELECT
      #{self.select_string.empty? ? "#{self.table_name}.*" : self.select_string}

    FROM
      #{self.table_name}
    #{"JOIN" unless self.joins_string.empty?}
      #{self.joins_string.join("\nJOIN ")}
    WHERE
      #{self.where_string}
    SQL
    if self.select_string.empty?
      self.object_class.parse_all(results)
    else
      results
    end
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

  def joins(params)
    Relation.new(:joins, self.table_name, self, params)
  end

  def select(params)
    Relation.new(:select, self.table_name, self, params)
  end

  def includes(association)


  end

end