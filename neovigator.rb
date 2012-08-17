require 'rubygems'
require 'neography'
require 'sinatra/base'
require 'uri'
require 'lib/cypher'

class Neovigator < Sinatra::Application
  set :haml, :format => :html5 
  set :app_file, __FILE__

  configure :test do
    require 'net-http-spy'
    Net::HTTP.http_logger_options = {:verbose => true} 
  end

  helpers do
    def link_to(url, text=url, opts={})
      attributes = ""
      opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
      "<a href=\"#{url}\" #{attributes}>#{text}</a>"
    end

    def neo
      @neo = Neography::Rest.new(ENV['NEO4J_URL'] || "http://localhost:7474")
    end

    def cypher
      @cypher = Cypher.new(neo)
    end
  end

  def neighbours
    {"order"         => "depth first",
     "uniqueness"    => "none",
     "relationships" => [{"type" => "TALKED", "direction" => "all"}],
     "return filter" => {"language" => "builtin", "name" => "all_but_start_node"},
     "depth"         => 1}
  end

  def node_id(node)
    case node
      when Hash
        node["self"].split('/').last
      when String
        node.split('/').last
      else
        node
    end
  end

START="200"

  def node_for(id)
    id = START unless id
#   return neo.get_node(id) if id =~ /\d+/
    return (neo.get_node_auto_index("tag",id)||[]).first || neo.get_node(id)
  end
  
  def get_info(props)
    properties = "<ul>"
    properties << "<li><b>Tag:</b> #{props["tag"]}</li>"
    properties << "<li><b>Name:</b> #{props["name"]}</li>"
    properties << "<li><b>Twitter:</b> <a href='http://twitter.com/#{props["twitter"]}'>#{props["twitter"]}</a></li>"
    properties << "<li><b>Github:</b> <a href='http://twitter.com/#{props["github"]}'>#{props["github"]}</a></li>"
    properties + "</ul>"
  end
  
  def get_properties(node)
    n = Neography::Node.new(node)
    res = cypher.query("start tag=node({id}) 
      match tag<-[?:HAS_TAG]-user 
      return ID(tag) as id, tag.tag as tag, 
          coalesce(user.name?,tag.tag) as name, user.twitter? as twitter, user.github? as github",{:id => n.neo_id.to_i})
    res.first
  end

QUERY = "start tag=node({id}) 
   match tag-[r:TALKED]-other<-[?:HAS_TAG]-other_user
   return ID(other) as id, other.tag as tag, coalesce(other_user.name?,other_user.twitter?,other_user.github?,other.tag) as name, r, type(r) as type"

# todo group by type and direction
NA="No Relationships"

  def direction(node, rel)
    rel.end_node.to_i == node ? "Incoming" : "Outgoing"
  end

  def get_connections(node_id)  
    connections = cypher.query(QUERY,{:id=>node_id})
    rels = connections.group_by { |row| [direction(id,row["r"]), row["type"]] }
  end
  
  get '/resources/show' do
    content_type :json
    node = node_for(params[:id])
    props = get_properties(node)
    user = props["name"]
    id = props["id"]

    connections = get_connections(id)
    attributes = rels.collect { |keys, values| {:id => keys.last, :name => keys.join(":"), :values => values } }
    attributes = [{:id => "N/A", :name => NA, :values => [{:id => id, :name => NA}]}] if attributes.empty?

    @node = {:details_html => "<h2>User: #{user}</h2>\n<p class='summary'>\n#{get_info(props)}</p>\n",
             :data => {:attributes => attributes, :name => user, :id => id }}.to_json
  end

  get '/resources/show2' do
    content_type :json
    node = node_for(params[:id])
    props = get_properties(node)
    user = props["name"]

    connections = neo.traverse(node, "fullpath", neighbours)
    incoming = Hash.new{|h, k| h[k] = []}
    outgoing = Hash.new{|h, k| h[k] = []}
    nodes = Hash.new
    attributes = Array.new

    connections.each do |c|
       c["nodes"].each do |n|
         nodes[n["self"]] = n["data"].merge({"name" => n["data"]["tag"]})
       end
     end
     
    connections.each do |c|
       rel = c["relationships"][0]
       
       if rel["end"] == node["self"]            # values has id which is usd for /resources/show?id=id and name which is displayed
         incoming["Incoming:#{rel["type"]}"] << {:values => nodes[rel["start"]].merge({:id => node_id(rel["start"]) }) }
       else
         outgoing["Outgoing:#{rel["type"]}"] << {:values => nodes[rel["end"]].merge({:id => node_id(rel["end"]) }) }
       end
    end

      incoming.merge(outgoing).each_pair do |key, value|
        attributes << {:id => key.split(':').last, :name => key, :values => value.collect{|v| v[:values]} }
      end

   attributes = [{"name" => "No Relationships","name" => "No Relationships","values" => [{"id" => "#{user}","name" => "No Relationships "}]}] if attributes.empty?

    @node = {:details_html => "<h2>User: #{user}</h2>\n<p class='summary'>\n#{get_info(props)}</p>\n",
              :data => {:attributes => attributes, 
                        :name => user,
                        :id => node_id(node)}
            }

    @node.to_json

  end

  get '/' do
    @user = node_for(params["user"]||START)["data"]["tag"]
puts @user
    haml :index
  end

end
