# Retrosheet parser
#   only supports play-by-play .EVA/.EVN files
#   only batting information is parsed

class RSParser
  attr_accessor :fields

  def initialize
    @db = DBInterface.new
    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @lastGameId = ''
    
    # used for figuring out what data is where in the returned array
    @fields = ['playerId', 'gameId', 'atbats', 'hits', 'singles', 'doubles',
               'triples', 'homeruns', 'strikeouts']
  end

  def generate_gamerecords(file)
    # input: retrosheet game event file as read in by a CSV
    #        (each is for a whole team's home games in a given year)
    # output: Array where each row is a playerId, gameId, and cumulative 
    #         performance on some stats (atbats, hits, singles, doubles, 
    #         triples, homeruns, strikeouts [at the plate])
    begin
  end

  def 

  def generate_measurements(startNum, analyzeLength)
    # colList: batting avg, avg(singles), avg(doubles), avg(triples), avg(homeruns), avg(strikeouts)"
    # definitely start a ways in, make sure there's some data
    @gml.get_gameId_list[startNum..analyzeLength].each_with_index do |gameId, idx|
      @lastGameId = gameId
      begin
      puts "Analyzing #{gameId}, #{analyzeLength-startNum-idx} remaining"
      teams = @gml.get_gamelog(gameId)[:teams]
      year = gameId[3..6]

      # team and roster setup
      #t = Time.now
      winTeam = @gml.get_gamelog(gameId)[:winner]
      winRoster = @rst.get_single_roster(winTeam, year)
      loseTeam = @gml.get_gamelog(gameId)[:loser]
      loseRoster = @rst.get_single_roster(loseTeam, year)
      #puts "team+roster setup: #{Time.now - t}"

      #t = Time.now
      winTeamData = @db.get_avg_batch(winRoster, gameId)
      loseTeamData = @db.get_avg_batch(loseRoster, gameId)
      #puts "SQL calls time: #{Time.now - t}"

      # didn't set null=false/default=0 on sql db
      #t = Time.now
      winTeamData.map! {|row| row.map {|x| if x == nil then 0 else x end}}
      loseTeamData.map! {|row| row.map {|x| if x == nil then 0 else x end}}
      #puts "nil fix time: #{Time.now - t}"

      # avg all values for team average at start of game
      #t = Time.now
      winAccum = winTeamData.transpose.map {|x| x.reduce(:+)}.map {|y| y/winTeamData[0].length}
      loseAccum = loseTeamData.transpose.map {|x| x.reduce(:+)}.map {|y| y/winTeamData[0].length}
      #puts "map/reduce time: #{Time.now - t}"

      @db.add_measurement((Matrix[winAccum] - Matrix[loseAccum]).to_a[0])

      rescue

      @db.save_to_disk
      File.write('./lib/lastGameAnalyzed', @lastGameId)
      end

    end
    @db.save_to_disk
    File.write('./lib/lastGameAnalyzed', @lastGameId)

  end
end
