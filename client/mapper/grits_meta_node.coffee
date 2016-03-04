_nextNum = 1
# container to store metanodes
_metaNodes = {}
# used to calculate what the width/height of the label with be prior
# to inserting into the DOM
_canvas = null

# Creates an instance of a GritsMetaNode
#
# @param [Array] nodes, a list of GritsNodes to create the GritsMetaNode
# @param [Object] marker, (optional) a GritsMarker instance
# @param [Object] options, (optional) options for creating the SVG rectangle
class GritsMetaNode extends GritsNode
  constructor: (nodes, obj, marker, options) ->
    GritsNode.call(this, obj, marker)
    self = this

    if typeof nodes == 'undefined'
      throw new Error('A GritsMetaNode requires an array of GritsNodes to be defined')
    if !nodes instanceof Array
      throw new Error('A GritsMetaNode requires a valid array of GritsNodes')
    self._children = nodes

    if obj.hasOwnProperty('bounds') == false
      throw new Error('A GritsMetaNode requires the "obj.bounds" property')
      return
    self.bounds = obj.bounds

    self.name = 'GritsMetaNode'

    if typeof options != 'undefined'
      self._options = options
    else
      self._options =
        box:
          'stroke': '#333'
          'stroke-width': 2
          'stroke-opacity': 0.75
          'fill': '#333'
          'fill-opacity': 0.35
        label:
          fontSize: 8

    self.fontSize = self._options.label.fontSize
    self.labelMetrics = self.getTextMetrics(self._children.length+'')
    self._id = GritsMetaNode.PREFIX + _nextNum
    _nextNum += 1
    _metaNodes[self._id] = self
    return
  # Uses canvas.measureText to compute and return the width of the given text of given font in pixels.
  #
  # @param [String] text The text to be rendered.
  # @param [String] font The css font descriptor that text is to be rendered with (e.g. "bold 14px verdana").
  # @return [Object] object containing keys 'height' and 'width'
  # @see http://stackoverflow.com/questions/118241/calculate-text-width-with-javascript/21015393#21015393
  getTextMetrics: (text) ->
    self = this
    font = 'bold ' + self.fontSize + 'pt'
    # re-use canvas object for better performance
    if (_canvas == null)
      _canvas = document.createElement('canvas')
    context = _canvas.getContext('2d');
    context.font = font;
    metrics = context.measureText(text);
    return {height: self.fontSize, width: metrics.width}
  getBoxStyle: () ->
    self = this
    props = []
    style = ''
    if self._options.hasOwnProperty('box')
      properties = self._options.box
      Object.keys(properties).forEach((key) ->
        value = properties[key]
        props.push(key + ':' + value)
      )
    if props.length > 0
      style = props.join(';')
    return style
  getAirportIds: ()->
    _.pluck @_children, '_id'
GritsMetaNode.PREFIX = 'META-'
# find a metanode
#
# @param [String] id, the metanode id
# @return [Object] metaNode, instance of a GritsMetaNode or null
GritsMetaNode.find = (id) ->
  if _metaNodes.hasOwnProperty(id)
    return _metaNodes[id]
  else
    return null
# resets the set of metanodes
GritsMetaNode.reset = () ->
  _metaNodes = {}
  return

# factory method for creating an instance of GritsMetaNode
GritsMetaNode.create = (nodes) ->
  # metaNodeData, an object containing information about the metaNode.  At a
  # minimum '_id' and geoJSON loc.coordinates are requried.
  metaNodeData =
    _id: null
    loc:
      coordinates: [null, null]
    bounds: null
    name: 'MetaNode'
  # static method to get the bounds of the metaNode prior to creating
  metaNodeBounds = GritsMetaNode.findBounds(nodes)
  if metaNodeBounds != null
    metaNodeCenter = metaNodeBounds.getCenter()
    metaNodeData.loc.coordinates[0] = metaNodeCenter.lng
    metaNodeData.loc.coordinates[1] = metaNodeCenter.lat
    metaNodeData.bounds = metaNodeBounds
  # create the instance or catch the error
  try
    marker = new GritsMarker(28, 28, GritsNodeLayer.colorScale)
    metaNode = new GritsMetaNode(nodes, metaNodeData, marker)
  catch e
    metaNode = {error: true, message: e.message}
  return metaNode

# calculates the latLng center of a group of GritsNodes
#
# @note This is not the center of the bounds, but of the nodes
# @param [Array] nodes, list of GritsNodes
# @return [Array] latLng, an array with coordinates or null
GritsMetaNode.findCenter = (nodes) ->
  # find center and add throughput
  latMinMax = [90,-90]
  lngMinMax = [180,-180]
  for node in nodes
    if !node instanceof GritsNode
      throw new Error('A GritsMetaNode requires an array of GritsNodes')
    lat = node.latLng[0]
    if !(typeof lat == 'undefined' || lat == null || isNaN(parseFloat(lat)) || (lat < -90.0 || lat > 90.0))
      if lat < latMinMax[0]
        latMinMax[0] = lat
      if lat > latMinMax[1]
        latMinMax[1] = lat
    lng = node.latLng[1]
    if !(typeof lng == 'undefined' || lng == null || isNaN(parseFloat(lng)) || (lng < -180.0 || lng > 180.0))
      if lng < lngMinMax[0]
        lngMinMax[0] = lng
      if lng > lngMinMax[1]
        lngMinMax[1] = lng
  if (latMinMax == [90,-90] && lngMinMax == [180,-180])
    return null
  else
    return [(latMinMax[0] + latMinMax[1]) / 2, (lngMinMax[0] + lngMinMax[1]) / 2]

# calculate the topLeft and bottomRight coordinates from a list of GritsNodes
#
# @param [Array] nodes, list of GritsNodes
# @return [Object] bounds, a Leaflet latLngBounds object or null
# @see http://leafletjs.com/reference.html#latlngbounds
GritsMetaNode.findBounds = (nodes) ->
  topLeft = [null,null]
  bottomRight = [null,null]
  for node in nodes
    if !node instanceof GritsNode
      throw new Error('A GritsMetaNode requires an array of GritsNodes')
    lat = node.latLng[0]
    if !(typeof lat == 'undefined' || lat == null || isNaN(parseFloat(lat)) || (lat < -90.0 || lat > 90.0))
      if topLeft[0] == null
        topLeft[0] = lat
      else
        if lat > topLeft[0]
          topLeft[0] = lat
      if bottomRight[0] == null
        bottomRight[0] = lat
      else
        if lat < bottomRight[0]
          bottomRight[0] = lat
    lng = node.latLng[1]
    if !(typeof lng == 'undefined' || lng == null || isNaN(parseFloat(lng)) || (lng < -180.0 || lng > 180.0))
      if topLeft[1] == null
        topLeft[1] = lng
      else
        if lng < topLeft[1]
          topLeft[1] = lng
      if bottomRight[1] == null
        bottomRight[1] = lng
      else
        if lng > bottomRight[1]
          bottomRight[1] = lng
  if (_.indexOf(topLeft, null) >= 0 || _.indexOf(bottomRight, null) >= 0)
    return null
  else
    return new L.LatLngBounds(topLeft, bottomRight)
