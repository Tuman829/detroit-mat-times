module MatTimes
  TrainingClass = Data.define(:day, :starts_at, :ends_at, :title, :gym, :season, :note, :disciplines, :attire, :who, :format) do
    NOON = 12 * 60
    FIVE_PM = 17 * 60

    def time_of_day
      return "morning" if starts_at < NOON

      starts_at < FIVE_PM ? "afternoon" : "evening"
    end

    def day_key = day[0, 3].downcase

    def time_label
      ends_at ? "#{Clock.format(starts_at)}–#{Clock.format(ends_at)}" : Clock.format(starts_at)
    end
  end
end
