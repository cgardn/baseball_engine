require './SingleGame'
require 'csv'


testFile = "./raw/1989ATL.EVN"

newGame = false
newFile = true
thisGame = SingleGame.new

# get all season files above given year
minYear = 1989
# filter out teamfiles
fileList = Dir.children('./raw/').filter {|fn| fn.split('.').length > 1}
# filter out roster files
fileList.filter! {|fn| fn.split('.')[1] != 'ROS'}
# filter above minimum year
fileList.filter! {|fn| fn.match(/([0-9]{4})/).to_s.to_i >= minYear}
# sort last on smallest list
fileList.sort!

fileList.each do |fName|
  # this is for each row of the file, not each file
  CSV.foreach("./raw/#{fName}") do |row|
  
    if row[0] == 'id' && thisGame.has_data?
      thisGame.position_setup
      puts thisGame.to_s
      gets.chomp
      thisGame = SingleGame.new
    end
    thisGame.process_row(row)
  
  end
end

=begin
File.open('./testDB_text', 'w') {|f|
  f.write(loadedGames.dump)
}
=end

