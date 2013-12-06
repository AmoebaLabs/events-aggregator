require 'executable'
require 'open-uri'
require 'icalendar'
require 'date'

class EventsAggregator
  include Executable

  # Set the output file name
  def out=(name)
    @outputFile = name
  end

  # Set the input file to read for URLs (one per line)
  def file=(name)
    file = File.open(name)

    @urls = []

    file.each do |line|
      url = line.strip
      if url.match /^http/
        @urls << url
      else
        $stderr.puts "Warning: Ignoring invalid (non HTTP) URL: #{url}"
      end
    end
  end

  # Default the file to config/calendars.txt
  def get_urls
    self.file = 'config/calendars.txt' unless @urls
    @urls
  end

  # Show this message
  def help!
    cli.show_help
    exit
  end
  alias :h! :help!

  #Write output
  def write_calendar(cal)
    unless @outputFile && !@outputFile.empty?
      $stderr.puts "Warning: You should specify output file (see --help). Defaulting to ./out.ical"
      @outputFile = './out.ical'
    end

    File.open(@outputFile, 'w') {|f| f.write(cal.to_ical) }
  end

  # Aggregate the calendar URLs specified into one
  def call
    urls = get_urls
    calendars = []

    # Load calendars from all the URLs
    urls.each do |url|
      begin
        data = URI.parse(url).read
      rescue Exception => ex
        $stderr.puts "Warning: Exception: #{ex.message}"
        $stderr.puts "Warning: Skipping URL: #{url} (probably not found)"
      end
      
      next unless data
      
      # Icalendar::parse(data) can return an array of calendars, so union them in to our existing set
      begin
        calendars = calendars | Icalendar::parse(data)
      rescue Exception => ex
        $stderr.puts "Warning: Exception: #{ex.message}"
        $stderr.puts "Warning: Skipping calendars for URL: #{url} (usually contain invalid data)"
      end
    end

    # Now iterate over the calendars and combine all their events in one new one
    newCal = Icalendar::Calendar.new

    calendars.each do |cal|
      cal.events.each do |event|
        newCal.add_component event
      end
    end

    puts "Done! Merged in #{newCal.events.count} events."

    write_calendar newCal
  end
end