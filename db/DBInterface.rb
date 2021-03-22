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

  def drop(table)
    @db.execute("drop table if exists #{table}")
  end

  def get_table_names
    @db.execute("select name from sqlite_master where type='table'").reduce(:+)
  end

  def has_table?(tableName)
    get_table_names.include? tableName
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

  def get_column_names(tablename)
    # returns array of string names of table columns, in the order they appear
    #   in the DB
    return @db.execute("PRAGMA table_info(#{tablename})").transpose[1]
  end

  def add_game(gameData)
    # insert one game's worth of records (many players)
    # for reference: value insertion limited to 999 values

    gameData.each do |k,v|
      @db.execute(
        "insert into playergames "\
          "(playerId, gameId, atbats, hits, strikes, balls, "\
          "singles, doubles, triples, homeruns, walks, strikeouts) "\
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", 
          [k, v[:gameId], v[:atbats], v[:hits], v[:strikes], 
          v[:balls], v[:singles], v[:doubles], v[:triples], 
          v[:homeruns], v[:walks], v[:strikeouts]]
      )
    end
  end

  def insert(tableName, headers, row)
    execString = "insert into #{tableName}"
    headerString = "(#{headers.join(', ')})"
    vString = "VALUES (#{row.join(", ")})"
    puts "#{execString} #{headerString} #{vString}"
    STDIN.gets

    st = @db.prepare("#{execString} #{headerString} #{vString}")
    puts "Prepared statement"
    puts st.to_s
    STDIN.gets
  end

  def add_measurement(row, tableName)
    # add a single measurement row into specified database
    @db.execute(
      "insert into #{tableName} "\
        "(gameId, teamCode, isWinner, battingaverage, singles, doubles, "\
        "triples, homeruns, strikeouts) "\
      "VALUES (?,?,?,?,?,?,?,?,?)", 
      row
    )
  end

  def drop_table(tablename)
    puts "Drop table: #{tablename} - Bail out if this isn't right!"
    STDIN.gets
    puts "Ok, I'm doing it then..."
    @db.execute("drop table if exists #{tablename}")
    puts "done."
  end

  def reset_db
    @db.execute("drop table if exists playergames")
    create_table
  end

  def create_table
    @db.execute("create table if not exists playergames (playerId varchar(30), gameId varchar(30), atbats int, hits int, strikes int, balls int, singles int, doubles int, triples int, homeruns int, walks int, strikeouts int);")
  end

  def create_new_table(tableName, schemaString)
    # input: 
    #   String tableName
    #   String schemaString - just a long string for SQL table definition
    @db.execute("create table if not exists #{tableName} (#{schemaString});")
  end

  def get_avg_batch(playerIdList, gameId='')
    # get players' career cumulative stats on columns specified below up to 
    #   gameId (exclusive)
    # returns array of [ [player1stat1, ...] [player2stat1,...] ]
    
    # FIXME this query is slow - 1.7s on avg, prioritize optimizing this
    colList = "sum(atbats), sum(hits), sum(singles), sum(doubles), "\
              "sum(triples), sum(homeruns), sum(strikeouts)"
    qString = (','.concat('?')*playerIdList.length).slice(1..)
    qry = "select #{colList} from playergames where "\
          "substr(gameId, 4) < '#{gameId[3..]}' and "\
          "playerId in (#{qString}) group by playerID"

    result = @db.execute(qry, playerIdList)
    return result
  end

end
