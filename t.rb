# frozen_string_literal: true

require 'maxminddb'

db = MaxMindDB.new('data/GeoLite2-City.mmdb')

ip = '128.101.101.101'

begin
  result = db.lookup(ip)

  puts "IP: #{ip}"
  puts "Country: #{result.country.name}"
  puts "City: #{result.city.name}" if result.city.name
  puts "Latitude: #{result.location.latitude}" if result.location.latitude
  puts "Longitude: #{result.location.longitude}" if result.location.longitude
  puts result.inspect
rescue MaxMindDB::AddressNotFoundError
  puts 'IP address not found in the database.'
end
