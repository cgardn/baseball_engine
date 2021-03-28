# originally the do-everything class, slowly moving toward just model training
# this is where the selection of model type will live, since specifically 
#   which features are being used isn't relevant to the type of model - that
#   choice happens entirely before, in the Measure module

require './lib/DBInterface'
require './lib/Rosters'
require './lib/Gamelogs'
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
  end

  def analyze_measurements
    # TODO replace with proper LDA
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
    
    # flip signs on K's, since fewer K's is better but we're doing sums
    @measureData.map! {|row| row[3..7].push(-row[8])}
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
      @measureData.each_with_index do |row, idy|
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
    result.sort! {|a,b| b[1] <=> a[1]}
    @analyzeResult = result[0]
    res = {'features': result[0][0], 'mean': result[0][1], 'stddev': result[0][2]}
    File.write('./lib/analyzeResult', Marshal.dump(res))

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
