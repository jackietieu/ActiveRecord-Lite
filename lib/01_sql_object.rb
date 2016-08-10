require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns_data ||= DBConnection.execute2(<<-SQL)
      SELECT *
      FROM #{table_name}
    SQL

    @columns_data.first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |col|
      define_method(col) do
        attributes["#{col}".to_sym]
      end

      define_method("#{col}=".to_sym) do |val|
        attributes["#{col}".to_sym] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.to_s.tableize
  end

  def self.all
    objs = DBConnection.execute(<<-SQL)
      SELECT #{table_name}.*
      FROM #{table_name}
    SQL

    objs.map { |attributes_hash| self.new(attributes_hash) }
  end

  def self.parse_all(results)
    results.map { |attributes_hash| self.new(attributes_hash) }
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
      SELECT #{table_name}.*
      FROM #{table_name}
      WHERE id = ?
    SQL

    self.parse_all(result).first
  end

  def initialize(params = {})
    params.each do |attr_name, val|
      if self.class.columns.include?(attr_name.to_sym)
        send("#{attr_name}=".to_sym, val)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    attributes.map { |attribute, val| val }
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.join(", ")
    question_marks = (["?"] * columns.length).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    columns = self.class.columns.drop(1)
    set_line = columns.map{ |attr_name| "#{attr_name} = ?"}.join(", ")
    question_marks = (["?"] * columns.length).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values.rotate)
      UPDATE
        #{self.class.table_name}
      SET
       #{set_line}
      WHERE
       id = ?
    SQL
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end
end
