require "test_helper"

class TimetableTest < Minitest::Test
  include FixtureData

  def find(title) = timetable.classes.find { |training_class| training_class.title.start_with?(title) }

  def test_reads_every_line_of_every_cell
    assert_equal 5, timetable.classes.size
  end

  def test_orders_by_day_then_time
    assert_equal ["Kids Judo 8-12", "No Gi Wrestling", "Women's BJJ", "Open Mat", "Youth Wrestling 9-12"],
      timetable.classes.map(&:title)
  end

  def test_groups_by_day_in_sheet_order
    assert_equal %w[Sunday Monday], timetable.by_day.keys
  end

  def test_uses_the_cell_time_as_the_start
    assert_equal 9 * 60, find("Kids Judo").starts_at
  end

  def test_text_in_the_cell_overrides_the_grid_time
    assert_equal 18 * 60 + 40, find("Youth Wrestling").starts_at
  end

  def test_links_each_class_to_its_gym
    assert_equal "Other Club of Michigan", find("Women's BJJ").gym.name
  end

  def test_kids_tab_sets_the_audience
    assert_equal %w[kids], find("Kids Judo").who
  end

  def test_women_tab_sets_the_audience
    assert_equal %w[women], find("Women's BJJ").who
  end

  def test_everything_else_is_for_adults
    assert_equal %w[adults], find("No Gi Wrestling").who
  end

  def test_open_mat_tab_sets_the_format
    assert_equal "open", find("Open Mat").format
    assert_equal "class", find("No Gi Wrestling").format
  end

  def test_buckets_time_of_day
    assert_equal "morning", find("Kids Judo").time_of_day
    assert_equal "evening", find("Open Mat").time_of_day
    assert_equal "evening", find("Youth Wrestling").time_of_day
  end

  def test_afternoon_runs_from_noon_until_five
    template = find("Open Mat")

    assert_equal "morning", template.with(starts_at: 11 * 60 + 59).time_of_day
    assert_equal "afternoon", template.with(starts_at: 12 * 60).time_of_day
    assert_equal "afternoon", template.with(starts_at: 16 * 60 + 59).time_of_day
  end

  def test_reports_gyms_with_classes_and_their_cities
    assert_equal ["Other Club of Michigan", "Test Gym"], timetable.gyms.map(&:name)
    assert_equal %w[Detroit Troy], timetable.cities
  end
end
