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

START="1047"

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
    return nil if !res || res.empty?
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
    rels = connections.group_by { |row| [direction(node_id,row["r"]), row["type"]] }
  end
  
  get '/resources/show' do
    content_type :json
    puts "Loading viz for #{params[:id]}"
    node = node_for(params[:id])
    props = get_properties(node)
    user = props["name"]
    id = props["id"]

    rels = get_connections(id)
    attributes = rels.collect { |keys, values| {:id => keys.last, :name => keys.join(":"), :values => values } }
    attributes = [{:id => "N/A", :name => NA, :values => [{:id => id, :name => NA}]}] if attributes.empty?

    @node = {:details_html => "<h2>User: #{user}</h2>\n<p class='summary'>\n#{get_info(props)}</p>\n",
             :data => {:attributes => attributes, :name => user, :id => id }}.to_json
  end

  get '/' do
    @user = node_for(params["user"]||START)["data"]["tag"]
puts @user
    haml :index
  end

end
