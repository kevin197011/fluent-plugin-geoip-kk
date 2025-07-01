# frozen_string_literal: true

require 'maxminddb'
require 'lru_redux'
require 'fluent/plugin/filter'
require 'ipaddr'
require 'zlib'
require 'stringio'

module Fluent
  module Plugin
    class GeoipFilter < Filter
      Fluent::Plugin.register_filter('geoip', self)

      helpers :record_accessor

      # Default cache size (number of IP addresses to cache)
      DEFAULT_CACHE_SIZE = 8192
      DEFAULT_CACHE_TTL = 3600 # 1 hour in seconds
      DEFAULT_DB_FILENAME = 'GeoLite2-City.mmdb'

      desc 'Path to the GeoIP database file'
      config_param :database_path, :string, default: nil

      desc 'Field name that contains the IP address'
      config_param :key_name, :string, default: 'client_ip'

      desc 'Output field name to store GeoIP data'
      config_param :out_key, :string, default: 'geo'

      desc 'Flatten the GeoIP data structure'
      config_param :flatten, :bool, default: false

      desc 'Size of the LRU cache'
      config_param :cache_size, :integer, default: DEFAULT_CACHE_SIZE

      desc 'TTL for cached items in seconds'
      config_param :cache_ttl, :integer, default: DEFAULT_CACHE_TTL

      desc 'Skip adding GeoIP data for private IP addresses'
      config_param :skip_private_ip, :bool, default: true

      desc 'Keep database in memory'
      config_param :memory_cache, :bool, default: true

      def initialize
        super
        @geoip = nil
        @ip_accessor = nil
        @database_data = nil
      end

      def configure(conf)
        super

        start_time = Time.now
        @database_path = resolve_database_path

        # Initialize MaxMindDB
        begin
          if @memory_cache
            @database_data = load_database(@database_path)
            @geoip = MaxMindDB.new(StringIO.new(@database_data))
          else
            @geoip = MaxMindDB.new(decompress_if_needed(@database_path))
          end

          load_time = Time.now - start_time
          log.info 'Loaded GeoIP database',
                   database: @database_path,
                   size: format_size(@database_data ? @database_data.size : File.size(@database_path)),
                   compressed_size: format_size(File.size(@database_path)),
                   load_time: format_time(load_time)
        rescue StandardError => e
          raise Fluent::ConfigError, "Failed to load GeoIP database: #{e.message}"
        end

        # Initialize IP field accessor
        @ip_accessor = record_accessor_create(@key_name)

        # Initialize cache with TTL support
        @geoip_cache = LruRedux::TTL::Cache.new(@cache_size, @cache_ttl)

        log.info 'Initialized GeoIP filter',
                 database: @database_path,
                 cache_size: @cache_size,
                 cache_ttl: @cache_ttl,
                 memory_cache: @memory_cache
      end

      def shutdown
        super
        @temp_db.unlink if @temp_db && File.exist?(@temp_db.path)
      end

      def filter(tag, time, record)
        ip_addr = @ip_accessor.call(record)
        return record if ip_addr.nil? || ip_addr.empty? || ip_addr == '-'

        begin
          ip = IPAddr.new(ip_addr)
          return record if @skip_private_ip && ip.private?
        rescue IPAddr::InvalidAddressError => e
          log.debug 'Invalid IP address', ip: ip_addr, error: e.message
          return record
        end

        geo_ip = @geoip_cache.getset(ip_addr) { get_geoip(ip_addr) }
        return record if geo_ip.empty?

        if @flatten
          record.merge!(hash_flatten(geo_ip, [@out_key]))
        else
          record[@out_key] = geo_ip
        end

        record
      rescue StandardError => e
        log.error 'Failed to process GeoIP lookup', error_class: e.class, error: e.message, tag: tag, time: time
        record
      end

      private

      def resolve_database_path
        return database_path if database_path && !database_path.empty?

        # Search paths in order of preference
        search_paths = [
          # 1. Current directory
          File.join(Dir.pwd, 'vendor/data', DEFAULT_DB_FILENAME),
          File.join(Dir.pwd, 'vendor/data', "#{DEFAULT_DB_FILENAME}.gz"),
          # 2. Gem vendor directory
          File.expand_path("../../../vendor/data/#{DEFAULT_DB_FILENAME}", __FILE__),
          File.expand_path("../../../vendor/data/#{DEFAULT_DB_FILENAME}.gz", __FILE__),
          # 3. System-wide locations
          '/usr/share/GeoIP/GeoLite2-City.mmdb',
          '/usr/local/share/GeoIP/GeoLite2-City.mmdb'
        ]

        # Find first existing database file
        found_path = search_paths.find { |path| File.exist?(path) }

        unless found_path
          available_paths = search_paths.join("\n  ")
          raise Fluent::ConfigError, "Could not find GeoIP database file. Searched in:\n  #{available_paths}"
        end

        log.info 'Found GeoIP database', path: found_path
        found_path
      end

      def load_database(path)
        if path.end_with?('.gz')
          Zlib::GzipReader.open(path, &:read)
        else
          File.binread(path)
        end
      end

      def decompress_if_needed(path)
        return path unless path.end_with?('.gz')

        decompressed_path = path.chomp('.gz')
        unless File.exist?(decompressed_path)
          File.open(decompressed_path, 'wb') do |file|
            Zlib::GzipReader.open(path) do |gz|
              file.write(gz.read)
            end
          end
        end
        decompressed_path
      end

      def format_size(bytes)
        units = %w[B KB MB GB]
        size = bytes.to_f
        unit_index = 0

        while size > 1024 && unit_index < units.length - 1
          size /= 1024
          unit_index += 1
        end

        format('%.2f %s', size, units[unit_index])
      end

      def format_time(seconds)
        if seconds < 1
          format('%.2f ms', seconds * 1000)
        else
          format('%.2f s', seconds)
        end
      end

      def get_geoip(ip_addr)
        geo_ip = @geoip.lookup(ip_addr)
        return {} if geo_ip.nil?

        result = {}

        if (coordinates = get_coordinates(geo_ip))
          result['coordinates'] = coordinates
        end

        if (country = get_country_info(geo_ip))
          result['country'] = country
        end

        if (city = get_city_info(geo_ip))
          result['city'] = city
        end

        if (region = get_region_info(geo_ip))
          result['region'] = region
        end

        if (postal = get_postal_info(geo_ip))
          result['postal'] = postal
        end

        result['timezone'] = geo_ip.location.time_zone if geo_ip.location && geo_ip.location.time_zone

        result
      end

      def get_coordinates(geo_ip)
        return nil unless geo_ip.location

        result = {}
        location = geo_ip.location

        result['latitude'] = location.latitude if location.latitude
        result['longitude'] = location.longitude if location.longitude
        result['accuracy_radius'] = location.accuracy_radius if location.accuracy_radius

        result.empty? ? nil : result
      end

      def get_country_info(geo_ip)
        return nil unless geo_ip.country

        result = {}
        country = geo_ip.country

        result['code'] = country.iso_code if country.iso_code
        result['name'] = country.name if country.name

        result.empty? ? nil : result
      end

      def get_city_info(geo_ip)
        return nil unless geo_ip.city

        result = {}
        city = geo_ip.city

        result['name'] = city.name if city.name
        result['confidence'] = city.confidence if city.confidence

        result.empty? ? nil : result
      end

      def get_region_info(geo_ip)
        return nil unless geo_ip.subdivisions && !geo_ip.subdivisions.empty?

        subdivision = geo_ip.subdivisions.first
        return nil unless subdivision

        result = {}
        result['code'] = subdivision.iso_code if subdivision.iso_code
        result['name'] = subdivision.name if subdivision.name

        result.empty? ? nil : result
      end

      def get_postal_info(geo_ip)
        return nil unless geo_ip.postal

        result = {}
        postal = geo_ip.postal

        result['code'] = postal.code if postal.code
        result['confidence'] = postal.confidence if postal.confidence

        result.empty? ? nil : result
      end

      def hash_flatten(hash, keys = [])
        ret = {}
        hash.each do |k, v|
          key_chain = keys + [k]
          if v.is_a?(Hash)
            ret.merge!(hash_flatten(v, key_chain))
          else
            ret[key_chain.join('_')] = v
          end
        end
        ret
      end
    end
  end
end
