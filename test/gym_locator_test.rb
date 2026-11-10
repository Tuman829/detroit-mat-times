require "test_helper"
require "tmpdir"
require "json"

class GymLocatorTest < Minitest::Test
  include FixtureData

  def census(lat, lng) = JSON.generate(result: { addressMatches: [{ coordinates: { x: lng, y: lat } }] })

  def no_match = JSON.generate(result: { addressMatches: [] })

  def locate(file, response)
    asked = []
    fetcher = lambda do |url|
      asked << url
      response
    end
    MatTimes::GymLocator.new(file:, fetcher:).call(timetable.gyms)
    asked
  end

  def test_saves_coordinates_for_each_gym_with_classes
    Dir.mktmpdir do |dir|
      file = File.join(dir, "coordinates.yml")
      locate(file, census(42.56, -83.14))

      saved = YAML.load_file(file)
      assert_equal timetable.gyms.map(&:slug).sort, saved.keys.sort
      assert_equal [42.56, -83.14], saved.fetch("test-gym")
    end
  end

  def test_asks_the_census_geocoder_for_the_cleaned_address
    Dir.mktmpdir do |dir|
      asked = locate(File.join(dir, "coordinates.yml"), census(42.5, -83.1))

      assert_includes asked.first, "geocoding.geo.census.gov"
      assert(asked.any? { |url| url.include?("1%20Main%20St%2C%20Troy%2C%20MI%2048084") })
    end
  end

  def test_keeps_coordinates_already_on_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, "coordinates.yml")
      File.write(file, YAML.dump("test-gym" => [1.0, 2.0]))
      asked = locate(file, census(42.5, -83.1))

      assert_equal [1.0, 2.0], YAML.load_file(file).fetch("test-gym")
      refute(asked.any? { |url| url.include?("Troy") })
    end
  end

  def test_names_the_gyms_it_could_not_place
    Dir.mktmpdir do |dir|
      error = assert_raises(MatTimes::GymLocator::NotFound) do
        locate(File.join(dir, "coordinates.yml"), no_match)
      end

      assert_includes error.message, "Test Gym"
    end
  end
end
