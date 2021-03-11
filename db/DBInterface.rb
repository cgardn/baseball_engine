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

  def has_record?(playerId, gameId)
    # this takes ~0.02s per search on a non-indexed column, to see if the 
    #   record already exists. since plays make up at least half of a gamefile
    #   there's something like 5m+ plays that need to be checked, so 0.02s
    #   per play adds up to an extra 27 hours give or take
    # By contrast, skipping the check and just re-writing the whole db takes
    #
    t = Time.now
    begin
      results = @db.execute "SELECT * FROM playergames WHERE playerId=? AND gameId=?", playerId, gameId
    rescue
      puts "Error in DBInterface::has_record? query"
      gets.chomp
    end
    t1 = "T1: #{Time.now - t}"
    t = Time.now
    out = results.count
    t2 = "T2: #{Time.now - t}"
    t = Time.now
    out = out.nonzero?
    t3 = "T3: #{Time.now - t}"
    puts "#{t1}\n#{t2}\n#{t3}"
    return out
  end

  def add_game(gameData)
    # insert one game's worth of records (many players)
    # check for existing records first

    gameData.each do |k,v|
      @db.execute("
        insert into playergames (playerId, gameId, atbats, hits, strikes, balls, singles, doubles, triples, homeruns, walks, strikeouts)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [k, v[:gameId], v[:atbats], v[:hits], v[:strikes], v[:balls], v[:singles], v[:doubles], v[:triples], v[:homeruns], v[:walks], v[:strikeouts]])
    end
  end

  def reset_db
    @db.execute("drop table if exists playergames")
    create_table
    #@db.execute("create table if not exists playergames (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
  end

  def create_table
    @db.execute("create table if not exists playergames (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
  end

  def get_sum(col, playerIdList, gameId='')
    # sum a column for specific player, optionally up to specific gameId
    #   (exclusive)
    qString = (','.concat('?')*playerIdList.length).slice(1..)
    qry = "select playerId, sum(#{col}) from playergames where playerId in (#{qString}) and substr(gameId, 4) < '#{gameId[3..]}' group by playerId"
    
    # batch of playerIds
    if gameId != ''
      result = @db.execute(qry, playerIdList)
    else
      result = @db.execute("select SUM(#{col}) from playergames where playerId='#{playerId}'")
    end

    return result
  end

  def get_avg_batch(col, playerIdList, gameId='')
    # get average stat value on column up to gameId (exclusive)
    # returns array of [playerId, avgStat]
    qString = (','.concat('?')*playerIdList.length).slice(1..)
    qry = "select playerId, avg(#{col}) from playergames where playerId in (#{qString}) and substr(gameId, 4) < '#{gameId[3..]}' group by playerId"
    result = @db.execute(qry, playerIdList)
    return result
  end

  def get_player_gamecount(playerId, gameId='')
    # get total number of games played by specific player, optionally up to
    # specific gameId (exclusive)
    
    if gameId != ''
      result = @db.execute("select count (distinct gameId) from playergames where playerId='#{playerId}' AND substr(gameId, 4) < '#{gameId[3..]}'")
    else
      result = @db.execute("select count (distinct gameId) from playergames where playerId='#{playerId}'")
    end
    return result[0]
  end

  def get_records_before_game(playerId, gameId, col)
    # get all game records for given player up to gameId (exclusive)
    cmd = "select #{col} from playergames where playerId='treaj001' and substr(gameId, 4) < '#{gameId[3..]}'"
    puts cmd
    gets.chomp
    result = @db.execute("select #{col} from playergames where playerId='#{playerId}' and substr(gameId, 4) < '#{gameId[3..]}'")
    return result
  end

  def get_avg_stat_at_point(col, playerId)
    # get the average value of a particular column up to specific gameId for
    # a given player
  end

end
