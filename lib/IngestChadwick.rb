require './lib/BaseIngest'
require './lib/SingleGame'
#require './db/DBInterface'
require './lib/Gamelogs'
require './lib/Logger'
require 'csv'


# TODO methodological: 
# - no defensive stats, or pitching stats
# - missing offense stats: RBIs, steals, etc
# - not exactly the correct definition of a hit (missing rules/detection
#     for bunts/sac bunts/sac flys/etc)
# TODO technical:
# - replace my own parsing with chadwick tool
# - put data in new/existing table
# - table add/drop/rename options

class IngestChadwick < BaseIngest

  def initialize(dbRef, tableName)
    super
    @testMode = false

    @newGame = false
    @newFile = true
    @rawData = []

    # TODO replace this with YAML config
    #      also needs types assigned, currently doing this manually
    @fieldsHome = "-f 0,8,35,37,39 -x 35-48"
    @fieldsVis = "-f 0,7,34,36,38 -x 10-23"
    @headers = []
    
    # we use the Gamelogs class for winner/loser of a given gameId
    @gml = Gamelogs.new
    @gml.load_data
  end

=begin
  def get_headers(fieldString)
    # FIXME is there a cleaner way to do this?
    # we use a random event file here, since we're just collecting column
    #   headers
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y 1989 -n #{fieldString} 1989ATL.EVN`
        output = CSV.parse(output)[0]

        # remove home/away prefix from headers, home/vis is stored as separate
        #   field
        t = ['HOME', 'AWAY']
        output.map! {|h| t.include?(h[0..3]) ? h[5..] : h}

        return output
      end
    rescue => error
      log(error, error.backtrace)
      exit
    end
  end
=end

  def process_single_event_file(file)
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y #{fileName[0..3]} #{fieldString} #{fileName}`
        output = CSV.parse(output)
        # FIXME hardcoded assumption that the first two values are strings, and
        #      the rest are ints - requires YAML config with type hints
        output = output.map! {|row| row[0..1] + row[2..].map!(&:to_i)}
        return output
      end
    rescue => error
      log(error, error.backtrace)
      return nil
    end
  end

  def ingest_single_event_file(fileName, fieldString)
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y #{fileName[0..3]} #{fieldString} #{fileName}`
        output = CSV.parse(output)
        # FIXME hardcoded assumption that the first two values are strings, and
        #      the rest are ints - requires YAML config with type hints
        output = output.map! {|row| row[0..1] + row[2..].map!(&:to_i)}
        return output
      end
    rescue => error
      log(error, error.backtrace)
      return nil
    end
  end

  def ingest_raw_data
    super()
    # main processing of game event files

    # fixing header prefixes, adding home team and win true/false column
    @headers = get_field_names(@fieldsHome)
    @headers.push("HOME", "WIN")

    # check for headers before we start processing, so we don't get all the way to
    #   the end and have to exit without saving anything
    check_headers

    mainTimecheck = Time.now
    @fileList.each do |fName|
      #this single year is only for testing
    
      if @testMode
        if fName[0..3].to_i < 1989 || fName[0..3].to_i > 1989
          next
        end
      end
      if !@testMode && fName[0..3].to_i < @startYear
        next
      end

      # TODO FIXME sqlite3 gem has a way to insert straight out of a Hash
      #            look into this, the home/away and win/loss additions would
      #            be clearer with named attributes

      # get home/vis team data for this file (returns 2d array, each row is
      #   a home or away team's game data as specified in the fieldStrings)
      homeData = ingest_single_event_file(fName, @fieldsHome)
      visData = ingest_single_event_file(fName, @fieldsVis)

      unless !homeData
        # set home team and winner fields
        homeData = set_home_and_winner_fields(homeData, true)
        @rawData = @rawData.concat(homeData)
        puts "Finished #{fName} home"
      else
        puts "Skipped #{fName} Home data"
      end

      unless !visData
        # set home team and winner fields
        visData = set_home_and_winner_fields(visData, false)
        @rawData = @rawData.concat(visData)
      else
        puts "Skipped #{fName} Visitor data"
      end
    end

    # drop if exists, recreate table
    recreate_table

    # dumping into DB
    errCount = insert_data(@rawData)
    puts "Logged #{errCount} errors."

    puts "Completed in #{Time.now - mainTimecheck}"
  end

  # @param [Array] gameFileData 2D array of ingested data for home or away team
  # in a particular retrosheet event file
  # @param [Boolean] isHome Is this array of home or visitor data?
  # @return gameFileData with last two fields filled in: 'HOME' and 'WIN', 
  # indicating whether the given row was for a home team and winning team with 0 
  # or 1
  def set_home_and_winner_fields(gameFileData, isHome)
    gameFileData.each_with_index do |row, idx|
      begin
        row.push( (isHome ? 1 : 0) )
        gamelog = @gml.get_gamelog(row[0])
        if !gamelog
          # skip any games with no gamelog, we need to know who won
          gameFileData[idx] = nil
          next
        end
        if row[1] == gamelog[:winner]
          row.push(1)
        else
          row.push(0)
        end
      rescue => error
        log(error, row.to_s)
      end
    end
    return gameFileData.filter {|x| x != nil}
  end

end
