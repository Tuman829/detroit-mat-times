require "test_helper"

class ClockTest < Minitest::Test
  def test_parses_morning_and_evening
    assert_equal 345, MatTimes::Clock.parse("5:45 AM")
    assert_equal 1170, MatTimes::Clock.parse("7:30 PM")
  end

  def test_noon_and_midnight
    assert_equal 720, MatTimes::Clock.parse("12:00 PM")
    assert_equal 0, MatTimes::Clock.parse("12:00 AM")
  end

  def test_rejects_garbage
    assert_raises(ArgumentError) { MatTimes::Clock.parse("soon") }
  end

  def test_formats
    assert_equal "5:45 AM", MatTimes::Clock.format(345)
    assert_equal "12:00 PM", MatTimes::Clock.format(720)
    assert_equal "1:05 PM", MatTimes::Clock.format(785)
  end
end
