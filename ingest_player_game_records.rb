require './SingleGame'
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

newGame = false
newFile = true

db = DBInterface.new

# switching to a generated list of files, much easier
fileList = File.readlines('./db/fileList').map(&:chomp)
last = (File.exists? "./db/lastFile") ? File.read('./db/lastFile') : ''

if last != ''
  fileList = fileList.slice(fileList.find_index(last)+1..)
end

puts last
gets.chomp
puts fileList[0..10]
gets.chomp

testMode = false
reset = false
if testMode
  fileList = ["1989ATL.EVN"]
end
if reset
  puts "RESET MODE IS ON!!! Press enter to reset DB, or bail out now!!!"
  gets.chomp
  db.reset_db
end

newGame = SingleGame.new
mainTimecheck = Time.now
fileList.each do |fName|

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

  ids.each_with_index do |idArr, idx|
    puts "\nProcessing game #{idx} of #{ids.count}"
    puts "ID: #{f[idArr[0]]}"
    
    currentRows = f.slice(idArr[0]..idArr[1]-1)

    #timecheck = Time.now
    newGame.process(currentRows)
    #puts "Process time: #{Time.now - timecheck}\n"
    
    #timecheck = Time.now
    db.add_game(newGame.playerList)
    #puts "Add_game: #{Time.now - timecheck}\n"

    newGame.reset

  end
  # if no problems, write to disk and last file completed
  db.save_to_disk
  File.write('./db/lastFile', fName) 
end
puts "Completed in #{Time.now - mainTimecheck}"
