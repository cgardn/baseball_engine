require 'sqlite3'

class DBInterface
  attr_accessor :db
  def initialize
    @db = SQLite3::Database.new ":memory:"
    load_from_disk
    create_table
  end

  def setup
    load_from_disk
    create_table
  end

  def load_from_disk
    diskDB = SQLite3::Database.open "./db/db.sqlite3"
    b = SQLite3::Backup.new(@db, 'main', diskDB, 'main')
    puts "Loading DB into memory..."
    begin
      b.step(1)
    end while b.remaining > 0
    b.finish
    diskDB.close
    puts "done."
  end

  def save_to_disk
    diskDB = SQLite3::Database.open "./db/db.sqlite3"
    b = SQLite3::Backup.new(diskDB, 'main', @db, 'main')
    puts "Saving in-memory data to disk..."
    begin
      b.step(1)
    end while b.remaining > 0
    b.finish
    diskDB.close
    puts "done."
  end

  def add_game(gameData)
    # insert one game's worth of records (many players)

    gameData.each do |k,v|
      @db.execute("
        insert into playergames (playerId, gameId, atbats, hits, strikes, balls, singles, doubles, triples, homeruns, walks, strikeouts)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [k, v[:gameId], v[:atbats], v[:hits], v[:strikes], v[:balls], v[:singles], v[:doubles], v[:triples], v[:homeruns], v[:walks], v[:strikeouts]])
    end
  end

  def add_measurement(row)
    @db.execute("insert into measurements (battingaverage, singles, doubles, triples, homeruns, strikeouts) VALUES (?,?,?,?,?,?)", [row[0], row[1], row[2], row[3], row[4], row[5]])
  end

  def reset_db
    @db.execute("drop table if exists playergames")
    create_table
  end

  def create_table
    @db.execute("create table if not exists playergames (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
    # calculated difference between winning and losing team for these stats
    #   the average of all the players on the roster is taken
    @db.execute("create table if not exists measurements (battingaverage real, singles real, doubles real, triples real, homeruns real, strikeouts real);")
  end

  def get_avg_batch(playerIdList, gameId='')
    # get average stat value on columns specified below up to 
    #   gameId (exclusive)
    # returns array of [ [playerId, avgStat1, avgStat2,...] [playerId2,...] ]
    
    # FIXME this isn't the optimal place for this - I'd prefer something more
    # general/flexible, but because of a lack of foresight I haven't built
    # batting average in as a standalone column, only atbats and hits.
    # - because all the other columns are scalars getting averaged and just
    # the one is an arithmetic operation, I'm hardcoding the columns here for
    # now. I'll come back and make this more general/move column input up to
    # the analysis module at a later date
    #
    # FIXME also this query is slow - 1.7s on avg, prioritize optimizing this
    colList= "cast(hits as real) / atbats, avg(singles), avg(doubles), avg(triples), avg(homeruns), avg(strikeouts)"
    qString = (','.concat('?')*playerIdList.length).slice(1..)

    qry = "select #{colList} from playergames where playerId in (#{qString}) and substr(gameId, 4) < '#{gameId[3..]}' group by playerId"
    result = @db.execute(qry, playerIdList)
    return result
  end

end
