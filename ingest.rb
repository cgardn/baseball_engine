require './SingleGame'
require './db/DBInterface'
#require './db_marshal/MarshalDB'
require 'csv'

#TODO problem with processing per game, it's adding the sum as each new game,
#     rather than that game's individual totals for each player. First player
#     in 1989ATL.EVN winds up with something like 44 at-bats per game later
#     in the season

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
  ids = f.each_with_index.select {|line, idx| line[0] == 'id'}.map(&:last) + [f.length-1]

  (1..(ids.count-1)).each do |idx|
    puts "Processing game #{idx} of #{ids.count}"
    newGame.initialize
    newGame.process(f.slice(ids[idx-1], ids[idx]))
    db.add_game(newGame.playerList)
  end

  #puts db.get_stats
  #gets.chomp

=begin
  # this is for each row of the file, not each file
  $thisGame = SingleGame.new
  CSV.foreach("./raw/#{fName}") do |row|
  
    begin
      if row[0] == 'id' && $thisGame.has_data?
        # new game starts here
        # but there's already one game processed, since the file starts with
        #   an id line
        puts "Game data"
        puts $thisGame.to_s
        gets.chomp
        db.add_game($thisGame.playerList, $thisGame.id)
        puts "DB Data"
        puts db.data
        gets.chomp
        $thisGame = SingleGame.new
      end
      $thisGame.process_row(row)
    rescue
      #puts "ERROR::::"
      #puts row
    end
  end

  begin
    puts db.get_stats
  rescue
    puts "db.get_stats error"
  end
=end
  
end


=begin
File.open('./testDB_text', 'w') {|f|
  f.write(loadedGames.dump)
}
=end

