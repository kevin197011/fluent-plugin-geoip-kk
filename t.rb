# frozen_string_literal: true

require 'maxminddb'

# 读取 GeoLite2-City.mmdb 文件
db = MaxMindDB.new('data/GeoLite2-City.mmdb')

# 查询 IP 地址
ip = '128.101.101.101'

begin
  # 使用 `lookup` 方法查询 IP 地址
  result = db.lookup(ip)

  # 打印返回的地理信息
  puts "IP: #{ip}"
  puts "Country: #{result.country.name}"
  puts "City: #{result.city.name}" if result.city.name
  puts "Latitude: #{result.location.latitude}" if result.location.latitude
  puts "Longitude: #{result.location.longitude}" if result.location.longitude
  puts result.inspect
rescue MaxMindDB::AddressNotFoundError
  puts 'IP address not found in the database.'
end
