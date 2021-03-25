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
require './db/DBInterface'

class Measure

  def initialize
    @db = DBInterface.new
    @rst= Rosters.new
    @rst.load_data
    @gml = Gamelogs.new
    @gml.load_data
    @lastGameId = ''
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

  def average_over_previous_games(col, num, gameId)
    # get the average value of a column over num previous games
    #   up to, but not including, gameId
    # this is mainly an sql command, how much should be pushed down to
    #   DBInterface?
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
