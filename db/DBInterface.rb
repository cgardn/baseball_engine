require 'sqlite3'

class DBInterface
  
  def initialize
    # there are ways to read from disk into memory, then dump at the end
    # but the bottleneck is somewhere in the processing
    #@db = SQLite3::Database.open ":memory:"
    @db = SQLite3::Database.open "./db/db.db"
  end

  def add_game(gameData)
    # insert one game's worth of records (many players)
    timecheck = Time.now
    gameData.each do |k,v|
      if v[:atbats] > 100
        puts v.to_s
        gets.chomp
      end
      @db.execute("
        insert into playergames (playerId, gameId, atbats, hits, strikes, balls, singles, doubles, triples, homeruns, walks, strikeouts)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [k, v[:gameId], v[:atbats], v[:hits], v[:strikes], v[:balls], v[:singles], v[:doubles], v[:triples], v[:homeruns], v[:walks], v[:strikeouts]])
    end
    puts "Addgame time: #{Time.now - timecheck}"
  end

  def reset_db
    @db.execute("drop table if exists playergames")
    @db.execute("create table playergames (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
  end

end
