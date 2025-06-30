# fluent-plugin-geoip-kk

[Fluentd](http://fluentd.org) filter plugin to add geoip.

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-geoip-kk.svg)](https://badge.fury.io/rb/fluent-plugin-geoip-kk)
[![Ruby](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/fluent-plugin-geoip-kk/actions/workflows/gem-push.yml)

## Requirements

| fluent-plugin-geoip-kk | fluentd    | ruby   |
|----------------------------|------------|--------|
| >= 1.0.1                   | >= v0.14.0 | >= 2.1 |
| < 1.0.0                    | >= v0.12.0 | >= 1.9 |


## Installation

```bash
# for fluentd
$ gem install fluent-plugin-geoip-kk

# for td-agent2
$ sudo td-agent-gem install fluent-plugin-geoip-kk
```


## Usage

### Example 1:

```xml
<filter access.nginx.**>
  @type geoip
  # key_name client_ip
  # database_path /data/geoip/GeoLite2-City.mmdb
  # out_key geo
</filter>
```

Assuming following inputs are coming:

```json
access.nginx: {
  "client_ip":"93.184.216.34",
  "scheme":"http", "method":"GET", "host":"example.com",
  "path":"/", "query":"-", "req_bytes":200, "referer":"-",
  "status":200, "res_bytes":800, "res_body_bytes":600, "taken_time":0.001, "user_agent":"Mozilla/5.0"
}
```

then output bocomes as belows:

```json
access.nginx: {
  "client_ip":"93.184.216.34",
  "scheme":"http", "method":"GET", "host":"example.com",
  "path":"/", "query":"-", "req_bytes":200, "referer":"-",
  "status":200, "res_bytes":800, "res_body_bytes":600, "taken_time":0.001, "user_agent":"Mozilla/5.0",
  "geo": {
    "coordinates": [-70.8228, 42.150800000000004],
    "country_code": "US",
    "city": "Norwell",
    "region_code": "MA",
  }
}
```


## Parameters
- key_name *field_key*

    Target key name. default client_ip.

- out_key *string*

    Output prefix key name. default geo.

- database_path *file_path*

    Database file(GeoIPCity.dat) path.
    Get from [MaxMind](http://dev.maxmind.com/geoip/legacy/geolite/)

- flatten *bool*
    join hashed data by '_'. default false.


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
