require './db/DBInterface'
require './Rosters'
require './Gamelogs'
require 'matrix'

class Analyze
  attr_accessor :db

  def initialize
    @measureData = []
    @db = DBInterface.new
    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @lastGameId = ''
    @normalizedData = []
    @analyzeResult = []
    @testIndexes = []
  end

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

  def self.generate_measurements(startNum, analyzeLength)
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
      File.write('./lastGameAnalyzed', @lastGameId)
      end

    end
    @db.save_to_disk
    File.write('./lastGameAnalyzed', @lastGameId)

  end

  def analyze_measurements
    # cols: battingaverage, singles, doubles, triples, homeruns, strikeouts
    # method:
    # - get mean and stddev on each col
    # - variance can be calculated directly in sql with avg() and -, square
    #   after
    # 
    # - find correlations, plot if necessary
    # population variance = sum( (sample-mean)^2 )/(pop size)
    # sample variance = sum( (sample-mean)^2) )/(sample size - 1)
    #   : this is called "Bessell's correction"
    # stddev = sqrt(variance)
    # standardError = stddev/(samplesize^2)

    # rows of data, one per game
    # each entry is the average of the entire roster on that stat, averaged 
    #   over each player's career up to but not including the game in question
    #   - do this for both winning and losing teams, and get difference
    #   - each entry in measurements is the difference on the averaged stats
    #     on the winning team
    #   - ex: -1.5 on strikeouts means the winning team's roster overall avg'd
    #         1.5 fewer K's when at bat vs the losing team, per game 
    # all stats seem to be individually normally distributed around 0
    # going to look at combinations of stats and see if the distribution
    #   shifts when combining stats
    # BattingAverage, s,d,t,hr,k
    @measureData = @db.db.execute("select * from measurements")
    
    # generate test indexes to skip
    @testIndexes = Array.new(@measureData.length*0.2)
    @testIndexes.each_with_index do |t,i|
      num = rand(@measureData.length-1)
      while @testIndexes.include? num
        num = rand(@measureData.length-1)
      end
      @testIndexes[i] = num
    end

    # flip signs on K's, since fewer K's is better but we're doing sums
    @measureData.map! {|row| row[0..4].push(-row[5])}
    # get combinations of stat indices
    combos = []
    6.times do |i|
      combos.concat([0,1,2,3,4,5].combination(i+1).to_a)
    end

    # Ranking stats by impact
    # for each combination of stats, get scores (sum of avg'd stats) 
    #    on each gamerecord, then save mean+stddev to output array with combo
    # 
    # start with a list for the scores from each combo of stats, for each 
    #   gamerecord. Should be an array with shape (numCombos, recordLength)
    result = Array.new(combos.length)
    combos.each_with_index do |c, idx|
      puts "checking combination #{idx+1} of #{combos.length}"
      scores = []
      # all scores for this combination of stats
      #@normalizedData.each_with_index do |row, idy|
      @measureData.each_with_index do |row, idy|
        if @testIndexes.include? idy
          # skip test games
          next
        end
        # sum the features in this combo
        scores.push row.filter.with_index{|x,i| c.include? i}.reduce(:+)
      end
      # mean
      mean = scores.reduce(:+)/scores.length
      # stddev, with Bessell's correction for sample variance
      variance = scores.map{|x| (x-mean)**2}.reduce(:+)/(scores.length-1)
      stddev = Math.sqrt(variance)

      result[idx] = [c, mean, stddev]
    end

    # this sorts the highest mean to the bottom
    # essentially, the higher the mean the more winning teams have these stats
    #   positive (higher than losing team)
    result.sort! {|a,b| b[1] <=> a[1]}
    @analyzeResult = result[0]
    #result.each {|r| puts "#{r.to_s}\n"}

    # from this, we determined that singles, triples, and strikeouts have the
    #   highest impact with the current dataset
    # a score is derived from normalizing team-wide avgs of singles, triples, 
    #   and -(strikeouts) per game across the team to the range (-1..1).
    #   Sum those three together and subtract one team's score from the other,
    #   if that score is at least 0.067 higher, that team has a 50% chance of
    #   winning.
    # highest is .067, meaning 50% of winning teams have an average difference
    #   of the normalized sum of singles, triples, and -(strikeouts) 
    #
    # the model derived is this:
    # - normalize team avg singles, triples, and -(strikeouts) vs losing team
    # - 

  end

  def normalize_to_range(val, oldMin, oldMax, newMin, newMax)
    # normalize to 0-1
    range = oldMax - oldMin
    val = (val-oldMin)/range
    # scale to newMin-newMax
    range = newMax - newMin
    val = (val * range) + newMin
    return val
  end

  def test_model
    # - z-score = (N-mean)/stddev
    #   values of 0 are at the mean, add 0.5 to z. This is the % of winning 
    #   teams with at least this score in the training set

    # result from analyze is in the form [stat combo, mean, stddev]
    puts "in test_model"

    numRight = 0
    #@normalizedData.each_with_index do |row, idx|
    @measureData.each_with_index do |row, idx|
      if !@testIndexes.include? idx
        # skip training data
        next
      end
       
      # even though these scores are from winners, we can still test by 
      #   just looking at the z-score and deciding if it is inside our chosen
      #   threshold (say 0.3). We then tabulate how many games fall inside
      #   the threshold, and that is how often we'd be correct - because all
      #   of the games here are winners
     
      threshold = 0.3
      score = row.filter.with_index {|x, i| @analyzeResult[0].include? i}.reduce(:+)
      if (score-@analyzeResult[1])/@analyzeResult[2] >= threshold
        numRight += 1
      end
    end
    puts "#{((numRight.to_f*100)/@testIndexes.length).truncate(2)}% of winners meet threshold"
  end

  def full_test(startNum, testLength)
    numGuesses = 0
    numRight = 0
    @gml.get_gameId_list[startNum..testLength].each_with_index do |gameId, idx|
      teams = @gml.get_gamelog(gameId)[:teams]
      year = gameId[3..6]
      rosters = teams.map{|t| @rst.get_single_roster(t, year)}
      teamData = rosters.map{|r| @db.get_avg_batch(r, gameId)}

      # didn't set null=false/default=0 on sql db
      # these next few pairs of ops aren't very rubyish, I know, but I'm 
      #   coming back to neaten and refactor it all I swear!! :)
      teamData[0].map!{|row| row.map{|x| if x == nil then 0 else x end}}
      teamData[1].map!{|row| row.map{|x| if x == nil then 0 else x end}}

      # get diff in raw stats between two teams
      team0diff = (Matrix[score_team(teamData[0])] - Matrix[score_team(teamData[1])]).to_a[0]
      team1diff = (Matrix[score_team(teamData[1])] - Matrix[score_team(teamData[0])]).to_a[0]

      # sum chosen dimensions to get final scalar for z-scoring
      team0score = team0diff.filter.with_index{ |x,i| @analyzeResult[0].include? i}.reduce(:+)
      team1score = team1diff.filter.with_index{ |x,i| @analyzeResult[0].include? i}.reduce(:+)

      # get z-scores
      team0score = (team0score - @analyzeResult[1])/@analyzeResult[2]
      team1score = (team1score - @analyzeResult[1])/@analyzeResult[2]

      puts "Game: #{gameId}, #{teams[1]} at #{teams[0]}"
      puts "Z-scores:"
      puts "#{teams[0]}: #{team0score}"
      puts "#{teams[1]}: #{team1score}"

      sorted = [ [team0score, teams[0]], [team1score, teams[1]] ].sort {|a,b| b[0] <=> a[0]}

      winner = @gml.get_gamelog(gameId)[:winner]
      threshold = @analyzeResult[2]*2

      if sorted[0][0] >= threshold
        puts "#{sorted[0][1]} over #{threshold}, winner predicted:"
        numGuesses += 1
      else
        puts "None over #{threshold}, no prediction"
      end
      puts "Winner: #{winner}"

      if sorted[0][0].to_f >= threshold && sorted[0][1] == winner
        numRight += 1
      end

      puts "Predictions on #{numGuesses} out of #{idx} games so far"
      puts "#{numRight}/#{numGuesses} correct, #{(numRight.to_f/numGuesses).truncate(2)}% correct"
    end
  end

  def score_team(dataBatch)
    # dataBatch is a 2d array, each row is a player's avg stats per game up
    #   to the game in question
    # this function averages each stat across the roster to estimate the 
    #   team's performance/strength
    return dataBatch.transpose.map{|x| x.reduce(:+)}.map{|y| y/dataBatch[0].length}
  end

end
