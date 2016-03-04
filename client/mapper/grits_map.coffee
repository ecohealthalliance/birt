_imagePath = 'packages/bevanhunt_leaflet/images'
# Creates an instance of a map
#
# @param [String]
# @param [Object] options, Leaflet map options + height
# @see http://leafletjs.com/reference.html#map-options
class GritsMap extends L.Map
  constructor: (element, options) ->
    @_name = 'GritsMap'
    @_element = element or 'grits-map'

    @_gritsOverlayControl = null
    @_gritsOverlays = {}
    @_gritsTileLayers = {}
    @_gritsLayers = {}

    L.Icon.Default.imagePath = _imagePath

    OpenStreetMap = L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      key: '1234'
      layerName: 'OpenStreetMap'
      styleId: 22677)

    if typeof options == 'undefined'
      @_options = {
        center: [37.8, -92]
        zoomControl: false
        noWrap: true
        maxZoom: 18
        minZoom: 0
        layers: [OpenStreetMap]
      }
    else
      @_options = options

    if typeof @_options.layers == 'undefined'
      @_options.layers = [OpenStreetMap]

    for layer in @_options.layers
      @_gritsTileLayers[layer.options.layerName] = layer

    @_options.layers = [@_options.layers[0]]
    super(@_element, @_options)

    @_drawOverlayControls()
    @_createDefaultLayerGroups()
    return

  # creates the default layer groups required by the map
  _createDefaultLayerGroups: () ->
    self = this
    # Add analyze layers to a layer group then store to map
    analyzeLayers = {}
    analyzeLayers[GritsConstants.NODE_LAYER_ID] = new GritsNodeLayer(self, GritsConstants.NODE_LAYER_ID)
    analyzeLayers[GritsConstants.PATH_LAYER_ID] = new GritsPathLayer(self, GritsConstants.PATH_LAYER_ID)
    analyzeLayerGroup = new GritsLayerGroup(analyzeLayers, self, GritsConstants.ANALYZE_GROUP_LAYER_ID, 'Analyze')
    analyzeLayerGroup.add()
    self.addGritsLayerGroup(analyzeLayerGroup)

    # Add explore layers to a layer group then store to map
    exploreLayers = {}
    exploreLayers[GritsConstants.NODE_LAYER_ID] = new GritsNodeLayer(self, GritsConstants.NODE_LAYER_ID)
    exploreLayers[GritsConstants.PATH_LAYER_ID] = new GritsPathLayer(self, GritsConstants.PATH_LAYER_ID)
    exploreLayerGroup = new GritsLayerGroup(exploreLayers, self, GritsConstants.EXPLORE_GROUP_LAYER_ID, 'Explore')
    exploreLayerGroup.add()
    self.addGritsLayerGroup(exploreLayerGroup)

    # Add heatmap layer to a layer group then store to map
    heatmapLayers = {}
    heatmapLayers[GritsConstants.HEATMAP_LAYER_ID] = new GritsHeatmapLayer(self, GritsConstants.HEATMAP_LAYER_ID)
    heatmapLayerGroup = new GritsLayerGroup(heatmapLayers, self, GritsConstants.HEATMAP_GROUP_LAYER_ID, 'Heatmap')
    self.addGritsLayerGroup(heatmapLayerGroup)

    # Add all nodes layers to a layer group then add to map
    allNodesLayers = {}
    allNodesLayers[GritsConstants.NODE_LAYER_ID] = new GritsAllNodesLayer(self)
    allNodesLayerGroup = new GritsLayerGroup(allNodesLayers, self, GritsConstants.ALL_NODES_GROUP_LAYER_ID, 'All Nodes')
    self.addGritsLayerGroup(allNodesLayerGroup)

  # adds a layer reference to the map object
  #
  # @note This does not add the layer to the Leaflet map.  Its just a container
  # @param [Object] layer, a GritsLayer instance
  addGritsLayerGroup: (layerGroup) ->
    if typeof layerGroup == 'undefined'
      throw new Error('A layer must be defined')
      return
    if !layerGroup instanceof GritsLayerGroup
      throw new Error('A map requires a valid GritsLayerGroup instance')
      return
    @_layers[layerGroup._id] = layerGroup
    return

  # gets a layer refreence from the map object
  #
  # @param [String] id, a string containing the name of the layer as shown
  #  in the UI layer controls
  getGritsLayerGroup: (id) ->
    if typeof id == 'undefined'
      throw new Error('A GritsLayerGroup Id must be defined')
      return
    if @_layers.hasOwnProperty(id) == true
      return @_layers[id]
    return null

  # draws the overlay controls within the control box in the upper-right
  # corner of the map.  It uses @_gritsOverlayControl to place the reference of
  # the overlay controls.
  _drawOverlayControls: () ->
    if @_gritsOverlayControl == null
      @_gritsOverlayControl = L.control.layers(@_gritsTileLayers, @_gritsOverlays).addTo this
    else
      @_gritsOverlayControl.removeFrom(this)
      @_gritsOverlayControl = L.control.layers(@_gritsTileLayers, @_gritsOverlays).addTo this
    return

  # adds a new overlay control to the map
  #
  # @param [String] layerName, string containing the name of the layer
  # @param [Object] layerGroup, the layerGroup object to add to the map controls
  addOverlayControl: (layerName, layerGroup) ->
    @_gritsOverlays[layerName] = layerGroup
    @_drawOverlayControls()
    window.dispatchEvent(new Event('mapper.addOverlayControl'))
    return

  # removes overlay control from the map
  #
  # @param [String] layerName, string containing the name of the layer
  removeOverlayControl: (layerName) ->
    if @_gritsOverlays.hasOwnProperty layerName
      delete @_gritsOverlays[layerName]
      @_drawOverlayControls()
    return
