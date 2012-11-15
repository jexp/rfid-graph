require 'rubygems'
require 'neography'
require 'rfid'
require "cypher"
require 'test/unit'

class TestRfid < Test::Unit::TestCase 
  def test_add_tags
    @rfid.add_tags(["1","2","3"]);
    res=@cypher.query("start n=node:node_auto_index('tag:*') return n order by n.tag")
    puts res.inspect
    assert_equal(3,res.size)
    assert_equal(["1","2","3"],res.map {|row| row.values.map { |v| v.tag }}.flatten)
  end

  def test_add_person 
    @rfid.add_tags(["4"])
    @rfid.add_person("4","foo","@twitter","@github")
    res=@cypher.query("start p=node:node_auto_index(name='foo') match p-[:HAS_TAG]->tag return p,tag")
    puts res.inspect
    assert_equal(1,res.size)
    p=res.first["p"]
    assert_equal(["foo","@twitter","@github"], [p.name,p.twitter,p.github])
    assert_equal("4",res.first["tag"].tag)
  end

  def test_add_connection_simple
    (tag1,tag2)=["5","6"]
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_simple(tag1,tag2,4711)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]->tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([4711,4711],[talk.begin,talk.end])
  end

  def test_batch_connection_simple
    (tag1,tag2,tag3)=["5","6","7"]
    @rfid.add_tags([tag1,tag2,tag3]);
    @rfid.batch_connect_simple([[tag1,tag2],[tag1,tag3]],4711)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]->tag2 return tag,talk,tag2 order by tag2.tag",{:t=>tag1})
    assert_equal(2,res.size)
    res.each do |row|
      assert_equal(tag1,row["tag"].tag)
      assert(["6","7"].include? row["tag2"].tag)
      talk=row["talk"]
      assert_equal([4711,4711],[talk.begin,talk.end])
    end
  end

  def test_batch_like
    (tag1,tag2,tag3)=["5","6","7"]
    @rfid.add_tags([tag1,tag2,tag3]);
    @rfid.batch_connect_simple([[tag1,tag2],[tag1,tag3]],4711)
    @rfid.batch_like([[tag1,tag2],[tag1,tag3]])
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]-tag2 where talk.like = true return talk",{:t=>tag1})
    assert_equal(2,res.size)
  end


  def test_add_connection_simple_tag_order
    (tag1,tag2)=["5","6"]
    now=4711
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_simple(tag2,tag1,now)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]->tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([now,now],[talk.begin,talk.end])
  end

  def test_add_connection_simple_twice
    (tag1,tag2)=["7","8"]
    now=4711
    duration=100
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_simple(tag1,tag2,now)
    @rfid.connect_simple(tag1,tag2,now+duration)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]->tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([now,now+duration],[talk.begin,talk.end])
  end

  def test_add_connection_simple_after_timeout
    (tag1,tag2)=["9","10"]
    now=4711
    duration=Rfid::TIMEOUT+10
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_simple(tag1,tag2,now)
    @rfid.connect_simple(tag1,tag2,now+duration)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[talk:TALKED]->tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([now+duration,now+duration],[talk.begin,talk.end])
  end
  
  def test_add_connection_advanced
    (tag1,tag2)=["11","12"]
    @rfid.add_tags([tag1,tag2]);
    now = 4711
    @rfid.connect_advanced(tag1,tag2,now)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[:TALKED]->talk<-[:TALKED]-tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([now,now,@rfid.interval(now)],[talk.begin,talk.end,talk.interval])
  end

  def test_add_connection_advanced_twice
    (tag1,tag2)=["13","14"]
    now=4711
    duration=100
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_advanced(tag1,tag2,now)
    @rfid.connect_advanced(tag1,tag2,now+duration)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[:TALKED]->talk<-[:TALKED]-tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([now,now+duration,@rfid.interval(now)],[talk.begin,talk.end,talk.interval])
  end

  def test_add_connection_advanced_timout
#    Neography::Config.log_enabled=true
    (tag1,tag2)=["15","16"]
    now=4711
    duration=Rfid::INTERVAL*2
    later=now+duration
    @rfid.add_tags([tag1,tag2]);
    @rfid.connect_advanced(tag1,tag2,now)
    @rfid.connect_advanced(tag1,tag2,later)
    res=@cypher.query("start tag=node:node_auto_index(tag={t}) match tag-[:TALKED]->talk<-[:TALKED]-tag2 return tag,talk,tag2",{:t=>tag1})
    puts res.inspect
    assert_equal(1,res.size)
    assert_equal(tag1,res.first["tag"].tag)
    assert_equal(tag2,res.first["tag2"].tag)
    talk=res.first["talk"]
    assert_equal([later,later,@rfid.interval(later)],[talk.begin,talk.end,talk.interval])
  end
  
  def setup
    @rfid=Rfid.new
    @cypher=Cypher.new
    @cypher.clean()
  end
end