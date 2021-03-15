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

  def generate_measurements(startNum, endNum)
    # all the gameIds are sorted in the playergames table, so startNum is 
    #   basically the index to start at
    # features: batting avg, avg(singles), avg(doubles), avg(triples),
    #           avg(homeruns), avg(strikeouts)
    #           - cumulative for each team's roster in that year, up to the
    #             game in question (exclusive)

    # set up table
    # need the chosen features for both teams along with team code and who won
    # tables: measurements - gameId, teamCode, features, isWinner (0 or 1)
    # note that the varchar length params are ignored by sqlite, included 
    #   here for portability to other SQL dbs
    tableName = 'measurements'
    colInfo = [
      {:name => 'gameId', :type => 'varchar(30)'},
      {:name => 'teamCode', :type => 'varchar(3)'},
      {:name => 'isWinner', :type => 'int',
        :notNull => 'true', :default => '0'},
      {:name => 'battingaverage', :type => 'real',
        :notNull => 'true', :default => '0'},
      {:name => 'singles', :type => 'int', 
        :notNull => 'true', :default => '0'},
      {:name => 'doubles', :type => 'int',
        :notNull => 'true', :default => '0'},
      {:name => 'triples', :type => 'int',
        :notNull => 'true', :default => '0'},
      {:name => 'homeruns', :type => 'int',
        :notNull => 'true', :default => '0'},
      {:name => 'strikeouts', :type => 'int',
        :notNull => 'true', :default => '0'},
    ]
    @db.drop_table(tableName)
    @db.create_new_table(tableName, colInfo)

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
