require './analyze'

usageStr = "usage:
  generate [START, LENGTH] - get measurements on LENGTH records, from START
  analyze - generate model with the measurements distribution
  test [START, LENGTH] - test with generated model. recommend using different
                         range from the one used for generate"

case ARGV[0]
when 'generate'
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  aModule = Analyze.new
  aModule.generate_measurements(ARGV[1].to_i, ARGV[2].to_i)
when 'analyze'
  aModule = Analyze.new
  aModule.analyze_measurements
when 'quicktest'
  aModule = Analyze.new
  aModule.analyze_measurements
  aModule.test_model
when 'fulltest'
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  aModule = Analyze.new
  aModule.analyze_measurements
  aModule.full_test(ARGV[1].to_i, ARGV[2].to_i)
end
