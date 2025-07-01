# frozen_string_literal: true

require 'maxminddb'
require 'lru_redux'
require 'fluent/plugin/filter'
require 'ipaddr'

module Fluent
  module Plugin
    class GeoipFilter < Filter
      Fluent::Plugin.register_filter('geoip', self)

      helpers :record_accessor

      # Default cache size (number of IP addresses to cache)
      DEFAULT_CACHE_SIZE = 8192
      DEFAULT_CACHE_TTL = 3600 # 1 hour in seconds

      desc 'Path to the GeoIP database file'
      config_param :database_path, :string, default: "#{File.dirname(__FILE__)}/../../../data/GeoLite2-City.mmdb"

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

      def initialize
        super
        @geoip = nil
        @ip_accessor = nil
      end

      def configure(conf)
        super

        unless File.exist?(@database_path)
          raise Fluent::ConfigError, "GeoIP database file '#{@database_path}' does not exist"
        end

        # Initialize MaxMindDB
        begin
          @geoip = MaxMindDB.new(@database_path)
        rescue StandardError => e
          raise Fluent::ConfigError, "Failed to load GeoIP database: #{e.message}"
        end

        # Initialize IP field accessor
        @ip_accessor = record_accessor_create(@key_name)

        # Initialize cache with TTL support
        @geoip_cache = LruRedux::TTL::Cache.new(@cache_size, @cache_ttl)

        log.info "Initialized GeoIP filter", database: @database_path, cache_size: @cache_size, cache_ttl: @cache_ttl
      end

      def filter(tag, time, record)
        ip_addr = @ip_accessor.call(record)
        return record if ip_addr.nil? || ip_addr.empty? || ip_addr == '-'

        begin
          ip = IPAddr.new(ip_addr)
          return record if @skip_private_ip && ip.private?
        rescue IPAddr::InvalidAddressError => e
          log.debug "Invalid IP address", ip: ip_addr, error: e.message
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
        log.error "Failed to process GeoIP lookup", error_class: e.class, error: e.message, tag: tag, time: time
        record
      end

      private

      def get_geoip(ip_addr)
        geo_ip = @geoip.lookup(ip_addr)
        return {} if geo_ip.nil?

        {
          'coordinates' => get_coordinates(geo_ip),
          'country' => get_country_info(geo_ip),
          'city' => get_city_info(geo_ip),
          'region' => get_region_info(geo_ip),
          'postal' => get_postal_info(geo_ip),
          'timezone' => geo_ip.location&.time_zone
        }.compact
      end

      def get_coordinates(geo_ip)
        return nil unless geo_ip.location

        {
          'latitude' => geo_ip.location.latitude,
          'longitude' => geo_ip.location.longitude,
          'accuracy_radius' => geo_ip.location.accuracy_radius
        }.compact
      end

      def get_country_info(geo_ip)
        return nil unless geo_ip.country

        {
          'code' => geo_ip.country.iso_code,
          'name' => geo_ip.country.name
        }.compact
      end

      def get_city_info(geo_ip)
        return nil unless geo_ip.city

        {
          'name' => geo_ip.city.name,
          'confidence' => geo_ip.city.confidence
        }.compact
      end

      def get_region_info(geo_ip)
        return nil unless geo_ip.subdivisions&.any?

        subdivision = geo_ip.subdivisions.first
        {
          'code' => subdivision.iso_code,
          'name' => subdivision.name
        }.compact
      end

      def get_postal_info(geo_ip)
        return nil unless geo_ip.postal

        {
          'code' => geo_ip.postal.code,
          'confidence' => geo_ip.postal.confidence
        }.compact
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
