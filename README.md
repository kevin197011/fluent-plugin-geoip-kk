# fluent-plugin-geoip-kk

[Fluentd](http://fluentd.org) filter plugin to add geoip.

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-geoip-kk.svg)](https://badge.fury.io/rb/fluent-plugin-geoip-kk)
[![Ruby](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml)

## Requirements

| fluent-plugin-geoip-kk | fluentd    | ruby   |
|----------------------------|------------|--------|
| >= 1.0.5                   | >= v0.14.0 | >= 2.1 |
| < 1.0.0                    | >= v0.12.0 | >= 1.9 |

## Features

- Automatic database handling (compressed/uncompressed)
- Memory-optimized database loading
- LRU caching for high-performance lookups
- Support for both legacy GeoIP and GeoIP2 databases
- Private IP address filtering
- Flexible output formatting (nested/flattened)

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
| database_path | string | auto-detect | Path to the GeoIP database file (supports .mmdb and .mmdb.gz) |
| flatten | bool | false | Flatten the GeoIP data structure |
| cache_size | integer | 8192 | Size of the LRU cache |
| cache_ttl | integer | 3600 | TTL for cached items in seconds |
| skip_private_ip | bool | true | Skip adding GeoIP data for private IP addresses |
| memory_cache | bool | true | Keep database in memory for better performance |

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
  database_path /path/to/your/GeoLite2-City.mmdb.gz  # Optional: supports both .mmdb and .mmdb.gz

  # Performance optimization
  memory_cache true     # Keep database in memory (recommended)
  cache_size 10000     # LRU cache size
  cache_ttl 3600      # Cache TTL in seconds

  # Output configuration
  flatten false       # Keep nested structure

  # IP processing configuration
  skip_private_ip true  # Skip private IP addresses
</filter>
```

### Output Examples

#### Default Structure (flatten: false)
```json
{
  "client_ip": "93.184.216.34",
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

#### Flattened Structure (flatten: true)
```json
{
  "client_ip": "93.184.216.34",
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

### Memory Usage vs Performance

The plugin offers two modes for database handling:

1. Memory Mode (Default, Recommended)
   - Loads entire database into memory
   - Fastest lookup performance
   - Higher memory usage (~56MB for GeoLite2-City)
   - Best for production environments

2. File Mode
   - Keeps database on disk
   - Lower memory usage
   - Slightly slower lookups due to disk I/O
   - Suitable for memory-constrained environments

### Caching Strategy

- LRU (Least Recently Used) cache with TTL
- Default cache size: 8192 entries
- Default TTL: 3600 seconds (1 hour)
- Adjust based on your traffic patterns:
  - High unique IPs: Increase cache_size
  - Stable IP patterns: Increase cache_ttl

### Database Compression

- Database is distributed in compressed format (.mmdb.gz)
- Automatic handling of compressed/uncompressed files
- ~52% size reduction (56MB → 27MB)
- No performance impact when using memory_cache

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

## License

[Apache License, Version 2.0.](http://www.apache.org/licenses/LICENSE-2.0)

This product includes GeoLite data created by MaxMind, available from
[http://www.maxmind.com](http://www.maxmind.com).
