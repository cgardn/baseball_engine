require './lib/BaseIngest'
require './lib/SingleGame'
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

    # TODO replace this with YAML config
    #      also needs types assigned, currently doing this manually
    @fieldsHome = "-f 0,8,35,37,39 -x 35-48"
    @fieldsVis = "-f 0,7,34,36,38 -x 10-23"
    
    # we use the Gamelogs class for labelling records with win/loss 
    @gml = Gamelogs.new
    @gml.load_data
  end

  # Get column names from data files, put in @headers
  def get_headers
    # FIXME is there a cleaner way to do this?
    # we use a random event file here, since we're just collecting column
    #   headers
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y 1989 -n #{@fieldsHome} 1989ATL.EVN`
        output = CSV.parse(output)[0]

        # remove home/away prefix from headers, home/vis is stored as separate
        #   field
        t = ['HOME', 'AWAY']
        output.map! {|h| t.include?(h[0..3]) ? h[5..] : h}

        output.push("HOME")
        output.push("WIN")

        return output
      end
    rescue => error
      puts error
      log(error, error.backtrace)
      exit
    end
  end

  def ingest_event_file(fileName, fieldString)
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y #{fileName[0..3]} #{fieldString} #{fileName}`
        output = CSV.parse(output)
        # FIXME hardcoded assumption that the first two values are strings, and
        #       the rest are ints - making this more general requires YAML 
        #       config with type hints or something similar
        output = output.map! {|row| row[0..1] + row[2..].map!(&:to_i)}
        return output
      end
    rescue => error
      puts error
      log(error, error.backtrace)
      return nil
    end
  end

  # Yield rows of data from file given by fName
  # @param [String] fName Name of file to be processed
  # returns nothing, yield rows of data instead
  def process_single_event_file(fName)
    homeData = ingest_event_file(fName, @fieldsHome)
    visData = ingest_event_file(fName, @fieldsVis)
    out = []

    unless !homeData
      # set home team and winner fields
      yield set_home_and_winner_fields(homeData, true)
      puts "Finished #{fName} home"
    else
      puts "Skipped #{fName} Home data"
    end

    unless !visData
      # set home team and winner fields
      yield set_home_and_winner_fields(visData, false)
    else
      puts "Skipped #{fName} Visitor data"
    end
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
        puts error
        log(error, row.to_s)
      end
    end
    return gameFileData.filter {|x| x != nil}
  end

end
