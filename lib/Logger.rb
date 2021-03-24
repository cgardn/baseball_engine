class Logger
  attr_reader :didLogErrors, :errorCount
  def initialize
    dirPath = "./logs"
    if !Dir.exist?(dirPath)
      Dir.mkdir(dirPath)
    end
    @fileName = "#{dirPath}/log_#{Time.now.to_i}"
    @didLogErrors = false
    @errorCount = 0
  end

  def log(str)
    @didLogErrors = true
    @errorCount += 1
    File.open(@fileName, 'a') do |f|
      f << "[#{Time.now}]: #{str}"
      f << "\n"
    end
  end
end
