class MarshalDB
  attr_accessor :data
  def initialize
    @dbPath = './marshaldb.db'
    puts "initializing marshaled db..."
    if File.exist? @dbPath
      @data = Marshal.load(File.open(@dbPath).read)
    else
      @data = {}
    end
    puts "end"
  end

  def add_game(newData, gameID)
    newData.each do |playerID, statDelta|
      @data[playerID] ||= {}
      @data[playerID][gameID] ||= {}
      
      if !@data[playerID][gameID]
        newData[playerID].each do |k,v|
          @data[playerID][gameID][k] = v
        end
      else
        newData[playerID].each do |k,v|

          @data[playerID][gameID][k] += v
        end
      end
      newData[playerID].each do |k,v|
        @data[playerID][gameID][k] ||= 0
        @data[playerID][gameID][k] += v
      end
    end
  end

  def get_stats
    playerCount = @data.length
    avgGames = 0
    @data.each do |p|
      avgGames += p.length
    end
    avgGames = avgGames/playerCount

    puts "DB Stats: 
      Number of Players: #{playerCount}
      Average Games played: #{avgGames}"
    puts "Sample: 
      #{data.keys[0]} : #{data[data.keys[0]]}"
  end

  def load
  end

  def write
    puts "writing to marshalldb.db"
    File.open('./marshalldb.db', 'w') {|f|
      f.write Marshal.dump(@data)
    }
    puts "end"
  end
end
