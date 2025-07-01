# frozen_string_literal: true

require 'maxminddb'
require 'json'
require 'zlib'
require 'tempfile'

# Database path resolution
def find_database
  search_paths = [
    File.join(Dir.pwd, 'vendor/data/GeoLite2-City.mmdb'),
    File.join(Dir.pwd, 'vendor/data/GeoLite2-City.mmdb.gz'),
    File.expand_path('../vendor/data/GeoLite2-City.mmdb', __dir__),
    File.expand_path('../vendor/data/GeoLite2-City.mmdb.gz', __dir__),
    '/usr/share/GeoIP/GeoLite2-City.mmdb',
    '/usr/local/share/GeoIP/GeoLite2-City.mmdb'
  ]

  found_path = search_paths.find { |path| File.exist?(path) }
  raise "GeoIP database not found. Searched in:\n  #{search_paths.join("\n  ")}" unless found_path

  found_path
end

def decompress_if_needed(path)
  return path unless path.end_with?('.gz')

  temp_db = Tempfile.new(['geoip', '.mmdb'])
  temp_db.binmode

  Zlib::GzipReader.open(path) do |gz|
    temp_db.write(gz.read)
  end

  temp_db.close
  at_exit { temp_db.unlink }
  temp_db.path
end

# Initialize database
db_path = find_database
db = MaxMindDB.new(decompress_if_needed(db_path))

# Test cases
test_cases = [
  {
    ip: '128.101.101.101',  # University of Minnesota
    desc: 'US University IP'
  },
  {
    ip: '185.199.108.153',  # GitHub Pages
    desc: 'GitHub Pages IP'
  },
  {
    ip: '8.8.8.8',          # Google DNS
    desc: 'Google Public DNS'
  },
  {
    ip: '192.168.1.1',      # Private IP
    desc: 'Private Network IP'
  }
]

def format_result(result)
  return 'Private IP address' unless result

  data = {}

  data[:country] = result.country.name if result.country

  data[:city] = result.city.name if result.city

  if result.location
    data[:coordinates] = {
      latitude: result.location.latitude,
      longitude: result.location.longitude
    }
    data[:timezone] = result.location.time_zone if result.location.time_zone
  end

  data[:region] = result.subdivisions.first.name if result.subdivisions && !result.subdivisions.empty?

  data[:postal] = result.postal.code if result.postal

  data
end

puts "\nGeoIP Database Test Results"
puts "==========================\n"
puts "Using database: #{db.metadata.database_type} (#{db.metadata.build_epoch})\n\n"

test_cases.each do |test_case|
  puts "Testing #{test_case[:desc]} (#{test_case[:ip]})"
  puts '-' * 50

  begin
    result = db.lookup(test_case[:ip])
    formatted_result = format_result(result)

    if formatted_result == 'Private IP address'
      puts formatted_result
    else
      puts JSON.pretty_generate(formatted_result)
    end
  rescue MaxMindDB::AddressNotFoundError
    puts 'IP address not found in the database.'
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  puts "\n"
end
