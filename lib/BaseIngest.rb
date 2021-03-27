require './lib/Logger'

# BaseIngest
#   base class for data ingest methods
#
#   inherited values:
#   @startYear, @endYear - integer years between 1989 - 2020 (years where gamelogs
#                        are available)
#   @db - reference to database
#   @tableName - reference to user's chosen table name for storing ingested data
#   @logger - reference to logger object (if you need it, see below)
#
#   inherited methods:
#   log(String *args) - writes string arguments to files under ./logs
#                       filenames look like "log_[Unix timestamp]"
#
#   things that base class does for you automatically before an ingest run
#   - check for existing table with given table name, confirm overwrite
#   - check for retrosheet files in the source directory under './raw'
#
#   usage:
#     Implement the following methods:
#       - get_headers
#       - process_single_event_file
#     BaseIngest will take care of getting the year range, and feeding individual
#       files into your subclass. Just return column names from get_headers and
#       2D Array with rows of data from process_single_event_file that match the
#       column names. See both methods docs for more details.

class BaseIngest
  def initialize(dbRef, tableName)
    @logger = Logger.new
    @db = dbRef
    @tableName = tableName
  end

  # log
  # @param [String *args] args Splats arbitrary number of strings into Logger for
  #   writing out to logfile
  def log(*args)
    args.each do |n|
      @logger.log(n)
    end
  end

  def has_subclass_methods
    if !self.respond_to?(:get_headers)
      puts "No #get_headers defined on subclass #{self.class}. "\
           "See docs for details."
    elsif !self.respond_to?(:process_single_event_file)
      puts "No #get_headers defined on subclass #{self.class}. "\
           "See docs for details."
    else
      return true
    end
    return false
  end

  def ingest_raw_data
    # give user a chance to avoid overwriting an existing table
    unless check_for_gamefiles then exit end
    unless has_subclass_methods then exit end
    get_year_range
    confirm_overwrite_table
    get_headers
    if !check_headers
      puts "No headers defined. Make sure @headers is set with column names in  "\
           "order to continue."
      exit
    end
  end


  def confirm_overwrite_table
    # just gives the user a chance to avoid overwriting the named table, if it
    #   already exists in the database
    if @db.has_table? @tableName
      puts "Table #{@tableName} exists. Bail out now, or continue to overwrite"
      STDIN.gets
    end
  end

  def check_headers
    if !@headers then return false else return true end
  end

  # recreate_table
  #   drops and recreates table with given @tableName and @headers. Bails out if
  #   no headers defined
  # @param none
  # @return nil
  def recreate_table
    # bail out if there's no headers at this point, don't want to drop existing
    #   if we know SQLite will throw an error for no table def statement
    if !@headers
      log("ERROR: no headers defined")
      exit
    end
    @db.drop(@tableName)
    @db.create_new_table(@tableName, @headers)
    return nil
  end

  # insert_data(rawData)
  #   dump 2D array of data into SQLite in-memory database, then write to disk
  #   also logs any errors, and returns error count
  #     
  # @param [Array] rawData Array of rows of data
  # @return [Integer] count of errors
  def insert_data(rawData)
    errCount = 0
    rawData.each_with_index do |row, idx|
      begin
        puts "Inserting row #{idx+1} of #{rawData.length}"
        @db.insert(@tableName, @headers, row)
      rescue => error # dump failed, just skip this row 
        log(error, error.backtrace)
        errCount += 1
        next
      end
    end
    begin
      @db.save_to_disk
    rescue => error
      puts "Error saving data"
      log(error, error.backtrace)
      errCount += 1
    end
    return errCount
  end

  def check_for_gamefiles
    @fileList ||= Dir["./raw/*.EV*"].map {|f| f[6..]}.sort
    if !@fileList
      puts "Couldn't find retrosheet game files. Please visit "\
        "https://www.retrosheet.org to download game event files."
      return false
    end
    puts "Found #{@fileList.length} event files in './raw'"
    return true
  end

  def get_year_range
    years = []
    while !verify_year(years)
      puts "Enter year range 1989-2020, comma-separated: "
      years = STDIN.gets.chomp.split(',').map(&:strip).map(&:to_i)
    end
    @startYear, @endYear = years
  end

  def verify_year(years)
    # checks user input ingest year range:
    #   - both numbers exist
    #   - both numbers are ints
    #   - starting year is before ending year
    #   - both years are between the acceptable range (1989-2020)
    if !years || years.length < 2 then return false end
    if years[0] > years[1] then return false end
    years.each do |n|
      if n.class != Integer || !n.between?(1989, 2020) then return false end
    end
    return true
  end
end
