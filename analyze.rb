require './db/DBInterface'

class Analyze

  DB = DBInterface.new

  # load each year's roster into memory
  # load full gamelog into memory
  # generate test list
  # for each game (skip if on test list)
  #   - get winning/losing team from gamelog (look at scores)
  #   - get rosters for both teams (list of playerIds)
  #   - get gameId from gamelog: assemble from home team code, date, and game#
  #   - get each player's accumulated career avg stats per game from big db 
  #       for each stat
  #   - get total avg of avg stats across roster for each time
  #   - sub winning team overall avgs from losing team and record somewhere
  # do stat/distribution analysis on diffs
  # do test against skiplist games
  #   - get teams from gamelog (incl. winner/loser)
  #   - look at avg cumulative stats per game for both teams, make prediction
  #   - compare to actual winner
  #   - record if prediction was correct or not and save with gameId somewhere
  # at end, sum overall frequency of correctness/% correct
  
  def batting_avg_before_game(playerId, gameId)
  end

  def self.avg_stats_before_game(playerIdList, gameId)
    statList = ["atbats", "hits", "singles", "doubles", "triples", "homeruns", "strikes", "balls", "strikeouts"]
    out = {}
    statList.each do |stat|
      count = DB.get_player_gamecount(playerIdList, gameId)
      statTotal = DB.get_sum(stat, playerIdList, gameId)
      out[stat] = ((statTotal[0][0]).to_f)/count[0]
    end

    return out
  end

  def strikes_avg_before_game
  end
end
