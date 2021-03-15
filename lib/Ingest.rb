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

class Ingest
  def initialize
    @newGame = false
    @newFile = true
    @db = DBInterface.new

    check_for_gamefiles
    @lastFile= (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''
    if @lastFile
      @fileList.slice!(@fileList.find_index(@lastFile)+1..)
    end
  end

  def ingest_raw_data
    #check_for_gamefiles
    check_for_lastFile

    newGame = SingleGame.new
    mainTimecheck = Time.now
    @fileList.each do |fName|
    
      puts "Processing: #{fName}"
      # bit of a hang here to load the file, might be unavoidable
      f = CSV.read("./raw/#{fName}")
      puts "stop here, seems ok"
      STDIN.gets
    
      # games are separated by rows starting with 'id'
      t = f.each_with_index.select {|line, idx| line[0] == 'id'}.map(&:last) + [f.length-1]
      ids = []
      t.each_index do |idx|
        if idx != 0
          ids.push([t[idx-1], t[idx]])
        end
      end
    
      begin
        ids.each_with_index do |idArr, idx|
          puts "\nProcessing game #{idx} of #{ids.count}"
          puts "ID: #{f[idArr[0]]}"
          
          currentRows = f.slice(idArr[0]..idArr[1]-1)
      
          newGame.process(currentRows)
          
          @db.add_game(newGame.playerList)
          newGame.reset
    
        rescue => error
          puts "ERROR: #{error}"
          puts "Attempting to save..."
          save_data(fName)
        end
    
      end
      save_data(fName)

    end
    puts "Completed in #{Time.now - mainTimecheck}"
  end

  def save_data(lastFileCompleted)
    @db.save_to_disk
    File.write('./db/lastFile', lastFileCompleted) 
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
