require './lib/Ingest'
require './lib/Measure'
require './lib/Analyze'
require './lib/Test'

usageStr = "usage:
  ingest - process raw retrosheet files into DB
  measure [START, LENGTH] - get measurements on LENGTH records, from START
  analyze - generate model with the measurements distribution
  test [START, LENGTH] - test with generated model. recommend using different
                         range from the one used for 'measure'\n\n
  ---
  Each command should be run in order from top to bottom
  *NOTE* 'test' uses old (and incorrect) methodology, so it's just going to
         give you a lot of garbage at the moment. Working on it! :)

  You'll also need event files from retrosheet.org. Check README for info."

if !ARGV[0]
  puts usageStr
  exit
end

case ARGV[0]

when 'ingest'
  # parse raw retrosheet files into db
  ing = Ingest.new
  ing.ingest_raw_data

when 'measure'
  # generate actual numbers used as signals
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  measure = Measure.new
  measure.generate_measurements(ARGV[1].to_i, ARGV[2].to_i)
when 'analyze'
  aModule = Analyze.new
  aModule.analyze_measurements
when 'test'
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  test = Test.new
  test.full_test(ARGV[1].to_i, ARGV[2].to_i)
end
