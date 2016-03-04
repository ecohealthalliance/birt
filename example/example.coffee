if Meteor.isClient
  Template.gritsMap.onRendered ->
    self = Template.instance()
    self.autorun ->
      isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
      if isReady
        OpenStreetMap = L.tileLayer('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          layerName: 'CartoDB_Positron'
          noWrap: true
          attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="http://cartodb.com/attributions">CartoDB</a>'
          subdomains: 'abcd'
          maxZoom: 19)
        MapQuestOpen_OSM = L.tileLayer('http://otile{s}.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.{ext}',
          type: 'map'
          layerName: 'MapQuestOpen_OSM'
          noWrap: true
          ext: 'jpg'
          subdomains: '1234')
        Esri_WorldImagery = L.tileLayer('http://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          layerName: 'Esri_WorldImagery'
          noWrap: true)

        baseLayers = [OpenStreetMap, Esri_WorldImagery, MapQuestOpen_OSM]
        element = 'grits-map'
        height = window.innerHeight
        options = {
          height: height
          zoomControl: false
          noWrap: true
          maxZoom: 18
          # min zoom is limited and hard bounds are set because the heatmap
          # will start shifting when the map is panned beyond it's top bound.
          minZoom: 2
          maxBounds: L.latLngBounds(L.latLng(-360, -360), L.latLng(360, 360))
          maxBoundsViscosity: 1.0
          zoom: 3
          center: L.latLng(35, -125)
          layers: baseLayers
        }

        # the map instance
        map = new GritsMap(element, options, baseLayers)

        # Add the default controls to the map.
        Template.gritsMap.addDefaultControls(map)

        # initialize the sidebar-v2
        L.control.sidebar('sidebar').addTo(map)
        L.control.sidebar('tableSidebar').addTo(map)

        # Add test control
        Meteor.call('isTestEnvironment', (err, result) ->
          if err
            return
          if result
            map.addControl(new GritsControl('<b> Select a Module </b><div id="moduleSelectorDiv"></div>', 7, 'topright', 'info'))
            Blaze.render(Template.moduleSelector, $('#moduleSelectorDiv')[0])
        )

        Template.gritsMap.setInstance(map)
        return
    return
