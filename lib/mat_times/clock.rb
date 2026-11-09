module MatTimes
  # Times of day are plain integers: minutes since midnight.
  module Clock
    FORMAT = /\A(\d{1,2})(?::(\d{2}))?\s*([AP]M)\z/i

    module_function

    def parse(text)
      match = text.strip.match(FORMAT) or raise ArgumentError, "Unreadable time: #{text.inspect}"

      minutes(match[1], match[2], match[3])
    end

    def minutes(hour, minute, meridian)
      (hour.to_i % 12 + (meridian.upcase == "PM" ? 12 : 0)) * 60 + minute.to_i
    end

    def format(minutes)
      hour, minute = minutes.divmod(60)

      "#{(hour % 12).nonzero? || 12}:#{minute.to_s.rjust(2, "0")} #{hour < 12 ? "AM" : "PM"}"
    end
  end
end
