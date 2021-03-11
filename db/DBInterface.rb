require 'sqlite3'

class DBInterface
  attr_accessor :db
  def initialize
    @db = SQLite3::Database.new ":memory:"
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

  def get_sum(col, playerId)
    # sum a column
    result = @db.execute("select SUM(#{col}) from playergames where playerId=#{playerId}")
    return result.next
  end

end
