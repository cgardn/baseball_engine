# decodes retrosheet play codes into a suitable format for usage
#   input:  single retrosheet 'play' row
#   output: object/hash with player id and key/value pairs for each thing
#           i'm pulling out:
#           Offense:
#             - balls/strikes, hits, runners advanced, bases stolen
#           Defense:
#             - playerID who fielded play, whether the hitter was put out
#           Pitcher:
#             - balls, strikes, strikeout?, walk?
#  as of 3-9-2021, only using limited set of offensive stats
#    will come back and add in defensive stats and pitcher stuff later

class PlayDecoder
  attr_reader :batter, :hitType, :raw
  def initialize(row)
    @raw = row
    @batter = row[2]
    @defPlayer = ''
    @hitType = ''
    @strikeout = 0
    @walk = 0
    @balls = 0
    @strikes = 0

    if row[4]
      @balls = row[3].split('')[0].to_i
      @strikes = row[3].split('')[1].to_i
    end

    @hitType = get_hit_type
  end

  def get_play
    # check db schema for correct field names
    # also make sure it's correct on GameRecord def in SingleGame.rb
    out = {
      'atbats': atbat? ? 1 : 0,
      'hits': hit? ? 1 : 0,
      'balls': @balls,
      'strikes': @strikes,
    }
    if @hitType
      # need full name because of GameRecord default value setup stuff
      name = {'S'=> 'singles', 'D'=> 'doubles', 'T'=> 'triples', 
              'HR'=> 'homeruns', 'W'=> 'walks', 'K'=> 'strikeouts'}[@hitType]
      out[name] = 1
    end
    return out
  end

  def to_s
    "Raw play code: #{@raw}
     Play data: #{get_play}"
  end
  
  def hit?
    return ['S','D','T','H','HR'].include? @hitType
  end

  def atbat?
    return @hitType != 'W'
  end

  def get_hit_type
    types = ['S','D','T','H','HR', 'K', 'W']
    # only extracting the type of hit, or walk/strikeout 
    regexp = /\A([A-Z]+)[0-9\.\/\+\>]/
    reg = /\A([A-Z]+).*/
    code = @raw[5].match(reg)

    # check if match and included in hit type list
    code = (code && types.include?(code[1])) ? code[1] : nil
    # consistency on home run code
    code = (code && code == 'H') ? 'HR' : code
    return code
  end
end
