#!/bin/ruby 

require './lib/IngestChadwick'
require './lib/Measure'
require './lib/Analyze'
require './lib/Test'

require './lib/DBInterface'

class BB

  def initialize
    @db = DBInterface.new
    @ingest = IngestChadwick
    @measure = nil
    @train = nil
    @test = nil
  end

  def ingest(tableName)
    ing = @ingest.new(@db, tableName)
    ing.ingest_raw_data
  end

  def measure(startNum, endNum, tableName)
    check_if_implemented(@measure)
    measure = @measure.new(@db, tableName)
    measure.generate_measurements(startNum, endNum)
  end

  def train(startNum, endNum, tableName)
    # show available strategies, pick one and generate trained model
    # ??
    check_if_implemented(@train)
    train = @train.new(@db, modelName)
    train.train_model(startNum, endNum, tableName)
  end

  def test(num, modelName)
    # show trained models available for testing, pick one and do test
    check_if_implemented(@test)
    test = @test.new(@db, modelName)
    test.test_model(num)
  end
  
  def check_if_implemented(method)
    if !method
      puts "Not implemented"
      exit
    end
  end
end


usageStr = "" \
  "Baseball Engine - an interactive platform for predicting MLB game winners "\
  "\nusage:\n"\
  "ingest [TABLENAME] \n"\
    "\tprocess raw retrosheet files into DB. TABLENAME is name of table to\n"\
    "\tsave data into in database\n"\
  "measure [START, LENGTH, TABLE] \n"\
    "\tget measurements on LENGTH records, beginning from START and \n"\
    "\trunning over LENGTH, stored in TABLE\n"\
  "train [START, LENGTH, MODEL] \n"\
    "\tgenerate named model on measurements\n"\
  "test [START, LENGTH] \n"\
    "\ttest with generated model. recommend using different range from the\n"\
    "\tone used for 'measure'"\
  "\n---\n\n"\
  "Each command should be run in order from top to bottom.\n"\
  "03/21: Not implemented/not finished:\n"\
  "\t- measure\n"\
  "\t- train\n"\
  "\t- test\n"\
  "You'll also need event, team, and roster files from retrosheet.org.\n"\
  "Check README for more info.\n\n"
  
if !ARGV[0]
  puts usageStr
  exit
end

bb = BB.new

case ARGV[0]
  
when 'ingest'
  if ARGV.length < 2 || ARGV[1].class != String
    puts usageStr
    exit
  end
  # parse raw retrosheet files into db
  bb = BB.new
  bb.ingest(ARGV[1])
when 'measure'
  # generate actual numbers used as signals
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  bb = BB.new
  bb.measure(ARGV[1].to_i, ARGV[2].to_i)
when 'train'
  bb = BB.new
  bb.train(ARGV[1].to_i, ARGV[2].to_i, ARGV[3])
when 'test'
  if ARGV.length < 3 
    puts usageStr
    exit
  end
  test = Test.new
  test.full_test(ARGV[1].to_i, ARGV[2].to_i)
when 'systest'
  bb = BB.new
  bb.ingest("test", [1989,1989])
else
  puts usageStr
end
