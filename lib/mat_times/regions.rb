module MatTimes
  class Regions
    class Unknown < StandardError; end

    Region = Data.define(:slug, :name)

    attr_reader :all

    def self.load(path, borders: nil) = new(YAML.load_file(path), borders: borders ? YAML.load_file(borders) : {})

    def initialize(cities_by_region, borders: {})
      @all = cities_by_region.keys.map { |name| Region.new(slug: Gym.slugify(name), name:) }
      @by_city = cities_by_region.each_with_index.flat_map { |(_, cities), index| cities.map { |city| [city, @all[index]] } }.to_h
      @borders = borders.transform_values { |name| named(name) }
    end

    def for(city) = @by_city.fetch(city) { raise Unknown, "#{city.inspect} has no region. Add it to data/regions.yml." }

    def of(gym) = [self.for(gym.city), @borders[gym.name]].compact.uniq

    private

    def named(name) = @all.find { |region| region.name == name } || raise(Unknown, "#{name.inspect} isn't a region in data/regions.yml.")
  end
end
