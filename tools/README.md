# BIRT-TOOLS

External node.js tools for working with bird data.

`npm install .`

`npm run-script clean && npm run-script build`

## Annual Sightings Script
The annual sight script will select all migrations from the year 1887 to 2012
and keep track of the number of sightings for each species. This is done to
provide recommended_dates to the user interface (UI) as well as filter out
species without many sightings. (see --min-insertion param below)

The script defaults to scan 100,000 records per year, but this could be
increased/decreased depending on the desired accuracy. A limit of zero (0) would
scan all records within the database. (see -limit param below)

`npm run-script annualSightings`

### The scrip may also be executed directly with the following usage:
```
Usage: build/annualSightings.js -u [mongodb://localhost:27017/birt] -d [boolean]

Options:
  -h, --help           Show help                                       [boolean]
  -u, --url            The mongodb url
                                     [default: "mongodb://localhost:27017/birt"]
  -d, --debug          Enable debugging messages                [default: false]
  -l, --limit          Specifiy the database record limit per year
                                                               [default: 100000]
  -m, --min_insertion  Specify the minimum insertion threshold (number of
                       sightings required to be included)         [default: 100]
```

## License
Copyright 2016 EcoHealth Alliance

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
