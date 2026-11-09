require "test_helper"
require "tmpdir"

class SheetPullTest < Minitest::Test
  GRID = ",Sunday,Monday\n9:00 AM,Gym - Judo,\n"
  GYMS = "Gym,City,Street address,Website,Youth program (ages),Status / notes\n"

  def fetcher(body_for_gyms: GYMS, body: GRID)
    ->(url) { url.include?("gid=#{MatTimes::SheetPull::TABS.fetch("gyms.csv")}") ? body_for_gyms : body }
  end

  def test_builds_the_export_url_for_a_tab
    url = MatTimes::SheetPull.new(to: "x", fetcher: nil).url_for(123)

    assert_includes url, "/export?format=csv&gid=123"
  end

  def test_writes_every_tab_and_stamps_the_date
    Dir.mktmpdir do |dir|
      MatTimes::SheetPull.new(to: dir, fetcher: fetcher, today: Date.new(2026, 11, 9)).call

      assert_equal GRID, File.read(File.join(dir, "classes.csv"))
      assert_equal GYMS, File.read(File.join(dir, "gyms.csv"))
      assert_equal "2026-11-09", File.read(File.join(dir, "pulled_on.txt")).strip
    end
  end

  def test_an_html_error_page_leaves_the_existing_data_untouched
    Dir.mktmpdir do |dir|
      path = File.join(dir, "classes.csv")
      File.write(path, "keep me")

      assert_raises(MatTimes::SheetPull::BadResponse) do
        MatTimes::SheetPull.new(to: dir, fetcher: ->(_) { "<!DOCTYPE html><html>" }).call
      end
      assert_equal "keep me", File.read(path)
    end
  end
end
