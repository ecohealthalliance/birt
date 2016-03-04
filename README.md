# grits-net-meteor
![Build Status](https://circleci.com/gh/ecohealthalliance/grits-net-meteor.svg?style=shield&circle-token=0bb5a68a6c2ff8aea6f0ae0c324a738362198f10)

A Meteor package for filtering grits transportation data and displaying on
a Leaflet map.  See the [wiki](https://github.com/ecohealthalliance/grits-net-meteor/wiki) for the API documentation

# An example Meteor application

The following instructions provide an example of how to use the grits-net-meteor package.

## Install
1. Setup a meteor app, change dir, and remove starter files

  ```
  meteor create grits-net-wrapper
  cd grits-net-wrapper/
  rm grits-net-wrapper.*
  ```

2. Create packages folder and change dir

  ```
  mkdir packages
  cd packages/
  ```

3. Clone 'grits-net-meteor' and 'grits-net-mapper'

  ```
  git clone git@github.com:ecohealthalliance/grits-net-meteor.git
  git clone git@github.com:ecohealthalliance/grits-net-mapper.git
  ```

4. Add/remove packages

  ```
  meteor remove autopublish
  meteor add grits:grits-net-meteor
  meteor add grits:grits-net-mapper
  meteor add coffeescript
  ```

5. Setup MONGO_URL environment variable

  ```
  cd ../
  export MONGO_URL=mongodb://localhost/grits
  ```

6. Create grits-net-example/example.html

  ```
  <head>
    <title></title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  </head>
  <body>
    	{{> gritsMap }}
  </body>
  ```

7. Create grits-net-example/example.coffee

  ```
  if Meteor.isClient
    Template.gritsMap.onRendered ->
      self = Template.instance()
      self.autorun ->
        # wait for grits-net-meteor to be ready
        isReady = Session.get('grits-net-meteor:isReady')
        if isReady

          # Define the base layers for the map
          OpenStreetMap = L.tileLayer('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            layerName: 'CartoDB_Positron'
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="http://cartodb.com/attributions">CartoDB</a>'
            subdomains: 'abcd'
            maxZoom: 19)
          MapQuestOpen_OSM = L.tileLayer('http://otile{s}.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.{ext}',
            type: 'map'
            layerName: 'MapQuestOpen_OSM'
            ext: 'jpg'
            subdomains: '1234')
          Esri_WorldImagery = L.tileLayer('http://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            layerName: 'Esri_WorldImagery')
          baseLayers = [OpenStreetMap, Esri_WorldImagery, MapQuestOpen_OSM]

          # The DOM id of the map element (defined in grits-net-meteor/template/grits_map.html)
          element = 'grits-map'

          # The current window height
          height = window.innerHeight

          # Options to pass to GritsMap instance
          options = {
            height: height
            zoomControl: false
            noWrap: true
            maxZoom: 18
            minZoom: 0
            zoom: 2
            center: L.latLng(30,-20)
            layers: baseLayers
          }

          # Create the map instance
          map = new GritsMap(element, options, baseLayers)

          # (Required) Add layers to the map
          map.addGritsLayer(new GritsHeatmapLayer(map))
          map.addGritsLayer(new GritsPathLayer(map))
          map.addGritsLayer(new GritsNodeLayer(map))

          # Add the default controls to the map.
          Template.gritsMap.addDefaultControls(map)

          # (Required) Sets reference to the map instance
          Template.gritsMap.setInstance(map)
          return
      return
  ```

## Run Meteor

  ```
  meteor
  ```

## Run docker
 1. (Optional) Set up a Mongo container

  ``` docker run --name mongo -d mongo ```

 2. Run the following Docker command, making substitutions to the environmental variables as needed:

 ``` docker run -e MONGO_URL='mongodb://mongo:27017/test' -e ROOT_URL='http://localhost' -e PORT=8080 --link mongo:mongo -d -p 8080:8080 grits/grits-net-meteor ```

## Generate Documentation

 1. From the grits-net-meteor root directory:

  ```
  codo
  ```

 2. Open grits-net-meteor/doc/index.html

## NOTE:

*MongoDB will need to be populated by the grits-net-consume script.  Please view the [README.md](https://github.com/ecohealthalliance/grits-net-consume/blob/master/README.md)*


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
