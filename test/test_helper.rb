$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "mat_times"

module FixtureData
  SHEET = File.expand_path("fixtures/sheet", __dir__)
  ALIASES = File.expand_path("fixtures/gym_aliases.yml", __dir__)

  def directory
    @directory ||= MatTimes::GymDirectory.load(File.join(SHEET, "gyms.csv"), ALIASES)
  end

  def timetable
    @timetable ||= MatTimes::Timetable.load(SHEET, directory)
  end
end
