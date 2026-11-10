require "test_helper"
require "tmpdir"
require "json"

class BingoTest < Minitest::Test
  include FixtureData

  CONFIG = { "title" => "Mat Times", "theme" => "wayfind", "support_url" => "", "support_label" => "", "repo_url" => "" }.freeze

  def builder
    MatTimes::SiteBuilder.new(timetable: timetable, directory: directory, config: CONFIG, pulled_on: Date.new(2026, 11, 9), regions: regions)
  end

  def bingo = @bingo ||= builder.bingo_html

  def squares = JSON.parse(bingo[%r{<script type="application/json" id="bingo-squares">(.*?)</script>}m, 1])

  def test_is_written_to_its_own_page_that_finds_the_shared_fonts
    Dir.mktmpdir do |dir|
      builder.write(to: dir)

      page = File.read(File.join(dir, "bingo/index.html"))
      assert_includes page, 'url("../fonts/chivo-mono-800.woff2")'
      assert File.exist?(File.join(dir, "fonts/chivo-mono-800.woff2"))
    end
  end

  def test_stays_hidden_from_the_schedule
    refute_includes builder.html, "bingo"
  end

  def test_offers_the_schedule_filters
    assert_includes bingo, 'name="q"'
    assert_includes bingo, 'name="day" value="sun"'
    assert_includes bingo, 'name="region" value="oakland-county"'
    assert_includes bingo, 'name="discipline" value="judo"'
    assert_includes bingo, 'name="gym" value="test-gym"'
  end

  def test_offers_three_card_sizes
    %w[5x5 6x8 12x24].each { |size| assert_includes bingo, %(name="size" value="#{size}") }
  end

  def test_each_square_carries_a_class_and_the_facets_to_filter_it
    square = squares.find { |each| each["gym"] == "Test Gym" && each["day"] == "Sun" }

    assert square["title"]
    assert square["time"]
    assert_equal({ "day" => ["sun"], "when" => ["morning"], "who" => ["kids"], "discipline" => ["judo"], "attire" => ["gi"], "format" => ["class"],
                   "city" => ["troy"], "region" => ["oakland-county"], "gym" => ["test-gym"] }, square["facets"])
    assert_includes square["text"], "test gym"
  end

  def test_has_one_square_per_class
    assert_equal timetable.classes.size, squares.size
  end
end
