# BIRT

BIRT is a geospatial bird migration analysis tool.  Users may search for a bird species and identify migrations patterns over a period of time.
[http://birt.eha.io](http://birt.eha.io)

## Setup the database
BIRT uses MongoDB and data from [eBird](http://ebird.org/content/ebird/).
The `birt-consume` [README.md](https://github.com/ecohealthalliance/birt-consumer/blob/master/README.md) provides instructions on parsing the eBird data and populating the database.

## Run
The run command can be issued by calling `make run`.  However, Meteor will need the `MONGO_URL` environment set.  This can be accomplished in one or two ways:

### a. Global environment variable
  ```
  export MONGO_URL=mongodb://localhost/birt
  make run
  ```
### b. Inline prior to executing `run`
 ```
 MONGO_URL=mondodb://localhost/birt make run
 ```

## Launch client
To launch the client, visit the following URL in your browser:
  ```
  http://localhost:3200/
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
