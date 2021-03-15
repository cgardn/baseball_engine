require './lib/SingleGame'
require './db/DBInterface'
require 'csv'

#TODO assorted things that aren't implemented or done quite "correct"
# - no defensive stats, or pitching stats
# - no RBIs
# - not exactly the correct definition of a hit (missing rules/detection
#     for bunts/sac bunts/sac flys/etc)
# TODO next
# - batch CSV reads/something else, to speed up the process
# - replace my own parsing with chadwick tool

class Ingest
  def initialize
    @newGame = false
    @newFile = true
    @db = DBInterface.new
    @fileList = File.readlines('./db/fileList').map(&:chomp)
    @lastFile = (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''
    if @lastFile
      @fileList.slice!(@fileList.find_index(@lastFile)+1..)
    end
  end

  def ingest_raw_data
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

end

=begin
newGame = false
newFile = true

db = DBInterface.new

# switching to a generated list of files, much easier
fileList = File.readlines('./db/fileList').map(&:chomp)
last = (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''

if last != ''
  fileList = fileList.slice(fileList.find_index(last)+1..)
end

reset = false
if reset
  puts "RESET MODE IS ON!!! Press enter to reset DB, or bail out now!!!"
  gets.chomp
  db.reset_db
end
=end
=begin
newGame = SingleGame.new
mainTimecheck = Time.now
@fileList.each do |fName|

  puts "Processing: #{fName}"
  # bit of a hang here to load the file, might be unavoidable
  f = CSV.read("./raw/#{fName}")

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
=end

def save_data(lastFileCompleted)
  @db.save_to_disk
  File.write('./db/lastFile', lastFileCompleted) 
end
