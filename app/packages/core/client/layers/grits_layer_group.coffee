_previousLayerGroup = null
# currently GritsLayerGroup acts as a wrapper to L.layerGroup
class GritsLayerGroup #extends L.layerGroup
  constructor: (layers, map, id, label) ->
    self = this
    validStr = new RegExp(/^[A-Za-z0-9_.]+$/)

    if typeof layers == 'undefined'
      throw new Error('GritsLayerGroup requires an Object of GritsLayers to be defined')
    if !layers.constructor == Object
      throw new Error('GritsLayerGroup requires a valid Object instance')
    if Object.keys(layers).length == 0
      throw new Error('GritsLayerGroup must have one or more keys')

    if typeof map == 'undefined'
      throw new Error('GritsLayerGroup requires a map to be defined')
    if !map instanceof GritsMap
      throw new Error('GritsLayerGroup requires a valid map instance')

    if typeof id == 'undefined'
      throw new Error('GritsLayerGroup requires an Id to be defined')
    if validStr.test(id) == false
      throw new Error('GritsLayerGroup requires the string Id to consist of [A-Za-z0-9_] characters')

    if typeof label == 'undefined' || typeof label != 'string'
      throw new Error('GritsLayerGroup requires the string label to be defined')

    self._layers = {}
    for own key, value of layers
      if validStr.test(key) == false
        throw new Error('Layers Object requires the key name to consist of [A-Za-z0-9_] characters')
      if !value instanceof GritsLayer
        throw new Error('Layers Object must have GritsLayer instance for values')
      if self._layers.hasOwnProperty(key)
        throw new Error("Layers Object with #{key} already exists")
      self._layers[key] = value

    self._map = map
    self._id = id # the unique string that identifies this layerGroup
    self._label = label # the label shown on the leaflet layer controls

    # _layerGroup is initialized to null then created in the add() method
    self._layerGroup = null

  # removes the layerGroup from the map
  remove: ->
    self = this
    if !(typeof self._layerGroup == 'undefined' or self._layerGroup == null)
      self._map.removeLayer(self._layerGroup)
    return

  # adds the layer group to the map
  add: ->
    self = this
    self._layerGroup = L.layerGroup(self._all())
    self._map.addOverlayControl(self._label, self._layerGroup)
    self._map.addLayer(self._layerGroup)
    return

  # clears the child layeers, then removes then adds the layer group
  reset: ->
    self = this
    Object.keys(self._layers).map((key) -> self._layers[key].clear())
    self.remove()
    self.add()
    return

  getNodeLayer: ->
    self = this
    return self._layers[GritsConstants.NODE_LAYER_ID]

  getPathLayer: ->
    self = this
    return self._layers[GritsConstants.PATH_LAYER_ID]

  getHeatmapLayer: ->
    self = this
    return self._layers[GritsConstants.HEATMAP_LAYER_ID]

  convertFlight: (flight, level, originTokens) ->
    self = this
    nodeLayer = self._layers[GritsConstants.NODE_LAYER_ID]
    pathLayer = self._layers[GritsConstants.PATH_LAYER_ID]
    nodes = nodeLayer.convertFlight(flight, level, originTokens)
    # convertFlight may return null in the case of a metaNode
    # which signifies that the node is contained within the bounding
    # box, so do not draw a path
    if (nodes[0] == null || nodes[1] == null)
      return
    pathLayer.convertFlight(flight, level, nodes[0], nodes[1])
    return

  convertItineraries: (fields, originToken) ->
    self = this
    nodeLayer = self._layers[GritsConstants.NODE_LAYER_ID]
    pathLayer = self._layers[GritsConstants.PATH_LAYER_ID]
    nodes = nodeLayer.convertItineraries(fields, originToken)
    # convertFlight may return null in the case of a metaNode
    # which signifies that the node is contained within the bounding
    # box, so do not draw a path
    if nodes[0] == null || nodes[1] == null
      return
    pathLayer.convertItineraries(fields, nodes[0], nodes[1])
    return

  updateLocations: (dateKey) ->
    self = this
    heatmapLayer = self._layers[GritsConstants.HEATMAP_LAYER_ID]
    heatmapLayer.updateLocations(dateKey)
    return

  draw: ->
    self = this
    Object.keys(self._layers).map((key) ->
      layer = self._layers[key]
      if typeof layer.draw == 'function'
        layer.draw()
    )
    return

  finish: ->
    self = this
    self.draw()
    Object.keys(self._layers).map((key) ->
      layer = self._layers[key]
      if typeof layer.hasLoaded == 'function'
        layer.hasLoaded.set(true)
    )
    return

  # @return [Array] array of all the layers in this group
  _all: ->
    self = this
    return Object.keys(self._layers).map((key) -> self._layers[key]._layer)

  # finds a layer by its given id or null
  #
  # @param [String] id, the string Id of the layer
  find: (id) ->
    self = this
    if self._layers.hasOwnProperty(id)
      return self._layers[id]
    return null

_resetPreviousLayer = (newLayerGroup) ->
  if _previousLayerGroup != null
    if _previousLayerGroup._id != newLayerGroup._id
      _previousLayerGroup.reset()
  _previousLayerGroup = newLayerGroup
  return

GritsLayerGroup.getCurrentLayerGroup = ->
  layerGroup = null
  map = Template.gritsMap.getInstance()
  mode = Session.get(GritsConstants.SESSION_KEY_MODE)
  if mode == GritsConstants.MODE_ANALYZE
    layerGroup = map.getGritsLayerGroup(GritsConstants.ANALYZE_GROUP_LAYER_ID)
  else if mode == GritsConstants.MODE_EXPLORE
    layerGroup = map.getGritsLayerGroup(GritsConstants.EXPLORE_GROUP_LAYER_ID)
  else
    console.error("Invalid Map Mode '#{mode}'")
  _resetPreviousLayer(layerGroup)
  return layerGroup
