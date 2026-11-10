module MatTimes
  class SheetPull
    class BadResponse < StandardError; end

    SHEET_ID = "1UkzLhGnMmzf0dy8qCZel2uZwK1n385PGrK7KMVhpKXw"

    TABS = {
      "classes.csv" => 766857493,
      "kids.csv" => 866857493,
      "open_mats.csv" => 966857493,
      "women.csv" => 2123339966,
      "wrestling_judo_sambo.csv" => 14419975,
      "gyms.csv" => 443627858
    }.freeze

    def initialize(to:, fetcher: ->(url) { URI.open(url, &:read) }, today: Date.today)
      @to = to
      @fetcher = fetcher
      @today = today
    end

    def url_for(gid) = "https://docs.google.com/spreadsheets/d/#{SHEET_ID}/export?format=csv&gid=#{gid}"

    def call
      bodies = TABS.transform_values { |gid| checked(@fetcher.call(url_for(gid)), gid) }

      bodies.each { |file, body| File.write(File.join(@to, file), body) }
      File.write(File.join(@to, "pulled_on.txt"), "#{@today.iso8601}\n")
    end

    private

    def checked(body, gid)
      raise BadResponse, "Tab #{gid} did not return CSV" if body.strip.empty? || body.lstrip.start_with?("<")

      body
    end
  end
end
