require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable

  def where(params)
    where_line = params.map { |attr_name, val| "#{attr_name} = ?" }.join(" AND ")
    #PARAMS IS A HASH DON'T FORGET!
    results = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_line}
    SQL

    parse_all(results)
  end
end

class SQLObject
  extend Searchable
  # Mixin Searchable here...
end
