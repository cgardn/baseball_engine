require "BaseIngest"

describe BaseIngest do
  bi = BaseIngest.new({}, "test1")
  describe "#check_headers" do
    it "returns false if @headers is not set" do
      expect(bi.check_headers).to eql(false)
    end
  end
end
