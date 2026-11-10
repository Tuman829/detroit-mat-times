require "test_helper"
require "tmpdir"
require "zlib"
require "json"

class SiteBuilderTest < Minitest::Test
  include FixtureData

  CONFIG = { "title" => "Mat Times", "theme" => "timetable", "support_url" => "", "support_label" => "Buy me a coffee", "repo_url" => "" }.freeze

  def build(config = {})
    MatTimes::SiteBuilder.new(
      timetable: timetable, directory: directory, config: CONFIG.merge(config), pulled_on: Date.new(2026, 11, 9), regions: regions
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
    assert_includes html, 'data-day="sun" data-when="morning" data-who="kids" data-discipline="judo" data-attire="gi" data-format="class" data-city="troy" data-region="oakland-county" data-gym="test-gym"'
  end

  def test_region_is_a_filter_listing_regions_with_classes
    assert_includes html, 'name="region" value="detroit"'
    assert_includes html, 'name="region" value="oakland-county"'
  end

  def sections_in(page)
    page.scan(%r{<details class="gym-section" data-section="(\w+)" open>(.*?)</details>}m).to_h { |section, body| [section, body.scan(/id="gym-([\w-]+)"/).flatten] }
  end

  def test_gyms_sit_in_the_section_most_of_their_classes_are_in
    assert_equal({ "bjj" => %w[other-club-of-michigan quiet-gym], "wrestling" => %w[test-gym] }, sections_in(html))
  end

  def test_a_listed_gym_goes_to_its_listed_section
    page = MatTimes::SiteBuilder.new(
      timetable: timetable, directory: directory, config: CONFIG, pulled_on: Date.new(2026, 11, 9), regions: regions, sections: { "Test Gym" => "judo" }
    ).html

    assert_equal %w[test-gym], sections_in(page)["judo"]
  end

  def test_sections_are_collapsible_and_named
    assert_includes html, "<summary>BJJ / MMA"
    assert_includes html, "<summary>Wrestling"
  end

  def test_map_is_a_layout_choice
    assert_includes html, 'name="view" value="map"'
    assert_includes html, '<div id="map" class="map" hidden></div>'
  end

  def test_pins_carry_each_placed_gym
    page = MatTimes::SiteBuilder.new(
      timetable: timetable, directory: directory, config: CONFIG, pulled_on: Date.new(2026, 11, 9), regions: regions,
      coordinates: { "test-gym" => [42.5, -83.1] }
    ).html
    pins = JSON.parse(page[%r{<script type="application/json" id="gym-pins">(.*?)</script>}m, 1])

    assert_equal [{
      "slug" => "test-gym", "name" => "Test Gym", "city" => "Troy", "regions" => ["oakland-county"], "lat" => 42.5, "lng" => -83.1,
      "site" => "https://testgym.example", "directions" => "https://www.google.com/maps/dir/?api=1&destination=1%20Main%20St%2C%20Troy%2C%20MI%2048084"
    }], pins
  end

  def test_town_names_link_to_directions
    assert_includes html, '<a class="town" href="https://www.google.com/maps/dir/?api=1&amp;destination=1%20Main%20St%2C%20Troy%2C%20MI%2048084" target="_blank" rel="noopener">Troy</a>'
  end

  def test_the_week_grid_is_the_default_view
    assert_includes html, 'id="schedule" class="days" data-view="week"'
    assert_includes html, 'name="view" value="week" checked'
    refute_includes html, 'name="view" value="list" checked'
  end

  def compact(page) = page.gsub(/\s*\n\s*/, "")

  def test_the_grid_has_one_row_per_start_time_below_the_header
    assert_includes html, 'style="--rows: 4; --cols: 2"'
    assert_includes compact(html), '<li class="hour" style="--row: 2"><span>9:00 AM</span></li>'
    assert_includes compact(html), '<li class="hour" style="--row: 4"><span>6:40 PM</span></li>'
  end

  def test_each_day_is_a_column
    assert_includes html, 'id="sunday" style="--col: 2"'
    assert_includes html, 'id="monday" style="--col: 3"'
  end

  def test_classes_at_the_same_time_share_one_grid_cell
    cell = html[/<ol class="slot" style="--row: 2">(?:(?!<\/ol>).)*No Gi Wrestling.*?<\/ol>/m]

    assert_includes cell, "Women&#39;s BJJ"
  end

  def test_a_class_at_another_time_gets_its_own_row
    assert_includes html, '<ol class="slot" style="--row: 3">'
  end

  def test_only_time_ranges_are_marked_to_stay_visible_in_the_grid
    assert_includes html, '<span class="time ranged">6:40 PM–7:40 PM</span>'
    assert_includes html, '<span class="time">9:00 AM</span>'
  end

  def test_text_stays_readable_on_every_region_tint
    palette = File.read(File.join(MatTimes::SiteBuilder::ASSETS, "application.js"))[/REGION_PALETTE = \[(.*?)\]/, 1].scan(/#\h{6}/)
    tint = File.read(File.join(MatTimes::SiteBuilder::ASSETS, "map.css"))[/color-mix\(in srgb, var\(--region\) (\d+)%/, 1].to_i / 100.0
    refute_empty palette

    MatTimes::SiteBuilder.themes.each do |theme|
      css = File.read(File.join(MatTimes::SiteBuilder::ASSETS, "themes", "#{theme}.css"))
      surface, ink, muted = %w[surface ink muted].map { |token| css[/--#{token}:\s*(#\h{6})/, 1] }
      next unless surface

      palette.each do |color|
        card = mix(color, surface, tint)
        assert_operator contrast(muted, card), :>=, 7, "#{theme} muted on #{color} tint"
        assert_operator contrast(ink, card), :>=, 7, "#{theme} ink on #{color} tint"
      end
    end
  end

  def mix(color, base, share)
    "#" + color.delete("#").scan(/../).zip(base.delete("#").scan(/../)).map { |a, b| (a.to_i(16) * share + b.to_i(16) * (1 - share)).round.to_s(16).rjust(2, "0") }.join
  end

  def test_every_theme_is_readable
    MatTimes::SiteBuilder.themes.each do |theme|
      css = File.read(File.join(MatTimes::SiteBuilder::ASSETS, "themes", "#{theme}.css"))
      paper, ink, muted = %w[paper ink muted].map { |token| css[/--#{token}:\s*(#\h{6})/, 1] or flunk "#{theme} needs a hex --#{token}" }
      surface = css[/--surface:\s*(#\h{6})/, 1] || paper

      [paper, surface].each do |background|
        assert_operator contrast(ink, background), :>=, 7, "#{theme} ink on #{background}"
        assert_operator contrast(muted, background), :>=, 7, "#{theme} muted on #{background}"
      end
    end
  end

  def contrast(first, second)
    light, dark = [luminance(first), luminance(second)].minmax.reverse

    (light + 0.05) / (dark + 0.05)
  end

  def luminance(hex)
    red, green, blue = hex.delete("#").scan(/../).map do |pair|
      channel = pair.to_i(16) / 255.0
      channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end

    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  def test_can_build_any_theme_from_the_project
    assert_includes MatTimes::SiteBuilder.from_project(theme: "timetable").html, "Helvetica Neue"
  end

  def test_lists_the_available_themes_and_color_schemes
    assert_equal %w[timetable wayfind wayfind.night wayfind.signal], MatTimes::SiteBuilder.themes
  end

  def test_a_color_scheme_layers_over_its_theme
    night = build("theme" => "wayfind.night")

    assert_includes night, "Chivo Mono"
    assert_includes night, "--paper: #0b0e14"
    refute_includes build("theme" => "wayfind"), "--paper: #0b0e14"
  end

  def test_an_unknown_color_scheme_stops_the_build
    assert_raises(ArgumentError) { build("theme" => "wayfind.nope") }
  end

  def test_each_day_shows_its_class_count
    assert_includes html, '<span class="day-count">4</span>'
  end

  def test_class_details_are_separate_items
    refute_includes html, " · "
    assert_includes html, "<span>Kids and teens</span>"
    assert_includes html, '<span class="open">Open mat</span>'
  end

  def test_the_configured_theme_sets_the_styles
    assert_includes build("theme" => "wayfind"), "Chivo Mono"
    refute_includes build("theme" => "timetable"), "Chivo Mono"
  end

  def test_every_theme_gets_the_shared_print_styles
    %w[timetable wayfind].each { |theme| assert_includes build("theme" => theme), "@page week" }
  end

  def test_an_unknown_theme_stops_the_build
    error = assert_raises(ArgumentError) { build("theme" => "nope") }
    assert_match "nope", error.message
  end

  def builder(theme)
    MatTimes::SiteBuilder.new(
      timetable: timetable, directory: directory, config: CONFIG.merge("theme" => theme), pulled_on: Date.new(2026, 11, 9), regions: regions
    )
  end

  def test_writes_only_the_fonts_the_theme_uses
    Dir.mktmpdir do |dir|
      builder("wayfind").write(to: dir)

      assert File.exist?(File.join(dir, "index.html"))
      assert File.exist?(File.join(dir, "fonts/chivo-mono-800.woff2"))
    end

    Dir.mktmpdir do |dir|
      builder("timetable").write(to: dir)

      refute Dir.exist?(File.join(dir, "fonts"))
    end
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
  end

  def test_the_sheets_research_notes_stay_off_the_site
    refute_includes html, "No timetable published"
    refute_includes html, "Verified live"
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
      timetable: MatTimes::Timetable.load(FixtureData::SHEET, gyms), directory: gyms, config: CONFIG, pulled_on: Date.new(2026, 11, 9), regions: regions
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
  BUDGET_KB = 90

  def test_the_real_page_stays_within_budget_when_compressed
    html = MatTimes::SiteBuilder.from_project.html
    kilobytes = Zlib.gzip(html).bytesize / 1024.0

    assert_operator kilobytes, :<, BUDGET_KB, "Compressed page is #{kilobytes.round}KB"
  end
end
