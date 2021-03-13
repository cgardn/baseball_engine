# Read player gamelogs and create per-team-per-game signals, like team's 
#   cumulative batting average, etc
# Could be anything - including starting pitcher ERA, total hits of top 5 
#   starting batters, etc. The point is to create a table of measurements
#   that can be loaded and quickly scanned for training and testing
#
# TODO
#   - put separation of test + training sets in here
#     - ideally two different tables with some descriptive name based on the
#       date? or something idk yet
#     - identically handled, but test will only use who the winning team is to
#       check 

class Measure

  def initialize
    @db = DBInterface.new
    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @lastGameId = ''
  end

  def generate_measurements(startNum, analyzeLength)
    # all the gameIds are sorted in the playergames table, so startNum is 
    #   basically the index to start at
    # features: batting avg, avg(singles), avg(doubles), avg(triples),
    #           avg(homeruns), avg(strikeouts)
    #           - cumulative for each team's roster in that year, up to the
    #             game in question (exclusive)
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
