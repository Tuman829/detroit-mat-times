require "fileutils"

module MatTimes
  class SiteBuilder
    include ERB::Util

    VIEWS = File.join(ROOT, "app/views")
    ASSETS = File.join(ROOT, "app/assets")
    FONT_REFERENCE = %r{url\("fonts/([^"]+)"\)}
    COORDINATES = File.join(ROOT, "data/gym_coordinates.yml")
    REGIONS = File.join(ROOT, "data/regions.yml")
    REGION_BORDERS = File.join(ROOT, "data/region_borders.yml")
    GYM_SECTIONS = File.join(ROOT, "data/gym_sections.yml")

    SECTIONS = { "bjj" => "BJJ / MMA", "judo" => "Judo", "other" => "Other", "wrestling" => "Wrestling" }.freeze
    SECTION_OF_DISCIPLINE = { "bjj" => "bjj", "striking" => "bjj", "judo" => "judo", "sambo" => "judo", "wrestling" => "wrestling", "other" => "other" }.freeze

    LABELS = {
      "when" => { "morning" => "Morning", "afternoon" => "Afternoon", "evening" => "Evening" },
      "who" => { "adults" => "Adults", "kids" => "Kids and teens", "women" => "Women" },
      "discipline" => {
        "bjj" => "Jiu Jitsu", "wrestling" => "Wrestling", "judo" => "Judo", "sambo" => "Sambo",
        "striking" => "Striking", "other" => "Other"
      },
      "attire" => { "gi" => "Gi", "nogi" => "No-Gi" }
    }.freeze

    def self.themes = Dir[File.join(ASSETS, "themes", "*.css")].map { |path| File.basename(path, ".css") }.sort

    def self.from_project(theme: nil)
      data = File.join(ROOT, "data")
      config = YAML.load_file(File.join(ROOT, "config/site.yml"))
      config["theme"] = theme if theme
      directory = GymDirectory.load(
        File.join(data, "sheet/gyms.csv"), File.join(data, "gym_aliases.yml"), overrides: File.join(data, "gym_overrides.yml")
      )

      new(
        timetable: Timetable.load(File.join(data, "sheet"), directory, hold: YAML.load_file(File.join(data, "unconfirmed_gyms.yml"))),
        directory: directory,
        config: config,
        pulled_on: Date.iso8601(File.read(File.join(data, "sheet/pulled_on.txt")).strip),
        regions: Regions.load(REGIONS, borders: REGION_BORDERS),
        coordinates: GymLocator.load(COORDINATES),
        sections: YAML.load_file(GYM_SECTIONS)
      )
    end

    def initialize(timetable:, directory:, config:, pulled_on:, regions:, coordinates: {}, sections: {})
      @timetable = timetable
      @directory = directory
      @config = config
      @pulled_on = pulled_on
      @regions = regions
      @coordinates = coordinates
      @sections = sections
      @templates = {}
    end

    attr_reader :timetable

    def html = page("index")

    def bingo_html = page("bingo")

    def write(to:)
      FileUtils.mkdir_p(File.join(to, "bingo"))
      File.write(File.join(to, "index.html"), html)
      File.write(File.join(to, "bingo/index.html"), bingo_html)
      copy_fonts(to)
    end

    private

    attr_reader :directory, :config

    def page(name) = render(name).gsub(/^[ \t]+/, "").squeeze("\n")

    def render(name, **locals)
      scope = binding
      locals.each { |key, value| scope.local_variable_set(key, value) }
      template(name).result(scope)
    end

    def template(name)
      @templates[name] ||= ERB.new(File.read(File.join(VIEWS, "#{name}.html.erb")), trim_mode: "-")
    end

    def asset(name) = File.read(File.join(ASSETS, name))

    def stylesheet = @stylesheet ||= theme_css + asset("grid.css") + asset("map.css") + asset("print.css")

    def bingo_stylesheet = theme_css.gsub('url("fonts/', 'url("../fonts/') + asset("bingo.css")

    def script(*names) = names.map { |name| asset(name).gsub(/^import .*;\n/, "") }.join("\n")

    # "wayfind.night" is the wayfind theme with the night color scheme layered on top.
    def theme_css
      theme = config.fetch("theme")
      raise ArgumentError, "Unknown theme: #{theme}. Add app/assets/themes/#{theme}.css." unless self.class.themes.include?(theme)

      [theme.split(".").first, theme].uniq.map { |name| asset("themes/#{name}.css") }.join
    end

    def row_for(start_time) = timetable.start_times.index(start_time) + 2

    def copy_fonts(to)
      fonts = stylesheet.scan(FONT_REFERENCE).flatten
      return if fonts.empty?

      FileUtils.mkdir_p(File.join(to, "fonts"))
      fonts.each { |font| FileUtils.cp(File.join(ASSETS, "fonts", font), File.join(to, "fonts", font)) }
    end

    def pulled_on = @pulled_on.strftime("%b %-d, %Y")

    def support? = !config["support_url"].to_s.empty?

    def day_options = timetable.by_day.keys.map { |day| [day[0, 3].downcase, day[0, 3]] }

    def options(facet)
      present = timetable.classes.flat_map { |entry| facets(entry).fetch(facet) }.uniq

      LABELS.fetch(facet).select { |value, _| present.include?(value) }.to_a
    end

    def facets(entry)
      {
        "day" => [entry.day_key], "when" => [entry.time_of_day], "who" => entry.who, "discipline" => entry.disciplines,
        "attire" => [entry.attire].compact, "format" => [entry.format], "city" => [entry.gym.city_slug],
        "region" => regions_of(entry.gym).map(&:slug), "gym" => [entry.gym.slug]
      }
    end

    def regions_of(gym) = @regions.of(gym)

    def region_slugs(gym) = regions_of(gym).map(&:slug).join(" ")

    def region_options
      present = timetable.gyms.flat_map { |gym| regions_of(gym) }.uniq
      @regions.all.select { |region| present.include?(region) }.map { |region| [region.slug, region.name] }
    end

    def city_options =timetable.gyms.uniq(&:city_slug).map { |gym| [gym.city_slug, gym.city] }.sort_by(&:last)

    def gym_options = timetable.gyms.map { |gym| [gym.slug, gym.name] }

    def pins
      timetable.gyms.filter_map do |gym|
        lat, lng = @coordinates[gym.slug]
        next unless lat

        { slug: gym.slug, name: gym.name, city: gym.city, regions: regions_of(gym).map(&:slug), lat:, lng:, site: gym.website, directions: gym.directions_url }
      end
    end

    def pins_json = json(pins)

    def bingo_squares_json
      json(timetable.classes.map do |entry|
        {
          title: entry.title, gym: entry.gym.name, day: entry.day[0, 3], time: entry.time_label, facets: facets(entry),
          text: [entry.title, entry.gym.name, entry.gym.city, *details(entry)].join(" ").downcase
        }
      end)
    end

    def json(data) = JSON.generate(data).gsub("</", "<\\/")

    def gym_sections = directory.group_by { |gym| section_of(gym) }.sort_by { |section, _| SECTIONS.keys.index(section) }

    def section_of(gym)
      @sections.fetch(gym.name) do
        tally = section_tally[gym.slug]
        next tally.max_by { |section, count| [count, -SECTIONS.keys.index(section)] }.first if tally

        { /wrestl/i => "wrestling", /judo/i => "judo" }.find { |pattern, _| gym.name.match?(pattern) }&.last || "bjj"
      end
    end

    def section_tally
      @section_tally ||= timetable.classes.group_by { |entry| entry.gym.slug }.transform_values do |entries|
        entries.flat_map { |entry| entry.disciplines.map { |discipline| SECTION_OF_DISCIPLINE.fetch(discipline) } }.tally
      end
    end

    def class_count(gym) = class_counts.fetch(gym.slug, 0)

    def class_counts = @class_counts ||= timetable.classes.map { |entry| entry.gym.slug }.tally

    def audience_tag(entry) = { "kids" => "Kids and teens", "women" => "Women" }[entry.who.first]

    def details(entry)
      [audience_tag(entry), ("Open mat" if entry.format == "open"), entry.season, entry.note].compact
    end

    def hostname(url) = url[%r{\Ahttps?://(?:www\.)?([^/?#]+)}i, 1]
  end
end
