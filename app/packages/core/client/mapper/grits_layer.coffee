# Creates an instance of a GritsLayer.  GritsLayer contains reference to a
# leaflet layer and leaflet group.
class GritsLayer
  constructor: ->
    @_name = 'Layer'
    @_data = {}

    @_map = null
    @_layer = null
    @_layerGroup = null
    @_normalizedCI = 1
    return

  # removes the layerGroup from the map
  _removeLayerGroup: ->
    if !(typeof @_layerGroup == 'undefined' or @_layerGroup == null)
      @_map.removeLayer(@_layerGroup)
    @_layerGroup = null
    return

  # adds the layerGroup to the map
  _addLayerGroup: ->
    @_layerGroup = L.layerGroup([@_layer])
    @_map.addOverlayControl(@_name, @_layerGroup)
    @_map.addLayer(@_layerGroup)
    return

  # draws the layer
  draw: ->
    @_layer.draw()
    return

  # clears the data redraws the layer
  clear: ->
    @_data = {}
    @_removeLayerGroup()
    @_addLayerGroup()
