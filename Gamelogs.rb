require 'csv'
class Gamelogs
  attr_accessor :data
  def initialize
    @data = {}
  end

  def load_from_marshal
    @data = Marshal.load(File.read('./gamelogdump'))
  end

  def load_data
    if File.exists? './gamelogdump'
      puts "loading gamelogs from dump"
      load_from_marshal
      puts "done."
      return
    end
    # iterate over all gamelog files and extract
    # fields: 0-date, 1-gamenum, 3-vis team code, 6-home team code
    #         9-vis team score, 10-vis team score (scores unquoted)
    #         15-forfeit ('V', 'H', 'T' for vis, home, no-decision)
    fileList = File.readlines('./fileLists/gamelogFileList').map(&:chomp)
    puts "fetching gamelogs..."
    fileList.each do |file|
      puts "Processing #{file}..."
      raw = CSV.read("./raw/gamelogs/#{file}")
      raw.each_with_index do |thisGame, idx|
        # skip tie games for now
        if thisGame[9] == thisGame[10]
          next
        end

        gameId = thisGame[6] + thisGame[0] + thisGame[1]
        winner,loser = thisGame[9] > thisGame[10] ? 
          [thisGame[3], thisGame[6]] :
          [thisGame[6], thisGame[3]]

        @data[gameId] ||= {}
        @data[gameId][:winner] = winner
        @data[gameId][:loser] = loser
        @data[gameId][:teams] = [thisGame[3], thisGame[6]]
      end
    end
    puts "done."
  end

  def get_gamelog(gameId)
    return @data[gameId]
  end

  def get_gameId_list
    return @data.keys
  end

end
