require "fileutils"

module MatTimes
  # Compiles the timetable into one self-contained HTML file.
  class SiteBuilder
    include ERB::Util

    VIEWS = File.join(ROOT, "app/views")
    ASSETS = File.join(ROOT, "app/assets")

    LABELS = {
      "when" => { "morning" => "Morning", "afternoon" => "Afternoon", "evening" => "Evening" },
      "who" => { "adults" => "Adults", "kids" => "Kids and teens", "women" => "Women" },
      "discipline" => {
        "bjj" => "Jiu Jitsu", "wrestling" => "Wrestling", "judo" => "Judo", "sambo" => "Sambo",
        "striking" => "Striking", "other" => "Other"
      },
      "attire" => { "gi" => "Gi", "nogi" => "No-Gi" }
    }.freeze

    def self.from_project
      data = File.join(ROOT, "data")
      directory = GymDirectory.load(
        File.join(data, "sheet/gyms.csv"), File.join(data, "gym_aliases.yml"), overrides: File.join(data, "gym_overrides.yml")
      )

      new(
        timetable: Timetable.load(File.join(data, "sheet"), directory),
        directory: directory,
        config: YAML.load_file(File.join(ROOT, "config/site.yml")),
        pulled_on: Date.iso8601(File.read(File.join(data, "sheet/pulled_on.txt")).strip)
      )
    end

    def initialize(timetable:, directory:, config:, pulled_on:)
      @timetable = timetable
      @directory = directory
      @config = config
      @pulled_on = pulled_on
      @templates = {}
    end

    def html = render("index").gsub(/^[ \t]+/, "").squeeze("\n")

    def write(to:)
      FileUtils.mkdir_p(to)
      File.write(File.join(to, "index.html"), html)
    end

    private

    attr_reader :timetable, :directory, :config

    def render(name, **locals)
      scope = binding
      locals.each { |key, value| scope.local_variable_set(key, value) }
      template(name).result(scope)
    end

    def template(name)
      @templates[name] ||= ERB.new(File.read(File.join(VIEWS, "#{name}.html.erb")), trim_mode: "-")
    end

    def asset(name) = File.read(File.join(ASSETS, name))

    def pulled_on = @pulled_on.strftime("%b %-d, %Y")

    def support? = !config["support_url"].to_s.empty?

    def day_options = timetable.by_day.keys.map { |day| [day[0, 3].downcase, day[0, 3]] }

    def options(facet)
      present = timetable.classes.flat_map { |entry| values_for(entry, facet) }.compact.uniq

      LABELS.fetch(facet).select { |value, _| present.include?(value) }.to_a
    end

    def values_for(entry, facet)
      { "when" => [entry.time_of_day], "who" => entry.who, "discipline" => entry.disciplines, "attire" => [entry.attire] }.fetch(facet)
    end

    def city_options = timetable.gyms.uniq(&:city_slug).map { |gym| [gym.city_slug, gym.city] }.sort_by(&:last)

    def gym_options = timetable.gyms.map { |gym| [gym.slug, gym.name] }

    def class_count(gym) = class_counts.fetch(gym.slug, 0)

    def class_counts = @class_counts ||= timetable.classes.map { |entry| entry.gym.slug }.tally

    def audience_tag(entry) = { "kids" => "Kids and teens", "women" => "Women" }[entry.who.first]

    def details(entry)
      [audience_tag(entry), ("Open mat" if entry.format == "open"), entry.season, entry.note].compact
    end

    def hostname(url) = url[%r{\Ahttps?://(?:www\.)?([^/?#]+)}i, 1]
  end
end
