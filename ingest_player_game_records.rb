require './SingleGame'
require './db/DBInterface'
require 'csv'

#TODO assorted things that aren't implemented or done quite "correct"
# - no defensive stats, or pitching stats
# - no RBIs
# - not exactly the correct definition of a hit (missing rules/detection
#     for bunts/sac bunts/sac flys/etc)
# TODO next
# - add memory load/save to DBInterface so whole db can be loaded into memory
#     and dumped when done
# - actually process all the seasons
# - write the analysis module, and the test+training modules
#   > keep it simple: 80% training, 20% test, no fancy pattern recognition
# - add conditional updating, check if game record exists for given player
#   and only update if it doesn't exist

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

=begin
# set min/max season years. set equal for single season 
minYear = 1989
maxYear = 1992
lastFile = ''
begin
  lastFile = File.open('./db/lastFileFinished') {|f| f.read.to_i}
  puts "Last file completed: #{lastFile}"
rescue
  puts "No lastFileFinished found, starting in #{minYear}"
end
# filter out teamfiles
fileList = Dir.children('./raw/').filter {|fn| fn.split('.').length > 1}
# filter out roster files
fileList.filter! {|fn| fn.split('.')[1] != 'ROS'}
# filter above minimum year
fileList.filter! {|fn| fn.match(/([0-9]{4})/).to_s.to_i >= minYear}
# filter below max year
fileList.filter! {|fn| fn.match(/([0-9]{4})/).to_s.to_i <= maxYear}
# sort last on smallest list
fileList.sort!
=end

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
