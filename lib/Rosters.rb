require 'csv'
class Rosters
  def initialize
    @data = {}
  end

  def load_data
    # set up team names and years
    fileList = File.readlines('./staticData/rosterFileList').map(&:chomp)
    puts "fetching rosters..."
    fileList.each do |file|
      @data[file.slice(0,3)] ||= {}
      @data[file.slice(0,3)][file.slice(3,4)] = CSV.read("./raw/#{file}").map{|x| x[0]}
    end
    puts "done."
  end

  def get_single_roster(team, year)
    return @data[team][year]
  end

  def get_rosters(teams, year)
    return {
      teams[0] => @data[teams[0]][year],
      teams[1] => @data[teams[1]][year]
    }
  end
end
