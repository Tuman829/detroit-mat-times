require "test_helper"
require "csv"

# Guards the real spreadsheet snapshot. A failure here means the sheet changed
# in a way the site can't represent, so it should stop the deploy.
class DataIntegrityTest < Minitest::Test
  SHEET = File.join(MatTimes::ROOT, "data/sheet")
  DIRECTORY = MatTimes::GymDirectory.load(
    File.join(SHEET, "gyms.csv"), File.join(MatTimes::ROOT, "data/gym_aliases.yml"), overrides: File.join(MatTimes::ROOT, "data/gym_overrides.yml")
  )
  TIMETABLE = MatTimes::Timetable.load(SHEET, DIRECTORY)

  def lines_in(tab)
    rows = CSV.read(File.join(SHEET, tab))
    rows.drop(1).flat_map { |row| row.drop(1).compact.flat_map { |cell| cell.split("\n").map(&:strip).reject(&:empty?) } }
  end

  def test_imports_every_line_of_the_master_tab
    assert_equal lines_in("classes.csv").size, TIMETABLE.classes.size
  end

  def test_every_gym_has_a_location
    TIMETABLE.gyms.each { |gym| refute_empty gym.location, gym.name }
  end

  def test_only_overridden_gyms_lack_a_website
    removed = YAML.load_file(File.join(MatTimes::ROOT, "data/gym_overrides.yml")).select { |_, url| url.nil? }.keys

    assert_equal removed.sort, DIRECTORY.reject(&:website).map(&:name).sort
  end

  def test_every_gym_with_classes_has_a_map_pin
    pins = MatTimes::GymLocator.load(MatTimes::SiteBuilder::COORDINATES)
    unpinned = TIMETABLE.gyms.reject { |gym| pins.key?(gym.slug) }.map(&:name)

    assert_empty unpinned, "Run rake gyms:locate"
  end

  def test_every_gym_with_classes_has_a_region
    regions = MatTimes::Regions.load(MatTimes::SiteBuilder::REGIONS)

    TIMETABLE.gyms.each { |gym| assert regions.for(gym.city), gym.name }
  end

  def test_class_lengths_describe_real_classes
    classes = TIMETABLE.classes.to_set { |klass| [klass.gym.name, klass.day[0, 3], MatTimes::Clock.format(klass.starts_at), klass.title] }

    YAML.load_file(File.join(MatTimes::ROOT, "data/class_lengths.yml")).each do |gym, record|
      record.fetch("classes").each do |klass|
        assert classes.include?([gym, klass["day"], klass["start"], klass["title"]]), "No class in the sheet matches #{gym}: #{klass}"
        assert klass["minutes"].nil? || (1..300).cover?(klass["minutes"]), "#{gym} #{klass}"
      end
    end
  end

  def test_hand_placed_gyms_are_real_and_go_to_a_real_section
    YAML.load_file(MatTimes::SiteBuilder::GYM_SECTIONS).each do |name, section|
      assert DIRECTORY.find { |gym| gym.name == name }, name
      assert_includes MatTimes::SiteBuilder::SECTIONS.keys, section
    end
  end

  def test_border_gyms_are_real_gyms
    names = TIMETABLE.gyms.map(&:name)

    YAML.load_file(MatTimes::SiteBuilder::REGION_BORDERS).each_key { |name| assert_includes names, name }
    MatTimes::Regions.load(MatTimes::SiteBuilder::REGIONS, borders: MatTimes::SiteBuilder::REGION_BORDERS)
  end

  def test_gyms_on_hold_are_real_and_written_up
    held = YAML.load_file(File.join(MatTimes::ROOT, "data/unconfirmed_gyms.yml"))
    write_up = File.read(File.join(MatTimes::ROOT, "docs/unconfirmed-gyms.md"))

    held.each do |name|
      assert DIRECTORY.fetch(name), name
      assert_includes write_up, "## #{name}", "#{name} needs a section in docs/unconfirmed-gyms.md"
    end
  end

  def test_gym_slugs_are_unique
    slugs = DIRECTORY.map(&:slug)

    assert_equal slugs.uniq, slugs
  end

  def test_every_class_ends_after_it_starts
    TIMETABLE.classes.select(&:ends_at).each do |training_class|
      assert_operator training_class.ends_at, :>, training_class.starts_at, training_class.title
    end
  end

  def test_no_scheduling_text_leaks_into_titles
    TIMETABLE.classes.each do |training_class|
      refute_match(/\d\s*[AP]M\b|\bno class\b|\(Kids\)/i, training_class.title.sub(/\A6AM /i, ""))
    end
  end

  def test_the_wrestling_judo_sambo_tab_is_classified_as_such
    labels = lines_in("wrestling_judo_sambo.csv").map { |line| MatTimes::ClassLine.parse(line).title }.to_set
    grappling = %w[wrestling judo sambo]

    TIMETABLE.classes.select { |training_class| labels.include?(training_class.title) }.each do |training_class|
      assert (training_class.disciplines & grappling).any?, "#{training_class.title}: #{training_class.disciplines}"
    end
  end

  def test_every_kids_tab_line_is_tagged_for_kids
    assert_equal lines_in("kids.csv").size, TIMETABLE.classes.count { |training_class| training_class.who == %w[kids] }
  end
end
