require "rubygems"
require "rfid"

def parse(args)
  return puts "Usage parse sample.json" if args.empty? || !File.exists?(args[0])
  sample = MultiJson.load(IO.read(args[0]))
  rfid = Rfid.new()
#  rfid.clean()
  time = sample["time"]
  tags = sample["tag"]
  tags = tags.map { |t| t["id"] } if (tags)
  tags = sample["edge"].map { |e| e["tag"] }.flatten.uniq if (!tags)
  liked = sample["tag"].find_all { |t| t["button"] }.map {|t| t["id"]}.flatten.uniq

#  puts tags.size
#  rfid.add_tags(tags)
  pairs = sample["edge"].map { |e| tags=e["tag"]; [tags[0],tags[1]]  }
  rfid.batch_connect_simple(pairs,time)
  liked_pairs = pairs.find_all{ |t| liked.member?(tags[0]) || liked.member?(tags[1]) }
  connected_pairs = pairs.find_all{ |t| liked.member?(tags[0]) && liked.member?(tags[1]) }
  rfid.batch_like(liked_pairs,"like")
  rfid.batch_like(connected_pairs,"connect")
#  sample["edge"].each { |e| tags=e["tag"]; rfid.connect_advanced(tags[0],tags[1],time)  }
end

parse(ARGV)