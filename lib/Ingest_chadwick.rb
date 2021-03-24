require './lib/SingleGame'
require './db/DBInterface'
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

class Ingest
  def initialize(tableName)
    @testMode = false
    @startYear = 1989

    @newGame = false
    @newFile = true
    @rawData = []
    @tableName = tableName
    @logger = Logger.new

    # TODO replace this with YAML config
    #      also needs types assigned, currently doing this manually
    @fieldsHome = "-f 0,8,35 -x 35-48"
    @fieldsVis = "-f 0,7,34 -x 10-23"
    @headers = []

    @db = DBInterface.new
    
    # we use the Gamelogs class for winner/loser of a given gameId
    @gml = Gamelogs.new
    @gml.load_data

    check_for_gamefiles

    # FIXME drop this once chadwick fully operational? fast enough to not
    #       bother?
    @lastFile= (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''
    if @lastFile
      @fileList.slice!(@fileList.find_index(@lastFile)+1..)
    end
  end

  def generate_schema_string(cols)
    out = "#{cols[0]} varchar(30), #{cols[1]} varchar(3), "
    out += cols[2..].map {|s| "\"#{s}\" int NOT NULL DEFAULT 0"}.join(', ')
    return out
  end

  def get_field_names(fieldString)
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
      @logger.log(error)
      @logger.log(error.backtrace)
      exit
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
      @logger.log(error)
      @logger.log(error.backtrace)
      return nil
    end
  end

  def ingest_raw_data
    # main processing of game event files
    # TODO include tagging entries with win or loss
    # TODO take each game event and separate home and vis team into their own
    #      rows
    
    # give user a chance to avoid overwriting an existing table
    if @db.has_table? @tableName
      puts "Table #{@tableName} exists. Bail out now, or continue to overwrite"
      STDIN.gets
    end

    # fixing header prefixes, adding home team and win true/false column
    @headers = get_field_names(@fieldsHome)
    @headers.push("HOME", "WIN")

    mainTimecheck = Time.now
    @fileList.each do |fName|
      #this single year is only for testing
      if @testMode && fName[0..3].to_i < 1989 || fName[0..3].to_i > 1989
        next
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
    @db.drop(@tableName)
    ss = generate_schema_string(@headers)
    @db.create_new_table(@tableName, ss)

    # dumping into DB
    @rawData.each_with_index do |row, idx|
      begin
        puts "Inserting row #{idx+1} of #{@rawData.length}"
        @db.insert(@tableName, @headers, row)
      rescue => error # dump failed, just skip this row 
        @logger.log(error)
        @logger.log(error.backtrace)
        next
      end
    end
    begin
      save_data
    rescue => error
      puts "Error saving data"
      @logger.log(error)
      @logger.log(error.backtrace)
    end
    if @logger.didLogErrors
      puts "Logged #{@logger.errorCount} errors"
    end
    puts "Completed in #{Time.now - mainTimecheck}"
  end
    
  def save_data
    @db.save_to_disk
  end

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
        @logger.log(error)
        @logger.log(row.to_s)
      end
    end
    return gameFileData.filter {|x| x != nil}
  end

  def check_for_gamefiles
    if !@fileList
      @fileList = Dir["./raw/*.EV*"].map {|f| f[6..]}.sort
    end
    puts "Found #{@fileList.length} event files in './raw'"
    if !@fileList
      puts "Couldn't find retrosheet game files. Please visit "\
        "https://www.retrosheet.org to download game event files."
      exit
    end
  end

  def check_for_lastFile
    if @fileList.find_index(@lastFile) == @fileList.length-1
      puts "Looks like you're already done, lastFile is at the end of the "\
           "fileList.\nIf you want to go again, reset the DB and delete "\
           "./db/lastFile"
      exit
    elsif @lastFile
      @fileList = @fileList.slice(@fileList.find_index(@lastFile)+1..)
      puts "Picking up where I left off: #{@lastFile}"
      puts "Filelist starting with: "
      puts @fileList[0..5].to_s
      puts "Press any key to begin..."
      STDIN.gets
    end
  end
end
