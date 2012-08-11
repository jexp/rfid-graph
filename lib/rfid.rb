require 'rubygems'
require 'neography'


class Rfid 
  def initialize
    @neo = Neography::Rest.new("http://localhost:7474")
#    puts @neo
#    puts query("start n=node({id}) return n", {:id => 0}).first.inspct
#    puts @neo.get_node(0).inspect
  end

def query(query, params={})
  convert(@neo.execute_query(query,params))
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

def clean 
  query("start n=node(*) match n-[r?]->m where ID(n)<>0 delete n,r")
end

def convert_cell(cell)
  return Neography::Relationship.new(cell) if (cell["type"])
  return Neography::Node.new(cell) if (cell["self"])
  return cell.map{ |x| convert_cell(x) } if (cell.kind_of? Enumerable)
  cell
end

def add_tags(tags)
  puts "Adding tags #{tags.inspect}"
  query("start n=node(0) foreach (tag in {tags} : create t={ tag: tag })", {:tags => tags})
end

# person-[:HAS_TAG]->tag 
def add_person(tag, name, twitter = null, github = null)
  query("start tag=node:node_auto_index(tag={tag}) "+
    " create person={ name : {name}, twitter : {twitter}, github: {github} }, person-[:HAS_TAG]->tag", 
    {:tag => tag, :name => name, :twitter => twitter, :github => github})
end

MINUTE=60
TIMEOUT=5*MINUTE
INTERVAL=15*MINUTE
INTERVAL_FORMAT="%D %H:%M"

# tag1-[talk:TALKED {begin,end}]->tag2
def connect_simple(tag1,tag2,time = Time.now.to_i) 
  (tag1,tag2) = [tag2, tag1] if tag2.to_i < tag1.to_i
#  puts "#{tag1}-[:TALKED {#{time}}]->#{tag2}"
  query(
  "start tag1=node:node_auto_index(tag={tag1}), tag2=node:node_auto_index(tag={tag2})
   relate tag1-[talk:TALKED]->tag2
   set talk.begin = head(filter( time in [coalesce(talk.begin?,{now}),{now}] : {now}-#{TIMEOUT} < time )), talk.end = {now}", 
    {:tag1 => tag1, :tag2 => tag2, :now => time})
=begin

"start tag1=node:node_auto_index(tag={tag1}), tag2=node:node_auto_index(tag={tag2})
 match tag1-[talk?:TALKED]->tag2
 with tag1,tag2, filter(t in collect(talk) : t = null) as talks, {now} as now
 foreach (t in talks: create tag1-[:TALKED {begin: now,end:now}]->tag2)
 with tag1, tag2, now
 match tag1-[talk:TALKED]->tag2
 set talk.begin = head(filter( time in [talk.begin,now] : now-#{TIMEOUT} < time )), talk.end = now", 
=end    
end

def interval(time = Time.now.to_i)
  Time.at(time-(time % (INTERVAL))).strftime(INTERVAL_FORMAT)
end

# case 1 add or update talk : tag1-[:TALKED]->(talk {interval,begin,end})<-[:TALKED]-tag2
# case 2 also push old data to "prev" node: talk-[:PREV]->(prev {interval,begin,end})
def connect_advanced(tag1,tag2,time = Time.now.to_i) 
  (tag1,tag2) = [tag2, tag1] if tag2.to_i < tag1.to_i
  puts "#{tag1}-[:TALKED {#{time}}]->#{tag2}"
  query(
  "start tag1=node:node_auto_index(tag={tag1}), tag2=node:node_auto_index(tag={tag2})
   relate tag1-[:TALKED]->(talk {tag1 : {tag1}, tag2: {tag2}})<-[:TALKED]-tag2
   with talk, filter(t in [talk] : t.interval! <> {interval}) as old_talk
   foreach (t in old_talk : 
     create prev={ interval:t.interval, begin : t.begin, end : t.end }, talk-[:PREV]->prev
     set t.begin = {now}
   )
   set talk.interval = {interval}, talk.begin = coalesce(talk.begin?, {now}), talk.end = {now}", 
    {:tag1 => tag1, :tag2 => tag2, :now => time, :interval => interval(time) })
=begin

=end
end

end