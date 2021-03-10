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
    @play_sub = []
    @er = []
    @proc_playOrSub = Proc.new {|x| x == 'play' || x == 'sub'}
    @playerHits = {}
    # hash of player IDs, fields are whatever I'm extracting at the moment
    # Currently: Hits, Singles, Doubles, Triples, HRs, Strikeouts (at bat)
    #            Walks
    @playerList = {}

    # default setup of player stat schema
    @emptyGameRecord = GameRecord.new

    # just collects all offensive plays by player code (i.e. all at-bats)
    # ignores subs for now, which includes pinch-hits and pinch-runs
    # dumps the raw play data
    @offensivePlays = {}

    # tracking who is currently playing in which position, for the purpose of
    #   assigning stats for plays on defense
    #   - this mainly changes when encountering a 'sub' play
    #   - 2d array, 0/1 at top level for vis/home,
    #     1-10 on 2nd level for position
    @currentDef = [['']*10, ['']*10]
    # current batting lineup
    # remember 0 is visiting, 1 is home
    @currentOff = [['']*10, ['']*10]

    # total of each player's defensive performance
    # each key is a player who participated in a recorded play
    # at the end of the game, the individual actions are tallied
    #   and added to the master DB of player stats along with gameID, etc
    #   - mainly recording total number of plays where ball was field to them
    #     and how many they threw out themselves
    @playerDefTotals = {}

    # total of each player's offensive performance throughout game.
    # Fields:
    # - total at-bats, strikes, balls, strikeouts, hits, on-bases, singles,
    #   doubles, triples, HRs, bunts, runners advanced (num of bases gained 
    #   total from all hits during game - so a single with 2 on is 3 bases 
    #   gained, 2 from runners and 1 from hitter)
    # - also includes bases stolen

    # start field 3: 1 for home, 0 for visiting
    # fielding positions are 1-9, 10 for DH, 11=pinch hit, 12=pinch run
    @homePositions = {}
    @visPositions = {}
  end

  def process(gameData)
    gameData.each do |row|
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
      # ignoring sub plays for now, only looking at batter performance
      # get decoded play, add to overall player tracking hash
      # at end of game, output everything into individual player hashes in 
      #   test.rb
      play = PlayDecoder.new(data[1..])
      add_play(play)

=begin
    when 'sub'
      # actually need to check in when play for play code 'NP,' these precede
      #   sub changes
      #   
      # include data[0] because we'll need to know if play or sub later
      @play_sub.push(data)
      #puts data.to_s
      #gets.chomp
=end
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
      #@playerList[play.batter][k] ||= 0
      @playerList[play.batter][k] += v
    end
  end

  def position_setup
    return nil
    # not implemented/used, this is for tracking defensive stats and also
    #   things like batting order etc
    # set up starting lineup and defensive positions
    # data format:
    # [playerID, player fullname, home/vis (1/0), batting order, defPosition]
    @start.each do |s|
      @currentOff[s[2]][s[3]] = s[0]
      @currentDef[s[2]][s[4]] = s[0]
    end
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
      #out += "\t#{k} : #{v}\n"
    end
    return out
  end

end
