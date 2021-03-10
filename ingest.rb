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

newGame = false
newFile = true

db = DBInterface.new

# set min/max season years. set equal for single season 
minYear = 1989
maxYear = 1989
testFile = "1989ATL.EVN"
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

testMode = true
if testMode
  fileList = ["1989ATL.EVN"]
  db.reset_db
end

newGame = SingleGame.new
fileList.each do |fName|

  puts "Processing: #{fName}"
  f = CSV.read("./raw/#{fName}")

  # games are only separated by rows starting with 'id'
  # FIXME this logic is wrong, and the reason the numbers are goofy
  #       - some of the slices have multiple games in them
  #       - the game ID printed as "game X of Y" is not correct 
  #           (i.e. doesn't always match the id of first game in the slice)
  t = f.each_with_index.select {|line, idx| line[0] == 'id'}.map(&:last) + [f.length-1]
  ids = []
  t.each_index do |idx|
    if idx != 0
      ids.push([t[idx-1], t[idx]])
    end
  end

      

  bigTimecheck = Time.now
  #(1..(ids.count-1)).each do |idx|
  ids.each_with_index do |idArr, idx|
    puts "Processing game #{idx} of #{ids.count}"
    puts "ID: #{f[idArr[0]]}"
    newGame.reset
    
    currentRows = f.slice(idArr[0]..idArr[1]-1)

    #timecheck = Time.now
    newGame.process(currentRows)
    #puts "\n\nProcess time: #{Time.now - timecheck}\n"
    #newGame.process(f.slice(ids[idx-1], ids[idx]))
    
    #timecheck = Time.now
    db.add_game(newGame.playerList)
    #puts "Timecheck3: #{Time.now - timecheck}"

    newGame.reset
    if newGame.playerList['treaj001']
      puts newGame['treaj001'][:atbats]
    end

  end
  puts "Total time: #{Time.now - bigTimecheck}"
end
