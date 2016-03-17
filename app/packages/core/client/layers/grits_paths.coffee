_previousPath = new ReactiveVar(null) # placeholder for a previously selected path

_eventHandlers = {
  mouseout: (element, selection, projection) ->
    if not Session.get(GritsConstants.SESSION_KEY_IS_UPDATING)
      previousPath = _previousPath.get()
      if previousPath isnt null
        if element is previousPath
          d3.select(element).style("cursor": "pointer")
          return
      if @clicked
        # do not remove the blue highlight
        d3.select(element).style("cursor": "pointer")
      else
        d3.select(element).style('stroke', @color).style("cursor": "pointer")
  mouseover: (element, selection, projection) ->
    if not Session.get(GritsConstants.SESSION_KEY_IS_UPDATING)
      previousPath = _previousPath.get()
      if previousPath isnt null
        if element is previousPath
          d3.select(element).style("cursor": "pointer")
          return
      if @clicked
        # do not remove the blue highlight
        d3.select(element).style("cursor": "pointer")
      else
        d3.select(element).style('stroke', 'black').style("cursor": "pointer")
  click: (element, selection, projection) ->
    self = this
    if not Session.get(GritsConstants.SESSION_KEY_IS_UPDATING)
      # attach the svg dom element to the GritsPath model
      self.element = element
      self.clicked = true
      # get any previously selected path
      previousPath = _previousPath.get()
      if previousPath == self
        d3.select(element).style('stroke', previousPath.color)
        self.clicked = false
        _previousPath.set(null)
        return
      if !_.isNull(previousPath)
        d3.select(previousPath.element).style('stroke', previousPath.color)
        previousPath.clicked = false
      # update the dataTable
      Template.gritsDataTable.highlightPathTableRow(this)
      # temporarily set the path color to blue
      d3.select(element).style('stroke', 'rgba(53, 185, 118, 1)')
      # set the _previousPath to this gritsPath
      _previousPath.set(this)
}
# custom color scale for each path
_colorScale =
  10: '#94BAFB'
  20: '#9FAFEA'
  30: '#ABA5D9'
  40: '#B79BC8'
  50: '#C390B7'
  60: '#CE86A6'
  70: '#DA7C95'
  80: '#E67184'
  90: '#F26773'
  100: '#FE5D62'

# Creates an instance of a GritsNodeLayer, extends  GritsLayer
#
# @param [Object] map, an instance of GritsMap
# @param [String] displayName, the displayName for the layer selector
class GritsPathLayer extends GritsLayer
  constructor: (map, displayName) ->
    GritsLayer.call(this) # invoke super constructor
    self = this
    if typeof map == 'undefined'
      throw new Error('A layer requires a map to be defined')
      return
    if !map instanceof GritsMap
      throw new Error('A layer requires a valid map instance')
      return
    if typeof displayName == 'undefined'
      self._displayName = 'Paths'
    else
      self._displayName = displayName

    self._name = 'Paths'
    self._map = map

    self._layer = L.d3SvgOverlay(_.bind(self._drawCallback, this), {})

    self._prefixDOMID = 'path-'

    self.hasLoaded = new ReactiveVar(false)
    # stores the current visible paths based on the slider filter
    self.visiblePaths = new ReactiveVar([])
    self.min = new ReactiveVar(0)
    self.max = new ReactiveVar(100)
    self.trackMinMaxThroughput()

    self.currentPath = _previousPath

    self._bindMapEvents()
    return

  # clears the layer
  #
  # @override
  clear: ->
    self = this
    self._data = {}
    self._normalizedCI = 1
    #self._removeLayerGroup()
    #self._addLayerGroup()
    self.hasLoaded.set(false)

  # draws the layer
  #
  # @override
  draw: ->
    self = this
    self._map.removeLayer(self._layer)
    self._map.addLayer(self._layer)
    self._layer.draw()
    # set visiblePaths to the current paths on every draw so that current slider
    # inputs are applied.
    min = self.min.get()
    max = self.max.get()
    self.visiblePaths.set(self.filterMinMaxThroughput(min, max))
    return

  ###
  # removes the layer
  #
  remove: ->
    self = this
    self._removeLayerGroup()

  # adds the layer
  #
  add: ->
    self = this
    self._addLayerGroup()

  # removes the layerGroup from the map
  #
  # @override
  _removeLayerGroup: ->
    self = this
    if !(typeof self._layerGroup == 'undefined' or self._layerGroup == null)
      self._map.removeLayer(self._layerGroup)
    return

  # adds the layer group to the map
  #
  # @override
  _addLayerGroup: ->
    self = this
    self._layerGroup = L.layerGroup([self._layer])
    self._map.addOverlayControl(self._displayName, self._layerGroup)
    self._map.addLayer(self._layerGroup)
    return
  ###

  # gets the paths from the layer
  #
  # @return [Array] array of nodes
  getPaths: ->
    self = this
    return _.values(self._data)

  # gets the element ID within the DOM of a path
  #
  # @param [Object] gritsPath
  # @return [String] elementID
  getElementID: (obj) ->
    self = this
    return self._prefixDOMID + obj._id

  # The D3 callback that renders the svg elements on the map
  #
  # @see https://github.com/mbostock/d3/wiki/API-Reference
  # @see https://github.com/mbostock/d3/wiki/Selections
  # @param [Object] selection, teh array of elements pulled from the current document, also includes helper methods for filtering similar to jQuery
  # @param [Object] projection, the current scale
  _drawCallback: (selection, projection) ->
    self = this
    arrowhead = d3.select("#arrowhead")
    if typeof arrowhead == 'undefined' or arrowhead[0][0] is null
      svg = d3.select("svg")
      defs = svg.append('defs')
      defs.append('marker').attr(
        'id': 'arrowhead'
        'viewBox': '0 -2 10 10'
        'refX': 5
        'refY': 0
        'opacity': .5
        'markerWidth': 2
        'markerHeight': 3
        'orient': 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('class', 'arrowHead')

    paths = _.sortBy(self.getPaths(), (path) ->
      return path.throughput
    )

    pathCount = paths.length
    if pathCount <= 0
      return

    # since the map may be updated asynchronously the sums of the throughput
    # counters must be calcuated on every draw and the self._normalizedCI set
    sums = _.map(paths, (path) ->
      path.throughput
    )
    self._normalizedCI = _.max(sums)



    lines = selection.selectAll('path').data(paths, (path) -> path._id)
    #work on existing nodes
    lines
      .attr('stroke-width', (path) ->
        self._getWeight(path)
        return 3 / projection.scale
      ).attr("stroke", (path) ->
        if path.clicked
          return '#EEA66C'
        path.color = self._getNormalizedColor(path)
        return path.color
      )
      .attr('stroke-opacity', .8)
      .attr("marker-mid": "url(#arrowhead)")

    lines.enter().append('path')
      .attr('d', (path) ->
        d = []
        d[0] = {}
        d[0].x = projection.latLngToLayerPoint(path.origin.latLng).x
        d[0].y = projection.latLngToLayerPoint(path.origin.latLng).y

        d[1] = {}
        d[1].x = projection.latLngToLayerPoint(path.midPoint).x
        d[1].y = projection.latLngToLayerPoint(path.midPoint).y

        d[2] = {}
        d[2].x = projection.latLngToLayerPoint(path.destination.latLng).x
        d[2].y = projection.latLngToLayerPoint(path.destination.latLng).y

        newLineFunction = d3.svg.line().x((d) -> d.x).y((d) -> d.y).interpolate('basis')
        newLine = newLineFunction(d)
        return newLine
      ).attr('stroke-width', (path) ->
        self._getWeight(path)
        return 3 / projection.scale
      ).attr("stroke", (path) ->
        if path.clicked
          return '#EEA66C'
        path.color = self._getNormalizedColor(path)
        return path.color
      )
      .attr('stroke-opacity', .8)
      .attr('fill', "none")
      .attr('id', (path) ->
        path.elementID = self.getElementID(path)
        return path.elementID
      )
      .attr("marker-mid": "url(#arrowhead)")
      .on('mouseover', (path) ->
        path.eventHandlers.mouseover(this, selection, projection)
        return
      ).on('mouseout', (path) ->
        path.eventHandlers.mouseout(this, selection, projection)
        return
      ).on('click', (path) ->
        path.eventHandlers.click(this, selection, projection)
        return
      )
    lines.exit()
    return

  # returns the path's weight based on normalized throughput.  The weight is a
  # scale from 2 to 12.0
  #
  # @return [Number] weight
  _getWeight: (path) ->
    self = this
    weight = (self._getNormalizedThroughput(path) / 10) + 2
    path.weight = +(weight).toFixed(2)
    return path.weight

  # returns normalized hex color code for a path
  #
  # @return [String] normalizedColor, a hex string
  _getNormalizedColor: (path) ->
    self = this
    np = self._getNormalizedThroughput(path)
    if np < 10
      path.color = _colorScale[10]
    else if np < 20
      path.color = _colorScale[20]
    else if np < 30
      path.color = _colorScale[30]
    else if np < 40
      path.color = _colorScale[40]
    else if np < 50
      path.color = _colorScale[50]
    else if np < 60
      path.color = _colorScale[60]
    else if np < 70
      path.color = _colorScale[70]
    else if np < 80
      path.color = _colorScale[80]
    else if np < 90
      path.color = _colorScale[90]
    else if np <= 100
      path.color = _colorScale[100]
    else
      path.color = _colorScale[10]
    return path.color

  # converts domain specific flight data into generic GritsNode nodes
  #
  # @param [Object] flight, an Astronomy class 'Flight' represending a single record from a MongoDB collection
  convertFlight: (flight, level, origin, destination) ->
    self = this
    if typeof flight == 'undefined' or flight == null
      return
    if typeof level == 'undefined'
      level = 0
    _id = CryptoJS.MD5(origin._id + destination._id).toString()
    path = self._data[_id]
    if (typeof path == 'undefined' or path == null)
      try
        path = new GritsPath(flight, flight.totalSeats, level, origin, destination)
        path.setEventHandlers(_eventHandlers)
        self._data[path._id] = path
      catch e
        console.error(e.message)
        return
    else
      path.level = level
      path.occurrences += 1
      path.throughput += (flight.totalSeats * flight.weeklyFrequency)
    return

  convertItineraries: (itinerary, origin, destination) ->
    self = this
    _id = CryptoJS.MD5(origin._id + destination._id).toString()
    itinerary['_id'] = _id
    path = self._data[_id]
    if (typeof path == 'undefined' or path == null)
      try
        path = new GritsPath(itinerary, 0, 0, origin, destination)
        path.setEventHandlers(_eventHandlers)
        self._data[path._id] = path
      catch e
        console.error(e.message)
        return
    else
      path.occurrences += 1
      path.throughput += 1
    return

  # returns the normalized throughput for a node
  #
  # @return [Number] normalizedThroughput, 0 >= n <= 100
  _getNormalizedThroughput: (path) ->
    self = this
    maxAllowed = 100
    r = 0
    if self._normalizedCI > 0
      r = (path.throughput / self._normalizedCI ) * 100
    if r > maxAllowed
      return maxAllowed
    path.normalizedPercent = +(r).toFixed(0)
    return path.normalizedPercent

  # returns the visible paths based on min,max values
  #
  # @param [Integer] min, the minimum value
  # @param [Integer] max, the maximum value
  # @return [Array] visible, the visible paths
  filterMinMaxThroughput: (min, max) ->
    self = this
    paths = self.getPaths()
    if _.isEmpty(paths)
      return
    visible = _.filter(paths, (path) ->
      $element = $('#' + path.elementID)
      np = self._getNormalizedThroughput(path)
      if (np < min) || (np > max)
        $element.attr('display', 'none')
        path.visible = false
      else
        $element.attr('display', '')
        path.visible = true
        p = path
      if p
        return p
    )
    return visible

  # tracks min,max set by the UI slider
  trackMinMaxThroughput: ->
    self = this
    Meteor.autorun ->
      min = self.min.get()
      max = self.max.get()
      self.visiblePaths.set(self.filterMinMaxThroughput(min, max))
    return

  # binds to the Tracker.gritsMap.getInstance() map event listener .on
  # 'overlyadd' and 'overlayremove' methods
  _bindMapEvents: ->
    self = this
    if typeof self._map == 'undefined'
      return
    self._map.on(
      overlayadd: (e) ->
        if e.name == self._displayName
          if Meteor.gritsUtil.debug
            console.log("#{self._displayName} layer was added")
      overlayremove: (e) ->
        if e.name == self._displayName
          if Meteor.gritsUtil.debug
            console.log("#{self._displayName} layer was removed")
    )

# Static reference to the colorScale
GritsPathLayer.colorScale = _colorScale
