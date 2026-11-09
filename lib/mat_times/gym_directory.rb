module MatTimes
  class GymDirectory
    include Enumerable

    def self.load(csv_path, aliases_path, overrides: nil)
      gyms = CSV.foreach(csv_path, headers: true).filter_map do |row|
        next if row["Gym"].to_s.strip.empty?

        website = row["Website"].to_s.strip
        raise ArgumentError, "Bad website for #{row["Gym"]}: #{website}" unless website.match?(%r{\Ahttps?://}i)

        Gym.new(
          name: row["Gym"].strip,
          city: row["City"].to_s.strip,
          address: row["Street address"].to_s.strip,
          website: website,
          youth: row["Youth program (ages)"].to_s.strip,
          notes: row["Status / notes"].to_s.strip
        )
      end

      new(apply_overrides(gyms, overrides ? YAML.load_file(overrides) : {}), YAML.load_file(aliases_path))
    end

    def self.apply_overrides(gyms, overrides)
      unknown = overrides.keys - gyms.map(&:name)
      raise UnknownGym, "Override for unknown gym: #{unknown.join(", ")}" unless unknown.empty?

      gyms.map { |gym| overrides.key?(gym.name) ? gym.with(website: overrides[gym.name]) : gym }
    end
    private_class_method :apply_overrides

    def initialize(gyms, aliases)
      @gyms = gyms.sort_by(&:name)
      @by_name = gyms.to_h { |gym| [gym.name, gym] }
      @aliases = aliases
      @aliases.each_value { |name| @by_name.fetch(name) { raise UnknownGym, "Alias points at unknown gym: #{name}" } }
    end

    def each(&) = @gyms.each(&)

    def fetch(label)
      @by_name.fetch(@aliases.fetch(label, label)) do
        raise UnknownGym, "#{label.inspect} is not in the gym directory. Add it to data/gym_aliases.yml or the Gym Websites tab."
      end
    end
  end
end
