require 'rubygems'
require 'neography'


class Cypher 
  def initialize(neo)
    @neo = neo || Neography::Rest.new(ENV['NEO4J_URL'] || "http://localhost:7474")
  end

  def query(query, params={})
    convert(@neo.execute_query(query,params))
  end

  def batch(prepared)
    params = prepared.map { |p| [:execute_query, p[:query], p[:params]]  }
    @neo.batch(*params)
  end

  def clean 
    query("start n=node(*) match n-[r?]->m where ID(n)<>0 delete n,r")
  end

  def convert(res)
    return nil if res.nil?
    data=res["data"]
    cols=res["columns"]
    data.map do |row| 
      new_row = {}
      row.each_with_index do |cell,idx|
         new_row[cols[idx]]=convert_cell(cell)
      end
      new_row 
    end
  end

  def convert_cell(cell)
    return Neography::Relationship.new(cell) if cell.kind_of?(Hash) && cell["type"]
    return Neography::Node.new(cell) if cell.kind_of?(Hash) && cell["self"]
    return cell.map{ |x| convert_cell(x) } if cell.kind_of?(Array)
    cell
  end
  
end