require "test_helper"

class ClassifierTest < Minitest::Test
  def disciplines(title, gym: "Test Gym") = MatTimes::Classifier.disciplines(title, gym_name: gym)
  def attire(title) = MatTimes::Classifier.attire(title)

  def test_names_the_discipline_in_the_title
    assert_equal %w[judo], disciplines("Adult Beginner Judo")
    assert_equal %w[wrestling], disciplines("Youth Folkstyle Wrestling")
    assert_equal %w[sambo], disciplines("Combat Sambo")
    assert_equal %w[bjj], disciplines("Gi Jiu Jitsu")
    assert_equal %w[bjj], disciplines("Adult No-Gi BJJ")
  end

  def test_a_class_can_cover_several_disciplines
    assert_equal %w[bjj judo], disciplines("Adult Gi Judo & Jiu Jitsu")
    assert_equal %w[striking wrestling], disciplines("Adult Boxing / Adult Wrestling")
  end

  def test_recognizes_striking
    assert_equal %w[striking], disciplines("Teens Kickboxing (9-13)")
    assert_equal %w[striking], disciplines("Muay Thai")
    assert_equal %w[striking], disciplines("Striking Class")
  end

  def test_traditional_judo_terms_count_as_judo
    assert_equal %w[judo], disciplines("Randori (Age 16+)", gym: "Ippon Martial Arts")
    assert_equal %w[judo], disciplines("Kata (Age 16+)", gym: "Ippon Martial Arts")
  end

  def test_unnamed_classes_default_to_bjj
    assert_equal %w[bjj], disciplines("Fundamentals Class", gym: "Westside Jiu Jitsu Academy - Westland")
    assert_equal %w[bjj], disciplines("Kids Class")
  end

  def test_unnamed_classes_at_mixed_gyms_are_other
    assert_equal %w[other], disciplines("Little Bushidos (Age 5-7)", gym: "Ippon Martial Arts")
    assert_equal %w[other], disciplines("Intermediate Sparring", gym: "Michigan Top Team")
    assert_equal %w[other], disciplines("Adult Open Training", gym: "Warrior Way Martial Arts")
  end

  def test_non_grappling_classes_are_other
    assert_equal %w[other], disciplines("Yoga")
    assert_equal %w[other], disciplines("Women's Self Defense")
    assert_equal %w[other], disciplines("ELITE Control Tactics ECT® (LEO Training)")
  end

  def test_attire
    assert_equal "nogi", attire("No Gi Jiu Jitsu")
    assert_equal "nogi", attire("Adult No-Gi BJJ")
    assert_equal "nogi", attire("NOGI Open Mat")
    assert_equal "gi", attire("Kids Gi Jiu Jitsu")
    assert_equal "gi", attire("GI Grappling")
    assert_nil attire("Fundamentals Class")
  end

  def test_gi_is_only_matched_as_a_word
    assert_nil attire("Beginner Class")
  end
end
