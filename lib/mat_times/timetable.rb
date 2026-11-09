module MatTimes
  # Builds the week from the master tab. The kids, women and open mat tabs are
  # subsets of it, so they serve as hand-curated tags rather than extra classes.
  class Timetable
    DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

    attr_reader :classes

    def self.load(sheet_dir, directory)
      new(sheet_dir, directory)
    end

    def initialize(sheet_dir, directory)
      @sheet_dir = sheet_dir
      @directory = directory
      @kids = tagged("kids.csv")
      @women = tagged("women.csv")
      @open_mats = tagged("open_mats.csv")
      @classes = cells("classes.csv").map { |cell| build(*cell) }
                                     .sort_by.with_index { |klass, index| [DAYS.index(klass.day), klass.starts_at, index] }
    end

    def by_day = classes.group_by(&:day)

    def gyms = classes.map(&:gym).uniq.sort_by(&:name)

    def cities = gyms.map(&:city).uniq.sort

    private

    def tagged(tab) = cells(tab).to_set

    # Every [day, grid time, line of text] in a tab.
    def cells(tab)
      header, *rows = CSV.read(File.join(@sheet_dir, tab))

      rows.flat_map do |time, *columns|
        header.drop(1).zip(columns).flat_map do |day, cell|
          cell.to_s.split("\n").map(&:strip).reject(&:empty?).map { |line| [day, time, line] }
        end
      end
    end

    def build(day, time, text)
      line = ClassLine.parse(text)
      gym = @directory.fetch(line.gym_label)
      key = [day, time, text]

      TrainingClass.new(
        day: day,
        starts_at: line.starts_at || Clock.parse(time),
        ends_at: line.ends_at,
        title: line.title,
        gym: gym,
        season: line.season,
        note: line.note,
        disciplines: Classifier.disciplines(line.title, gym_name: gym.name),
        attire: Classifier.attire(line.title),
        who: [audience(key)],
        format: @open_mats.include?(key) ? "open" : "class"
      )
    end

    def audience(key)
      return "kids" if @kids.include?(key)

      @women.include?(key) ? "women" : "adults"
    end
  end
end
