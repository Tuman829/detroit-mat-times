require "test_helper"
require "tempfile"

class GymDirectoryTest < Minitest::Test
  include FixtureData

  def test_finds_a_gym_by_its_exact_name
    assert_equal "Troy", directory.fetch("Test Gym").city
  end

  def test_finds_a_gym_by_alias
    assert_equal "Other Club of Michigan", directory.fetch("Other Club").name
  end

  def test_an_unknown_label_stops_the_build
    error = assert_raises(MatTimes::UnknownGym) { directory.fetch("Nowhere BJJ") }
    assert_match "Nowhere BJJ", error.message
  end

  def test_skips_blank_spacer_rows
    assert_equal ["Other Club of Michigan", "Quiet Gym", "Test Gym"], directory.map(&:name)
  end

  def test_an_alias_to_a_missing_gym_stops_the_build
    Tempfile.create(["aliases", ".yml"]) do |file|
      file.write("Ghost: Ghost Gym\n")
      file.flush

      assert_raises(MatTimes::UnknownGym) do
        MatTimes::GymDirectory.load(File.join(FixtureData::SHEET, "gyms.csv"), file.path)
      end
    end
  end

  def with_overrides(yaml)
    Tempfile.create(["overrides", ".yml"]) do |file|
      file.write(yaml)
      file.flush

      yield MatTimes::GymDirectory.load(File.join(FixtureData::SHEET, "gyms.csv"), FixtureData::ALIASES, overrides: file.path)
    end
  end

  def test_an_override_replaces_a_website
    with_overrides(%(Test Gym: "https://new.example"\n)) do |gyms|
      assert_equal "https://new.example", gyms.fetch("Test Gym").website
    end
  end

  def test_a_blank_override_removes_a_dead_website
    with_overrides("Test Gym: ~\n") { |gyms| assert_nil gyms.fetch("Test Gym").website }
  end

  def test_an_override_for_a_missing_gym_stops_the_build
    assert_raises(MatTimes::UnknownGym) { with_overrides(%(Ghost: "https://x.example"\n)) { } }
  end

  def test_rejects_a_website_that_is_not_http
    gym_row = "Gym,City,Street address,Website,Youth program (ages),Status / notes\nBad,Troy,1 Main,javascript:alert(1),,\n"

    Tempfile.create(["gyms", ".csv"]) do |file|
      file.write(gym_row)
      file.flush

      assert_raises(ArgumentError) { MatTimes::GymDirectory.load(file.path, FixtureData::ALIASES) }
    end
  end
end

class GymTest < Minitest::Test
  include FixtureData

  def test_slug_is_url_safe
    assert_equal "test-gym", directory.fetch("Test Gym").slug
    assert_equal "lanse-creuse", MatTimes::Gym.new(name: "L'Anse Creuse", city: "", address: "", website: "", youth: "", notes: "").slug
  end

  def test_map_url_searches_for_the_encoded_address
    assert_equal "https://www.google.com/maps/search/?api=1&query=1%20Main%20St%2C%20Troy%2C%20MI%2048084",
      directory.fetch("Test Gym").map_url
  end

  def test_map_url_leaves_out_parenthetical_source_notes
    gym = directory.fetch("Other Club")

    assert_equal "Rec Center, 2 Oak St, Detroit, MI 48201", gym.location
    assert_includes gym.map_url, "48201"
    refute_includes gym.map_url, "Elm"
  end

  def test_directions_url_routes_to_the_encoded_address
    assert_equal "https://www.google.com/maps/dir/?api=1&destination=1%20Main%20St%2C%20Troy%2C%20MI%2048084",
      directory.fetch("Test Gym").directions_url
  end
end
