require './lib/SingleGame'
require './db/DBInterface'
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
    @newGame = false
    @newFile = true
    @rawData = []
    @tableName = tableName

    # TODO replace this with YAML config
    #      also needs types assigned, currently doing this manually
    @fieldString = "-f 0,8,35 -x 35-48"
    @headers = []

    @db = DBInterface.new

    check_for_gamefiles
    @lastFile= (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''
    if @lastFile
      @fileList.slice!(@fileList.find_index(@lastFile)+1..)
    end
  end

  def run_ingest
    ingest_raw_data
  end

  def generate_schema_string(cols)
    out = "#{cols[0]} varchar(30), #{cols[1]} varchar(3),  "
    out += cols[2..].map {|s| "#{s} int NOT NULL DEFAULT 0"}.join(', ')
    return out
  end

  def get_field_names(fieldString)
    # we use a random event file here, since we're just collecting column
    #   headers
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y 1989 -n #{fieldString} 1989ATL.EVN`
        return CSV.parse(output)[0]
      end
    rescue => error
      puts error
      puts error.backtrace
      exit
    end
  end

  def ingest_single_event_file(fileName, fieldString)
    begin
      Dir.chdir("./raw") do
        output = `cwgame -y #{fileName[0..3]} #{fieldString} #{fileName}`
        output = CSV.parse(output)
        # FIXME hardcoded assumption that the first two values are strings, and
        #      the rest are ints
        output = output.map! {|row| row[0..1] + row[2..].map!(&:to_i)}
        return output
      end
    rescue => error
      puts error
      puts error.backtrace
      return nil
    end
  end

  def ingest_raw_data
    # main processing of all game event files
    
    if @db.has_table? @tableName
      puts "Table #{@tableName} exists. Bail out now, or continue to overwrite"
      STDIN.gets
    end

    @headers = get_field_names(@fieldString)

    mainTimecheck = Time.now
    @fileList.each do |fName|
      # this is only for testing
      if fName[0..3].to_i < 1989 || fName[0..3].to_i > 1989
        next
      end

      fileData = ingest_single_event_file(fName, @fieldString)
      if !fileData
        puts "Skipping #{fName}..."
        next
      end
      @rawData = @rawData.concat(fileData)
    end

    @db.drop(@tableName)
    ss = generate_schema_string(@headers)
    @db.create_new_table(@tableName, ss)

    # then dump processed data into table
    # then save data
    begin # dumping into DB
      @rawData.each do |row|
        puts "About to dump row"
        puts row.to_s
        STDIN.gets
        @db.insert(@tableName, @headers, row)
      end
      save_data
    rescue => error # dump failed, just print error and exit
      puts error
      puts error.backtrace
      exit
    end
    puts "Completed in #{Time.now - mainTimecheck}"
  end
    
  #def save_data(lastFileCompleted)
  def save_data
    @db.save_to_disk
    #File.write('./db/lastFile', lastFileCompleted) 
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
