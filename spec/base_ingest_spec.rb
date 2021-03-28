require "BaseIngest"
require 'sqlite3'

describe BaseIngest do
  # mocks
  db = SQLite3::Database.new ":memory:"
  bi = BaseIngest.new(db, "test1")

  describe "#check_headers" do
    it "returns false if @headers is not set" do
      expect(bi.check_headers).to eql(false)
    end
  end

  describe "#has_subclass_methods" do
    class TestClass < BaseIngest
    end
    tc = TestClass.new(db, "test")
    it "returns name of missing methods if subclass doesn't implement "\
       "get_headers and process_single_event_file methods" do
      expect(tc.has_subclass_methods).to eql(["get_headers", "process_single_event_file"])
    end
    it "returns empty array if subclass implements correct methods" do
      tc.define_singleton_method(:get_headers) {}
      tc.define_singleton_method(:process_single_event_file) {}
      expect(tc.has_subclass_methods).to eql([])
    end
      
  end

  describe "#verify_year" do
    context "given an array that should contain two integer years" do

      it "checks the array exists / is not blank" do
        n = []
        expect(bi.verify_year(n)).to eql(false)
      end

      it "checks there are two numbers" do 
        n = [1234]
        expect(bi.verify_year(n)).to eql(false)
      end
      
      it "checks both years are integers" do
        n = [1989.0, 1991.1]
        expect(bi.verify_year(n)).to eql(false)
      end

      it "checks the starting year is before the ending year" do
        n = [1992, 1990]
        expect(bi.verify_year(n)).to eql(false)
      end

      it "checks the starting year is at least 1989" do
        n = [1987, 2020]
        expect(bi.verify_year(n)).to eql(false)
      end

      it "checks the ending year is at most 2020" do
        n = [1991, 2021]
        expect(bi.verify_year(n)).to eql(false)
      end

      it "allows 1989 and 2020 inclusive" do
        n = [1989, 2020]
        expect(bi.verify_year(n)).to eql(true)
      end
    end

  end

end
