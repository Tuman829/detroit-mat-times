require "test_helper"

class ClassLineTest < Minitest::Test
  def parse(text) = MatTimes::ClassLine.parse(text)

  def test_splits_gym_label_from_title
    line = parse("Freedom Academy - No Gi Submission Wrestling")

    assert_equal "Freedom Academy", line.gym_label
    assert_equal "No Gi Submission Wrestling", line.title
  end

  def test_splits_on_the_first_separator_only
    assert_equal "Gi - Advanced", parse("Test Gym - Gi - Advanced").title
  end

  def test_rejects_a_line_without_a_gym
    assert_raises(ArgumentError) { parse("Open Mat") }
  end

  def test_reads_a_range_with_a_shared_meridian
    line = parse("MI-REV - Youth/HS Powerhouse Wrestling (5-6:30 PM; Nov 9-Mar 26)")

    assert_equal "Youth/HS Powerhouse Wrestling", line.title
    assert_equal 17 * 60, line.starts_at
    assert_equal 18 * 60 + 30, line.ends_at
    assert_equal "Nov 9-Mar 26", line.season
  end

  def test_reads_a_range_with_two_meridians
    line = parse("MI-REV - Homeschool Wrestling (11 AM-2:30 PM; Nov 9-Mar 26)")

    assert_equal 11 * 60, line.starts_at
    assert_equal 14 * 60 + 30, line.ends_at
  end

  def test_a_shared_meridian_never_starts_after_it_ends
    line = parse("Test Gym - Lunch Wrestling (11-1 PM)")

    assert_equal 11 * 60, line.starts_at
    assert_equal 13 * 60, line.ends_at
  end

  def test_an_off_grid_start_is_read_from_the_text
    line = parse("Plymouth Wrestling Academy - Youth Wrestling 9-12 (START 6:40 PM-7:40 PM; Nov 23-Jan 7)")

    assert_equal "Youth Wrestling 9-12", line.title
    assert_equal 18 * 60 + 40, line.starts_at
    assert_equal 19 * 60 + 40, line.ends_at
  end

  def test_a_range_alone_is_removed_from_the_title
    line = parse("Boombox / Cortex-CSG - Catch Wrestling (6-7:30 PM)")

    assert_equal "Boombox / Cortex-CSG", line.gym_label
    assert_equal "Catch Wrestling", line.title
    assert_nil line.season
  end

  def test_keeps_extra_segments_as_a_note
    line = parse("Lake Orion - Youth Novice Wrestling K-8 (5:45-7 PM; Nov 10-Feb 18; not middle school team)")

    assert_equal "not middle school team", line.note
    assert_equal "Nov 10-Feb 18", line.season
  end

  def test_a_cancellation_becomes_a_note
    line = parse("Shojin Judo - Adult Beginner Judo (no class Oct 24)")

    assert_equal "Adult Beginner Judo", line.title
    assert_equal "no class Oct 24", line.note
    assert_nil line.starts_at
  end

  def test_commas_in_the_title_survive
    assert_equal "Youth Novice Wrestling, grades 2-6",
      parse("Club PAW - Youth Novice Wrestling, grades 2-6 (6:30-7:45 PM; Nov 9-Mar 24)").title
  end

  def test_drops_the_sheets_kids_marker
    assert_equal "Kids Wrestling (Ages 6-12)", parse("DJJ Heights - Kids Wrestling (Ages 6-12) (Kids)").title
    assert_equal "Kids Class", parse("Monroe Jiu Jitsu - Kids Class (Kids)").title
  end

  def test_a_bracketed_source_note_moves_out_of_the_title
    line = parse("10th Planet Royal Oak - Kids Jiu-Jitsu (Ages 7+) (Kids) [schedule per Dec 2025 site snapshot]")

    assert_equal "Kids Jiu-Jitsu (Ages 7+)", line.title
    assert_equal "schedule per Dec 2025 site snapshot", line.note
  end

  def test_leaves_descriptive_parentheses_alone
    assert_equal "Adult Class (Advanced)", parse("Core Jiu Jitsu - Adult Class (Advanced)").title
    assert_equal "Randori (Age 16+)", parse("Ippon Martial Arts - Randori (Age 16+)").title
  end

  def test_an_age_range_is_not_mistaken_for_a_time
    line = parse("Roots-BF - Teens Kickboxing (9-13)")

    assert_equal "Teens Kickboxing (9-13)", line.title
    assert_nil line.ends_at
  end
end
