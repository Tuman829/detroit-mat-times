module MatTimes
  # Coordinates already in the file are kept, so a hand-corrected pin sticks.
  class GymLocator
    class NotFound < StandardError; end

    ENDPOINT = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress"

    def self.load(file) = File.exist?(file) ? YAML.load_file(file) || {} : {}

    def initialize(file:, fetcher: ->(url) { URI.open(url, &:read) })
      @file = file
      @fetcher = fetcher
    end

    def call(gyms)
      known = self.class.load(@file)
      missing = gyms.reject { |gym| known.key?(gym.slug) }
      found = missing.to_h { |gym| [gym.slug, locate(gym)] }.compact
      File.write(@file, YAML.dump(known.merge(found).sort.to_h))

      unplaced = missing.reject { |gym| found.key?(gym.slug) }
      raise NotFound, "Couldn't place: #{unplaced.map(&:name).join(", ")}. Add them to #{@file} by hand." if unplaced.any?
    end

    private

    # "Rec Center, 2 Oak St, ..." also gets tried as "2 Oak St, ...".
    def locate(gym)
      [gym.location, gym.location.sub(/\A\D+?,\s*(?=\d)/, "")].uniq.each do |address|
        match = JSON.parse(@fetcher.call(url_for(address))).dig("result", "addressMatches", 0, "coordinates")
        return [match["y"].round(5), match["x"].round(5)] if match
      end
      nil
    end

    def url_for(address) = "#{ENDPOINT}?address=#{ERB::Util.url_encode(address)}&benchmark=Public_AR_Current&format=json"
  end
end
