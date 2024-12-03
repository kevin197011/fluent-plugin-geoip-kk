# frozen_string_literal: true

require 'maxminddb'
require 'lru_redux'
require 'fluent/plugin/filter'

module Fluent
  module Plugin
    class GeoipFilter < Filter
      Fluent::Plugin.register_filter('geoip', self)

      def initialize
        @geoip_cache = LruRedux::Cache.new(8192)
        super
      end

      # 配置参数
      config_param :database_path, :string, default: "#{File.dirname(__FILE__)}/../../../data/GeoLite2-City.mmdb"
      config_param :key_name, :string, default: 'client_ip'
      config_param :out_key, :string, default: 'geo'
      config_param :flatten, :bool, default: false

      def configure(conf)
        super
        begin
          @geoip = MaxMindDB.new(@database_path)
        rescue StandardError => e
          log.warn 'Failed to configure parser. Use default pattern.', error_class: e.class, error: e.message
          log.warn_backtrace
        end
      end

      def filter(_tag, _time, record)
        ip_addr = record[@key_name]

        # Return the record immediately if the IP is invalid or nil
        return record if ip_addr.nil? || ip_addr == '-'

        geo_ip = @geoip_cache.getset(ip_addr) { get_geoip(ip_addr) }

        if flatten
          record.merge! hash_flatten(geo_ip, [@out_key])
        else
          record[@out_key] = geo_ip
        end

        record
      end

      private

      def get_geoip(ip_addr)
        geo_ip = @geoip.lookup(ip_addr)
        data = {}
        return data if geo_ip.nil? || ip_addr == '-'

        data['coordinates'] = [geo_ip.location.longitude, geo_ip.location.latitude] if geo_ip.location
        data['country_code'] = geo_ip.country.iso_code if geo_ip.country
        data['city'] = geo_ip.city.name if geo_ip.city
        data['region_code'] = geo_ip.subdivisions.first.iso_code if geo_ip.subdivisions.any?
        data
      end

      # 将嵌套的 Hash 展平
      def hash_flatten(a, keys = [])
        ret = {}
        a.each do |k, v|
          ks = keys + [k]
          if v.instance_of?(Hash)
            ret.merge!(hash_flatten(v, ks))
          else
            ret.merge!({ ks.join('_') => v })
          end
        end
        ret
      end
    end
  end
end
