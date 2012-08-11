Sample Ruby application to read [OpenBeacon](http://www.openbeacon.org/BruCON_2011) RFID tracking sightings into a neo4j graph.

## Data Model

    (person {name, twitter,github})-[:HAS_TAG]->(tag {tag})

### Simple with talk as relationship

    tag1-[talk:TALKED {begin,end}]->tag2 # simple model

### Advanced with talk as node

    tag1-[:TALKED]->(talk {interval,begin,end})<-[:TALKED]-tag2
    // old data (later than TIMEOUT) pushed to separate node
    talk-[:PREV]->(prev {interval,begin,end})

## Usage

### Setup Openbeacon Tracker

1. get openbeacon tags and reader, configure the reader via serial port to an ip network of your choice
2. power the reader via USB or PoE and connect to your machine, make sure to set it up as the _server-ip_ from the reader configuration
3. put batteries in the tags and use them
4. clone the [openbeacon github repository](https://github.com/meriac/openbeacon) 
5. go to `openbeacon/host/services/openbeacon-tracker`
5. enter your reader as `{0x457 /*=id 1111*/ , 1 /* room */, 1 /* floor */, 1 /* group */, 100 /* X */, 100 /* Y */},` in `bmReaderPositions.h`; run `make`
6. run ./openbeacon-tracker 2>&1 | ./filter-singularsighting logs/sightings.json
7. those json files can then be polled and inserted into the neo4j graph

### Ruby Scripts to insert into the Neo4j Graph

1. [download](http://neo4j.org/download) and unzip Neo4j server
* add `node_auto_indexing=true` and `node_keys_indexable=tag,name,twitter,github,interval` to `/path/to/neo4j/conf/neo4j.properties`
* start the server with `/path/to/neo4j/bin/neo4j start`
* run `ruby parse.rb ../testdata/sample.json`
* go to [local web interface](http;//localhost;7474)
* enter `node:index:node_auto_index:tag:*` in the *data browser* searchbar and hit `ctrl-enter` and press the rightmost "visualize" button
* enjoy and go hacking
