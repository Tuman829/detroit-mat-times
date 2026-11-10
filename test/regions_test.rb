require "test_helper"

class RegionsTest < Minitest::Test
  include FixtureData

  def test_finds_the_region_for_a_city
    region = regions.for("Troy")

    assert_equal "Oakland County", region.name
    assert_equal "oakland-county", region.slug
  end

  def test_keeps_the_order_regions_are_listed_in
    assert_equal ["Detroit", "Oakland County"], regions.all.map(&:name)
  end

  def test_a_gym_on_a_border_belongs_to_both_regions
    border = MatTimes::Regions.new(YAML.load_file(REGIONS), borders: { "Line Gym" => "Detroit" })

    assert_equal %w[oakland-county detroit], border.of(Struct.new(:name, :city).new("Line Gym", "Troy")).map(&:slug)
    assert_equal %w[oakland-county], border.of(Struct.new(:name, :city).new("Other Gym", "Troy")).map(&:slug)
  end

  def test_names_a_border_region_that_does_not_exist
    error = assert_raises(MatTimes::Regions::Unknown) { MatTimes::Regions.new(YAML.load_file(REGIONS), borders: { "Line Gym" => "Mars" }) }

    assert_includes error.message, "Mars"
  end

  def test_names_a_city_without_a_region
    error = assert_raises(MatTimes::Regions::Unknown) { regions.for("Holly") }

    assert_includes error.message, "Holly"
    assert_includes error.message, "data/regions.yml"
  end
end
