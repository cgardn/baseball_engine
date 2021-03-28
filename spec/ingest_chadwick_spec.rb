require "IngestChadwick"
require "sqlite3"

describe IngestChadwick do
  # mocks
  db = SQLite3::Database.new ":memory:"
  ic = IngestChadwick.new(db, "test")

  describe "class" do
    it "implements the required methods: #get_headers and "\
       "#process_single_event_file" do
      expect(ic.has_subclass_methods).to eql([])
    end
  end

  describe "process_single_event_file" do
  end
end
