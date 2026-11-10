module MatTimes
  module Classifier
    DISCIPLINES = {
      "bjj" => /jiu|jits|bjj|grappl/i,
      "judo" => /judo|randori|\bkata\b/i,
      "other" => /yoga|self[- ]defen|control tactics/i,
      "sambo" => /sambo/i,
      "striking" => /box|muay|mma|striking/i,
      "wrestling" => /wrestl/i
    }.freeze

    # Gyms where a title like "Sparring" doesn't imply Jiu Jitsu.
    MIXED_GYMS = ["Ippon Martial Arts", "Michigan Top Team", "Warrior Way Martial Arts"].freeze

    module_function

    def disciplines(title, gym_name:)
      named = DISCIPLINES.select { |_, pattern| title.match?(pattern) }.keys
      return named unless named.empty?

      MIXED_GYMS.include?(gym_name) ? %w[other] : %w[bjj]
    end

    DEFAULT_ATTIRE = { %w[judo] => "gi", %w[wrestling] => "nogi" }.freeze

    def attire(title, disciplines:)
      return "nogi" if title.match?(/\bno[\s-]?gi\b/i)
      return "gi" if title.match?(/\bgi\b/i)

      DEFAULT_ATTIRE[disciplines]
    end
  end
end
