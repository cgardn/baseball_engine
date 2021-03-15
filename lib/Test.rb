# class for testing generated model from analyze.rb

require './db/DBInterface'
require './lib/Rosters'
require './lib/Gamelogs'
require 'matrix'

class Test

  def initialize
    check_for_model
    @model = Marshal.load(File.read('./lib/analyzeResult'))
    @features = model[:features]
    @mean = model[:mean]
    @stddev = model[:stddev]
    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @db = DBInterface.new
  end

  def full_test(startNum, testLength)
    # TODO replace this with LDA
    # - everything in full_test is based on old (and incorrect) ideas, so it
    #   doesn't work right
    puts "Features: #{@features.to_s}\nMean: #{@mean}\nSTDDEV: #{@stddev}"

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

      # remove low atbats
      teamData[0]= teamData[0].filter {|row| row[0] > 50}
      teamData[1]= teamData[1].filter {|row| row[0] > 50}

      # convert hits/atbats to batting average
      teamData[0] = teamData[0].map {|row| 
        row[1..].map.with_index {|x, i| x.to_f/row[0]}
      }
      teamData[1] = teamData[1].map {|row| 
        row[1..].map.with_index {|x, i| x.to_f/row[0]}
      }

      # get diff in raw stats between two teams
      team0diff = (Matrix[score_team(teamData[0])] - Matrix[score_team(teamData[1])]).to_a[0]
      team1diff = (Matrix[score_team(teamData[1])] - Matrix[score_team(teamData[0])]).to_a[0]

      # sum chosen dimensions to get final scalar for z-scoring
      team0score = team0diff.filter.with_index{ |x,i| @features.include? i}.reduce(:+)
      team1score = team1diff.filter.with_index{ |x,i| @features.include? i}.reduce(:+)

      # get z-scores
      team0score = (team0score - @mean)/@stddev
      team1score = (team1score - @mean)/@stddev

      puts "Game: #{gameId}, #{teams[1]} at #{teams[0]}"
      puts "Z-scores:"
      puts "#{teams[0]}: #{team0score}"
      puts "#{teams[1]}: #{team1score}"

      sorted = [ [team0score, teams[0]], [team1score, teams[1]] ].sort {|a,b| b[0] <=> a[0]}

      winner = @gml.get_gamelog(gameId)[:winner]
      #threshold = @stddev*2
      threshold = 0

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

      puts "Predictions on #{numGuesses} out of #{idx+1} games so far"
      puts "#{numRight}/#{numGuesses} correct, #{((numRight.to_f/numGuesses)*100).truncate(2)}% correct"
    end
  end

  def score_team(dataBatch)
    # dataBatch is a 2d array, each row is a player's avg stats per game up
    #   to the game in question
    # this function averages each stat across the roster to estimate the 
    #   team's performance/strength
    return dataBatch.transpose.map{|x| x.reduce(:+)}.map{|y| y/dataBatch[0].length}
  end

  def check_for_model
    if !File.exist? './lib/analyzeResult'
      puts "ERROR: no generated model found. Please run 'analyze' to make one."
      exit
    end
  end

end
