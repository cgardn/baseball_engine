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
#       - could also just add a 0/1 column called "train" 
#     - identically handled, but test will only use who the winning team is to
#       check 

require './lib/Rosters'
require './lib/Gamelogs'
require './lib/DBInterface'
require 'yaml'

# creates the actual values that are trained/tested on. May not be necessary
#   depending on your ingest implementation.
# For example: Each row in the ingested table represents one team's summary 
#   stats, but you want to train on the average of the last 5 games for each
#   stat. You can do this in the ingest method, or build a separate table here
#   if you want to preserve the raw ingested data in its own table, for doing
#   something different next time without having to re-scan all the original
#   text files.
# FIXME NB: this is still an old version, refactoring WIP.
class MeasureGame

  def initialize(tableName, dbRef)
    @db = dbRef

    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @lastGameId = ''
    @table = tableName
  end

  def table=(newTable)
    @table = newTable
  end

  def setup_table(tableName = '')
    # set up table
    # need the chosen features for both teams along with team code and who won
    # note that the varchar length params are ignored by sqlite, included 
    #   here for portability to other SQL dbs
    tableName ||= 'measurements'
    schemaString = 
      "gameId varchar(30), "\
      "teamCode varchar(3), "\
      "isWinner int NOT NULL DEFAULT 0, "\
      "battingaverage real NOT NULL DEFAULT 0, "\
      "singles int NOT NULL DEFAULT 0, "\
      "doubles int NOT NULL DEFAULT 0, "\
      "triples int NOT NULL DEFAULT 0, "\
      "homeruns int NOT NULL DEFAULT 0, "\
      "strikeouts int NOT NULL DEFAULT 0"

    @db.drop_table(tableName)
    @db.create_new_table(tableName, schemaString)
  end

  def generate_model(startRow, num)
    # starting at specified row of ingested data, build a model with num 
    #   records
    # generated model is saved at the end
  end

  def save_model
    if !Dir.exists? "./models"
      Dir.mkdir("./models")
    end

    fName = "#{@table}.model"
    i = 1
    while File.exists(fName)
      fName = "#{@table}_#{i}.model"
      i += 1
    end
    File.open("./models/#{fName}", 'w') do |f|
      f << @weights.to_yaml
    end
  end

  def get_saved_models(table)
    modelList = `ls ./models`.split.filter {|x| x.match(/#{table}/)}
    return modelList
  end

  def load_model(name)
    return YAML.load(File.read("./models/#{name}.model"))
  end

  def get_winner(r)
    # takes 2-row gamerecord set, returns string team code of winning team
    return r.sort{|a,b| a.last <=> b.last}[1][1]
  end

  def compare_values(col, num, gameId)
    # TODO only for testing? remove me later?
    # looks at avg value of col over previous num games before gameId
    records = @db.get_gamerecords(@table, gameId)
    teams = records.transpose[1]
    winner = get_winner(records)
    loser = teams.filter{|x| x != winner}[0]
    winVals =  @db.average_over_previous(col, winner, num, @table, gameId)
    loseVals =  @db.average_over_previous(col, loser, num, @table, gameId)
    return [winVals, loseVals]
  end

  def get_predictive_value(num, avgNum)
    # compares average values of col over avgNum games before a game, checks
    #   separation between winning and losing team over num games
    # output: mean and stddev of winning and losing team for given column
    measureList = (1..@gml.get_gameId_list.length-1).to_a.shuffle
    testList = []
    (measureList.length*0.2).to_i.times do |idx|
      testList << measureList.pop 
    end

    featureList = @db.get_column_names("measurements2")[2..]

    winAvg = {}
    loseAvg = {}

    num.times.with_index do |idx, idy|
      gameId = @gml.get_gameId_list[measureList[idx]]
      puts "measuring #{idy} of 1000"
      if idy != 0 && (idy % 100 == 0)
        puts "#{col} winner avg: #{(winAvg.reduce(:+))/winAvg.length}"
        puts "#{col} lose avg: #{(loseAvg.reduce(:+))/loseAvg.length}"
      end
      featureList.each do |feature|
        out = compare_values(feature, avgNum, gameId)
        winAvg[feature] ||= []
        loseAvg[feature] ||= []
        winAvg[feature].push(out[0])
        loseAvg[feature].push(out[1])
      end
    end
    begin
      featureList.each do |feature|
        puts "#{feature} winner avg: #{(winAvg[feature].reduce(:+))/winAvg[feature].length}"
        puts "#{feature} lose avg: #{(loseAvg[feature].reduce(:+))/loseAvg[feature].length}"
      end
    rescue => error
      puts error
      puts error.backtrace
      puts winAvg
      puts lostAvg
    end
  end

  def generate_measurements(startNum, endNum, tableName = '')
    setup_table((tableName ? tableName : "measurements"))
    # all the gameIds are sorted in the playergames table, so startNum is 
    #   basically the index to start at
    # features: batting avg, avg(singles), avg(doubles), avg(triples),
    #           avg(homeruns), avg(strikeouts)
    #           - cumulative for each team's roster in that year, up to the
    #             game in question (exclusive)

    @gml.get_gameId_list[startNum..endNum].each_with_index do |gameId, idx|
      begin
        puts "Analyzing #{gameId}, #{endNum-startNum-idx} remaining"
        teams = @gml.get_gamelog(gameId)[:teams]
        winner = @gml.get_gamelog(gameId)[:winner]
        year = gameId[3..6]

        teams.each do |teamId|
          roster = @rst.get_single_roster(teamId, year)
          stats = @db.get_avg_batch(roster, gameId)
          
          # didn't set default values on playergames table when ingesting data
          stats.map! {|row| row.map {|x| if x == nil then 0 else x end}}

          # remove players with low impact on team's batting stats
          # filter threshold must be somewhere above 0, just some players have 
          #   a handful of atbats without being regular batters
          stats = stats.filter {|row| row[0] > 50}

          # convert atbats and hits to batting average
          stats = stats.map {|row| 
            row[1..].map.with_index {|x, i| x.to_f/row[0]}
          }

          # average together each column to get team-wide stats
          avgStats = stats.transpose.map {|x| x.reduce(:+)}.map {|y| y/stats[0].length}
          row = [gameId, teamId, (teamId == winner ? 1 : 0)] + avgStats

          @db.add_measurement(row, tableName)
          @lastGameId = gameId
        end

      rescue => error
        # try to save last game finished if there's a problem
        puts "Error, attempting to save"
        puts error
        puts error.backtrace
        @db.save_to_disk
        File.write('./lib/lastGameAnalyzed', @lastGameId)
        exit
      end

    end
    # otherwise save between files
    @db.save_to_disk
    File.write('./lib/lastGameAnalyzed', @lastGameId)

  end
end
