require 'sqlite3'

class DBInterface
  
  def initialize
    @db = SQLite3::Database.open "./db/db.db"
  end

  def add_game(gameData)
    # insert one game's worth of records (many players)
    gameData.each do |k,v|
      @db.execute("
        insert into players (playerId, gameId, atbats, hits, strikes, balls, singles, doubles, triples, homeruns, walks, strikeouts)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [k, v[:gameId], v[:atbats], v[:hits], v[:strikes], v[:balls], v[:singles], v[:doubles], v[:triples], v[:homeruns], v[:walks], v[:strikeouts]])
    end
  end

  def reset_db
    @db.execute("drop table if exists players")
    @db.execute("create table players (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
  end

end
