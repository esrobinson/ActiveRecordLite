require 'active_support/core_ext/object/try'
require 'active_support/inflector'
require_relative './db_connection.rb'

class AssocParams
  attr_accessor :name, :primary_key, :foreign_key, :class_name
  def other_class
    @class_name.constantize
  end

  def other_table
    other_class.table_name
  end
end

class BelongsToAssocParams < AssocParams
  def initialize(name, params)
    @name = name
    @primary_key = params[:primary_key] || "id"
    @foreign_key = params[:foreign_key] || "#{name}_id"
    @class_name = params[:class_name] || name.to_s.camelcase
  end

  def type
    :belongs_to
  end
end

class HasManyAssocParams < AssocParams
  def initialize(name, params, self_class)
    @name = name
    @primary_key = params[:primary_key] || "id"
    @foreign_key = params[:foreign_key] || "#{self_class.to_s.underscore}_id"
    @class_name = params[:class_name] || name.to_s.camelcase.singularize
  end

  def type
    :has_many
  end
end

module Associatable
  def assoc_params
     @assoc_params = {} if @assoc_params.nil?
     @assoc_params
  end

  def belongs_to(name, params = {})
    self.assoc_params[name] = BelongsToAssocParams.new(name, params)
    define_method(name) do
      values = self.class.assoc_params[name]
      result = values.other_class.where(
                  values.primary_key => self.send(values.foreign_key)
                )

      result.first
    end
  end


  def has_many(name, params = {})
    self.assoc_params[name] = HasManyAssocParams.new(name, params, self.to_s)
    define_method(name) do
      values = self.class.assoc_params[name]

      results = values.other_class.where(
      values.foreign_key => self.send(values.primary_key)
      )
    end
  end

  def has_one_through(name, assoc1, assoc2)
    self.assoc_params[name] = { :source => assoc2, :through => assoc1 }
    define_method(name) do

      through_assoc = self.class.assoc_params[name][:through]
      values_through = self.class.assoc_params[through_assoc]


      through_class = values_through.other_class
      source_assoc = self.class.assoc_params[name][:source]
      values_source = through_class.assoc_params[source_assoc]

      result = DBConnection.execute(<<-SQL)
        SELECT
          #{values_source.other_table}.*
        FROM
          #{values_through.other_table}
        JOIN
          #{values_source.other_table}
        ON
          #{values_through.other_table}.#{values_source.foreign_key} =
          #{values_source.other_table}.#{values_source.primary_key}
        WHERE
          #{self.send(values_through.foreign_key)} =
          #{values_through.other_table}.#{values_through.primary_key}
      SQL

      values_source.other_class.new(result.first)

    end


  end
end
