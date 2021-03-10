require './PlayDecoder'

class GameRecord < Struct.new(:playerId, :gameId, :atbats, :hits, :strikes, :balls, :singles, :doubles, :triples, :homeruns, :walks, :strikeouts)
  def initialize(
      playerId = '', gameId = '', atbats = 0, hits = 0, strikes = 0,
      balls = 0, singles = 0, doubles = 0, triples = 0, homeruns = 0, 
      walks = 0, strikeouts = 0
  )
    super
  end
end

class SingleGame
  attr_reader :playerList, :id
  # processes a single game, a row at a time
  # input: raw Retrosheet season file: [year][teamcode].EV*, i.e. 1989ATL.EVN
  # output: single file with list of playerIDs, and each offensive play
  #         they made along with gameID
  def initialize
    @id = ''
    @info = {}
    @start = []
    @er = []

    # hash of player IDs, values are GameRecords 
    @playerList = {}
  end

  def reset
    initialize
  end

  def process(gameData)
    gameData.each do |row|
      if row.include? 'NP' then next end
      process_row(row)
    end
  end

  def process_row(data)
    case data[0]
    when 'id'
      @id = data[1]
    when 'info'
      @info[data[1]] = data[2]
    when 'start'
      @start.push(data[1..])
    when 'play'
      # get decoded play, add to overall player tracking hash
      play = PlayDecoder.new(data[1..])
      add_play(play)
    when 'data'
      # these are actually earned runs
      if data[1] == 'er'
        @er.push(data[2..])
      end
    end
  end

  def add_play(play)
    @playerList[play.batter] ||= GameRecord.new
    @playerList[play.batter].gameId = @id
    @playerList[play.batter].playerId = play.batter
    play.get_play.each do |k,v|
      @playerList[play.batter][k] += v
    end
    
    #if play.batter == 'treaj001'
    #  puts "Game: #{@id}"
    #  puts "Play: #{play}"
    #  puts "Atbats so far: #{@playerList[play.batter][:atbats]}"
    #end
  end

  def sub_player(newPlayer)
    # not implemented, not tracking defensive stats yet
    return nil
  end

  def has_data?
    return !@id.empty?
  end

  def to_s
    "Processed game info: \n
     ID: #{@id}\n
     Records:
       #{print_player_stats}"
  end

  def print_player_stats
    out = ""
    @playerList.each do |k,v|
      # each is now a GameRecord
      out += "\t#{v.to_s}\n"
    end
    return out
  end

end
