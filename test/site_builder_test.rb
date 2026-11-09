require "test_helper"
require "zlib"

class SiteBuilderTest < Minitest::Test
  include FixtureData

  CONFIG = { "title" => "Mat Times", "support_url" => "", "support_label" => "Buy me a coffee", "repo_url" => "" }.freeze

  def build(config = {})
    MatTimes::SiteBuilder.new(
      timetable: timetable, directory: directory, config: CONFIG.merge(config), pulled_on: Date.new(2026, 11, 9)
    ).html
  end

  def html = @html ||= build

  def test_is_a_complete_document
    assert_match(/\A<!doctype html>/i, html)
    assert_includes html, '<html lang="en">'
    assert_includes html, 'name="viewport"'
  end

  def test_has_a_section_for_each_day_with_classes
    assert_includes html, 'id="sunday"'
    assert_includes html, 'id="monday"'
    refute_includes html, 'id="tuesday"'
  end

  def test_entries_carry_every_facet
    assert_includes html, 'data-day="sun" data-when="morning" data-who="kids" data-discipline="judo" data-attire="" data-format="class" data-city="troy" data-gym="test-gym"'
  end

  def test_each_class_links_to_the_gym_site_and_map
    assert_includes html, %(href="https://testgym.example")
    assert_includes html, "https://www.google.com/maps/search/?api=1&amp;query=1%20Main"
  end

  def test_the_gym_name_opens_its_card_and_works_without_javascript
    assert_includes html, 'href="#gym-test-gym" data-gym-link="test-gym"'
    assert_includes html, 'id="gym-test-gym"'
  end

  def test_external_links_open_safely
    assert_includes html, 'target="_blank" rel="noopener"'
  end

  def test_escapes_sheet_content
    assert_includes html, "Women&#39;s BJJ"
    assert_includes html, "https://other.example/?a=1&amp;b=2"
  end

  def test_shows_season_details_and_the_real_time
    assert_includes html, "Nov 23-Jan 7"
    assert_includes html, "6:40 PM–7:40 PM"
  end

  def test_the_directory_includes_gyms_without_published_classes
    assert_includes html, "Quiet Gym"
    assert_includes html, "No timetable published"
  end

  def test_only_offers_filters_that_have_classes
    assert_includes html, 'name="discipline" value="judo"'
    refute_includes html, 'name="discipline" value="sambo"'
  end

  def test_offers_each_filter_group
    %w[day when who discipline attire format city gym].each do |facet|
      assert_includes html, %(name="#{facet}"), facet
    end
  end

  def test_offers_each_print_mode
    %w[list week gyms].each { |mode| assert_includes html, %(data-print-as="#{mode}"), mode }
  end

  def test_support_link_is_hidden_until_configured
    refute_includes html, "Buy me a coffee"
  end

  def test_support_link_appears_when_configured
    page = build("support_url" => "https://coffee.example/me")

    assert_includes page, "Buy me a coffee"
    assert_includes page, "https://coffee.example/me"
  end

  def test_a_gym_without_a_working_site_still_gets_a_map_link
    gyms = MatTimes::GymDirectory.new(directory.map { |gym| gym.with(website: nil) }, { "Other Club" => "Other Club of Michigan" })
    page = MatTimes::SiteBuilder.new(
      timetable: MatTimes::Timetable.load(FixtureData::SHEET, gyms), directory: gyms, config: CONFIG, pulled_on: Date.new(2026, 11, 9)
    ).html

    refute_includes page, "testgym.example"
    assert_includes page, "maps/search"
  end

  def test_reports_real_totals_and_the_pull_date
    assert_includes html, "5 classes at 2 gyms"
    assert_includes html, "Nov 9, 2026"
  end

  def test_loads_nothing_from_other_servers
    refute_match(/<script[^>]+src=/, html)
    refute_match(/<link[^>]+stylesheet/, html)
  end
end

class PageWeightTest < Minitest::Test
  BUDGET_KB = 60

  def test_the_real_page_stays_within_budget_when_compressed
    html = MatTimes::SiteBuilder.from_project.html
    kilobytes = Zlib.gzip(html).bytesize / 1024.0

    assert_operator kilobytes, :<, BUDGET_KB, "Compressed page is #{kilobytes.round}KB"
  end
end
