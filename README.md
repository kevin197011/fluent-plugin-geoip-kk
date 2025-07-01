# fluent-plugin-geoip-kk

[Fluentd](http://fluentd.org) filter plugin to add geoip.

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-geoip-kk.svg)](https://badge.fury.io/rb/fluent-plugin-geoip-kk)
[![Ruby](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml)

## Requirements

| fluent-plugin-geoip-kk | fluentd    | ruby   |
|----------------------------|------------|--------|
| >= 1.0.3                   | >= v0.14.0 | >= 2.1 |
| < 1.0.0                    | >= v0.12.0 | >= 1.9 |

## GeoIP Database

This plugin comes bundled with the GeoLite2-City database file. The plugin will automatically search for the database file in the following locations (in order of preference):

1. Custom path specified in configuration
2. Current working directory: `./vendor/data/GeoLite2-City.mmdb`
3. Gem installation directory: `$(gem environment gemdir)/gems/fluent-plugin-geoip-kk-[VERSION]/vendor/data/GeoLite2-City.mmdb`
4. System-wide locations:
   - `/usr/share/GeoIP/GeoLite2-City.mmdb`
   - `/usr/local/share/GeoIP/GeoLite2-City.mmdb`
5. Legacy path (for backward compatibility)

You can override the database path in your configuration:

```xml
<filter access.nginx.**>
  @type geoip
  database_path /path/to/your/GeoLite2-City.mmdb  # Optional: defaults to auto-discovery
  # ... other configurations ...
</filter>
```

Note: The bundled database is from MaxMind's GeoLite2 Free Database. For production use, you might want to:
1. Use your own licensed MaxMind database
2. Regularly update the database file
3. Configure a custom path to the database file

### Database Auto-Discovery

The plugin will automatically find and use the GeoIP database file. If you need to check which database file is being used, you can find this information in the Fluentd logs when the plugin starts:

```
2024-01-28 12:00:00 +0000 [info]: Found GeoIP database path=/path/to/found/database.mmdb
```

## Installation

```bash
# for fluentd
$ gem install fluent-plugin-geoip-kk

# for td-agent2
$ sudo td-agent-gem install fluent-plugin-geoip-kk
```

## Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| key_name | string | client_ip | Field name that contains the IP address |
| out_key | string | geo | Output field name to store GeoIP data |
| database_path | string | data/GeoLite2-City.mmdb | Path to the GeoIP database file |
| flatten | bool | false | Flatten the GeoIP data structure |
| cache_size | integer | 8192 | Size of the LRU cache |
| cache_ttl | integer | 3600 | TTL for cached items in seconds |
| skip_private_ip | bool | true | Skip adding GeoIP data for private IP addresses |

## Usage Examples

### Basic Configuration

```xml
<filter access.nginx.**>
  @type geoip
  key_name client_ip
  out_key geo
</filter>
```

### Advanced Configuration

```xml
<filter access.nginx.**>
  @type geoip

  # IP address field configuration
  key_name client_ip
  out_key geo

  # Database configuration
  database_path /path/to/GeoLite2-City.mmdb

  # Cache configuration
  cache_size 10000    # Cache up to 10000 IP addresses
  cache_ttl 3600      # Cache TTL: 1 hour

  # Output configuration
  flatten false       # Keep nested structure

  # IP processing configuration
  skip_private_ip true  # Skip private IP addresses
</filter>
```

### Input Example

```json
{
  "client_ip": "93.184.216.34",
  "scheme": "http",
  "method": "GET",
  "host": "example.com",
  "path": "/",
  "query": "-",
  "req_bytes": 200,
  "referer": "-",
  "status": 200,
  "res_bytes": 800,
  "res_body_bytes": 600,
  "taken_time": 0.001,
  "user_agent": "Mozilla/5.0"
}
```

### Output Example (Default Structure)

```json
{
  "client_ip": "93.184.216.34",
  "scheme": "http",
  "method": "GET",
  // ... other original fields ...
  "geo": {
    "coordinates": {
      "latitude": 42.150800000000004,
      "longitude": -70.8228,
      "accuracy_radius": 100
    },
    "country": {
      "code": "US",
      "name": "United States"
    },
    "city": {
      "name": "Norwell",
      "confidence": 90
    },
    "region": {
      "code": "MA",
      "name": "Massachusetts"
    },
    "postal": {
      "code": "02061",
      "confidence": 95
    },
    "timezone": "America/New_York"
  }
}
```

### Output Example (Flattened Structure)

When `flatten true` is specified:

```json
{
  "client_ip": "93.184.216.34",
  // ... other original fields ...
  "geo_coordinates_latitude": 42.150800000000004,
  "geo_coordinates_longitude": -70.8228,
  "geo_coordinates_accuracy_radius": 100,
  "geo_country_code": "US",
  "geo_country_name": "United States",
  "geo_city_name": "Norwell",
  "geo_city_confidence": 90,
  "geo_region_code": "MA",
  "geo_region_name": "Massachusetts",
  "geo_postal_code": "02061",
  "geo_postal_confidence": 95,
  "geo_timezone": "America/New_York"
}
```

## Performance Optimization

The plugin includes several performance optimizations:

1. LRU Cache with TTL
   - Caches GeoIP lookups to reduce database access
   - Configurable cache size and TTL
   - Automatic cache cleanup for expired entries

2. Skip Private IPs
   - Optionally skip processing private IP addresses
   - Reduces unnecessary database lookups

3. Efficient Record Access
   - Uses Fluentd's record accessor for optimized field access
   - Reduces memory allocations

## VS.
[fluent-plugin-geoip](https://github.com/y-ken/fluent-plugin-geoip)
Fluentd output plugin to geolocate with geoip.
It is able to customize fields with placeholder.

* Easy to install.
    * Not require to install Development Tools and geoip-dev library.
    * ( fluent-plugin-geoip use geoip-c gem but our plugin use geoip. It's conflict. )
* 5-10 times faster by the LRU cache.
    * See [benchmark](test/bench_geoip_filter.rb).

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Publishing

This gem uses GitHub Actions for automated publishing. To publish a new version:

1. Update the version number in `fluent-plugin-geoip-kk.gemspec`
2. Commit the changes:
   ```bash
   git add fluent-plugin-geoip-kk.gemspec
   git commit -m "Bump version to x.x.x"
   ```
3. Create and push a new tag:
   ```bash
   git tag vx.x.x
   git push origin main vx.x.x
   ```
4. The GitHub Action will automatically build and publish the gem to RubyGems.org

## Contributing

1. Fork it ( https://github.com/kevin197011/fluent-plugin-geoip-kk/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Copyright

Copyright (c) 2015 Yuri Umezaki

## License

[Apache License, Version 2.0.](http://www.apache.org/licenses/LICENSE-2.0)

This product includes GeoLite data created by MaxMind, available from
[http://www.maxmind.com](http://www.maxmind.com).
