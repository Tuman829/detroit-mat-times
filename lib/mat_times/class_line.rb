module MatTimes
  # One line of a spreadsheet cell, e.g.
  #   "MI-REV - Youth/HS Powerhouse Wrestling (5-6:30 PM; Nov 9-Mar 26)"
  class ClassLine
    SEPARATOR = " - "
    SOURCE_NOTE = /\s*\[([^\[\]]*)\]\s*\z/
    KIDS_MARKER = /\s*\(Kids\)\s*\z/
    TRAILING_GROUP = /\s*\(([^()]*)\)\s*\z/
    TIME_RANGE = /\A(?:START\s+)?(\d{1,2})(?::(\d{2}))?\s*([AP]M)?\s*-\s*(\d{1,2})(?::(\d{2}))?\s*([AP]M)\z/i
    SEASON = /\A[A-Z][a-z]{2} \d{1,2}-[A-Z][a-z]{2} \d{1,2}\z/
    CANCELLATION = /\Ano class\b/i

    attr_reader :gym_label, :title, :starts_at, :ends_at, :season, :note

    def self.parse(text)
      gym_label, title = text.strip.split(SEPARATOR, 2)
      raise ArgumentError, "No gym in line: #{text.inspect}" unless title

      new(gym_label, title)
    end

    def initialize(gym_label, title)
      @gym_label = gym_label
      @title = title
      extract_source_note
      @title = @title.sub(KIDS_MARKER, "").strip
      extract_schedule_details
    end

    private

    def extract_source_note
      @note = @title[SOURCE_NOTE, 1]
      @title = @title.sub(SOURCE_NOTE, "")
    end

    def extract_schedule_details
      group = @title[TRAILING_GROUP, 1] or return
      segments = group.split(";").map(&:strip)
      return unless segments.any? { |segment| schedule_detail?(segment) }

      @title = @title.sub(TRAILING_GROUP, "")
      notes = segments.reject { |segment| read_time_range(segment) || read_season(segment) }
      @note = notes.join("; ") unless notes.empty?
    end

    def schedule_detail?(segment)
      segment.match?(TIME_RANGE) || segment.match?(SEASON) || segment.match?(CANCELLATION)
    end

    def read_season(segment)
      @season = segment if segment.match?(SEASON)
    end

    def read_time_range(segment)
      match = segment.match(TIME_RANGE) or return

      start_hour, start_minute, start_meridian, end_hour, end_minute, end_meridian = match.captures
      @ends_at = Clock.minutes(end_hour, end_minute, end_meridian)
      @starts_at = Clock.minutes(start_hour, start_minute, start_meridian || end_meridian)
      @starts_at -= 12 * 60 if start_meridian.nil? && @starts_at > @ends_at
      true
    end
  end
end
