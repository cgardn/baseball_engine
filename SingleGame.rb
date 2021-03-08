class SingleGame
  # processes a single game, a row at a time
  def initialize
    @id = ''
    @info = {}
    @start = []
    @play_sub = []
    @er = []
    @proc_playOrSub = Proc.new {|x| x == 'play' || x == 'sub'}

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
    @playerOffTotals = {}

    # start field 3: 1 for home, 0 for visiting
    # fielding positions are 1-9, 10 for DH, 11=pinch hit, 12=pinch run
    @homePositions = {}
    @visPositions = {}
  end

  def process_row(data)
    case data[0]
    when 'id'
      @id = data[1]
    when 'info'
      @info[data[1]] = data[2]
    when 'start'
      @start.push(data[1..])
    when @proc_playOrSub
      # include data[0] because we'll need to know if play or sub later
      @play_sub.push(data)
    when 'data'
      # these are actually earned runs
      if data[1] == 'er'
        @er.push(data[2..])
      end
    end
  end

  def position_setup
    # set up starting lineup and defensive positions
    # data format:
    # [playerID, player fullname, home/vis (1/0), batting order, defPosition]
    @start.each do |s|
      @currentOff[s[2]][s[3]] = s[0]
      @currentDef[s[2]][s[4]] = s[0]
    end
  end

  def record_atbats
    # for each play, record batting player and what they did
    @play_sub.each do |row|
    end
  end

  def sub_player(newPlayer)
    # [playerID, player fullname, home/vis (1/0), batting order, defPosition]
    @currentOff[newPlayer[2]][newPlayer[3]] = newPlayer[0]
    @currentDef[newPlayer[2]][newPlayer[4]] = newPlayer[0]
  end

  def separate_player_data
    return nil
  end

  def clear
    initialize
  end

  def has_data?
    return !@id.empty?
  end

  def to_s
    "Processed game info: \n
     ID: #{@id}\n
     Home: #{@info['hometeam']}
     Away: #{@info['visteam']}
     Starters: #{@start.to_s}
     Plays: #{@play_sub.count}
     Errors: #{@er.count}\n
     ---
     Player Off: #{@currentOff.to_s}
     Player Def: #{@currentDef.to_s}"
  end
end
