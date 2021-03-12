require './db/DBInterface'
require './Rosters'
require './Gamelogs'
require 'matrix'

class Analyze

  DB = DBInterface.new
  RST = Rosters.new
  RST.load_data
  GML = Gamelogs.new
  GML.load_data

  # load each year's roster into memory
  # load full gamelog into memory
  # generate test list
  # for each game (skip if on test list)
  #   - get winning/losing team from gamelog (look at scores)
  #   - get rosters for both teams (list of playerIds)
  #   - get gameId from gamelog: assemble from home team code, date, and game#
  #   - get each player's accumulated career avg stats per game from big db 
  #       for each stat
  #   - get total avg of avg stats across roster for each time
  #   - sub winning team overall avgs from losing team and record somewhere
  # do stat/distribution analysis on diffs
  # do test against skiplist games
  #   - get teams from gamelog (incl. winner/loser)
  #   - look at avg cumulative stats per game for both teams, make prediction
  #   - compare to actual winner
  #   - record if prediction was correct or not and save with gameId somewhere
  # at end, sum overall frequency of correctness/% correct
  
  def batting_avg_before_game(playerId, gameId)
  end

  def self.analyze(startNum, analyzeLength)
    # colList: batting avg, avg(singles), avg(doubles), avg(triples), avg(homeruns), avg(strikeouts)"
    # definitely start a ways in, make sure there's some data
    GML.get_gameId_list[startNum..analyzeLength].each_with_index do |gameId, idx|
      puts "Analyzing #{gameId}, #{analyzeLength-startNum-idx} remaining"
      teams = GML.get_gamelog(gameId)[:teams]
      year = gameId[3..6]

      # team and roster setup
      #t = Time.now
      winTeam = GML.get_gamelog(gameId)[:winner]
      winRoster = RST.get_single_roster(winTeam, year)
      loseTeam = GML.get_gamelog(gameId)[:loser]
      loseRoster = RST.get_single_roster(loseTeam, year)
      #puts "team+roster setup: #{Time.now - t}"

      #t = Time.now
      winTeamData = DB.get_avg_batch(winRoster, gameId)
      loseTeamData = DB.get_avg_batch(loseRoster, gameId)
      #puts "SQL calls time: #{Time.now - t}"

      # didn't set null=false/default=0 on sql db
      t = Time.now
      winTeamData.map! {|row| row.map {|x| if x == nil then 0 else x end}}
      loseTeamData.map! {|row| row.map {|x| if x == nil then 0 else x end}}
      puts "nil fix time: #{Time.now - t}"

      # avg all values for team average at start of game
      t = Time.now
      winAccum = winTeamData.transpose.map {|x| x.reduce(:+)}.map {|y| y/winTeamData[0].length}
      loseAccum = loseTeamData.transpose.map {|x| x.reduce(:+)}.map {|y| y/winTeamData[0].length}
      puts "map/reduce time: #{Time.now - t}"

      puts (Matrix[winAccum] - Matrix[loseAccum]).to_a[0].to_s
      gets.chomp

      DB.write(
      DB.save_to_disk
      File.write('./lastGameAnalyzed', gameId)

    end

  end

end

a = Analyze.analyze
