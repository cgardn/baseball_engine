# Retrosheet baseball stats analyzer

An experiment in working with large(ish) datasets, and statistical classifiers.

Usage:
ruby ./bb.rb

Run with no arguments to see available commands. Each command should be run in
order, as each step depends on the output of the previous step.

Using this program requires play-by-play game log files from [retrosheet.org](https://www.retrosheet.org/gamelogs/index.html). Download the years you want
to use, and extract the individual files into a subfolder named 'raw'.
In particular, the full season data files that look like this:
  \[4-digit year\]\[3-digit team code\].EV\*

ex: 1980ATL.EVN

Please note: ingesting the data uses the builtin CSV module, so getting
through significant numbers of years takes a while. I used 1989-2020, and it 
took 8 hours+ to generate ~1.5m player records. This will be significantly improved in the next version!

Also, the 'analyze' and 'test' modules don't use a "real" classifier, just 
something I whipped up to complete the loop from ingest -\> extract features -\> build model -\> test. An actual methodology is coming in future versions! 
