require "rubygems"
require "rfid"

  rfid = Rfid.new()
  rfid.clean()
  lines = IO.read("graphconnect.csv")
  tags = lines.split(/\n/).map{|line| line.split(/,/)[1] } 
  puts tags.inspect
  rfid.add_tags(tags)
  lines.split(/\n/).each do |line|
    (tag,name,twitter,github) = line.split(/,/)
    rfid.add_person(name,tag,twitter)
    puts "Added #{tag} #{name} #{twitter}"
  end
