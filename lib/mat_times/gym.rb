module MatTimes
  Gym = Data.define(:name, :city, :address, :website, :youth, :notes) do
    def slug = self.class.slugify(name)

    def city_slug = self.class.slugify(city)

    # The sheet sometimes cites its source after the address: "... MI 48201 (club page)".
    def location = address.sub(/\s*\(.*\z/m, "")

    def map_url = "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(location)}"

    def directions_url = "https://www.google.com/maps/dir/?api=1&destination=#{ERB::Util.url_encode(location)}"

    def self.slugify(text) = text.downcase.delete("'’").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end
end
