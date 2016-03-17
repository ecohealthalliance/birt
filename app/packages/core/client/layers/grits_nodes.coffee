_previousNode = new ReactiveVar(null) # placeholder for a previously selected node
_eventHandlers = {
  mouseover: (element, selection, projection) ->
    if not Session.get(GritsConstants.SESSION_KEY_IS_UPDATING)
      _previousNode.set(this)
  click: (element, selection, projection) ->
    self = this
    if not Session.get(GritsConstants.SESSION_KEY_IS_UPDATING)
      departureSearch = Template.gritsSearch.getDepartureSearchMain()
      if typeof departureSearch != 'undefined'
        rawTokens =  departureSearch.tokenfield('getTokens')
        tokens = _.pluck(rawTokens, 'label')
        match = _.find(tokens, (t) -> t == self._id)
        if match
          # this token was already used in the query
          _previousNode.set(this)
          return
        else
          # erase any previous departures
          GritsFilterCriteria.setDepartures(null)
          # set the clicked element as the new origin
          departureSearchMain = Template.gritsSearch.getDepartureSearchMain()
          departureSearchMain.tokenfield('setTokens', [self._id])

          async.nextTick( ->
            # apply the filter
            GritsFilterCriteria.apply((err, res) ->
              if res
                map = Template.gritsMap.getInstance()
                layerGroup = GritsLayerGroup.getCurrentLayerGroup()
                if map.getZoom() > 2
                  # panto the map if we're at zoom level 3 or greater
                  map.panTo(self.latLng)
                else
                  # set the view to the latLng and zoom level to 2
                  map.setView(self.latLng, 2)
                # reset the current path
                layerGroup.getPathLayer().currentPath.set(null)
                # set previous/current node to self
                _previousNode.set(self)
            )
          )
    return
}
# custom color scale for each marker
_colorScale =
  10: '#D95F0E'
  20: '#DD6F21'
  30: '#E18034'
  40: '#E9A25B'
  50: '#E89B53'
  60: '#EEB36E'
  70: '#F2C482'
  80: '#F6D595'
  90: '#FAE6A8'
  100: '#FFF7BC'
# custom width scale for each marker
_widthScale =
  0: '7'
  1: '8'
  2: '9'
  3: '10'
  4: '11'
  5: '12'
  6: '13'
  7: '14'
  8: '15'
  9: '16'
# custom [width, height] size for each marker
_size = [7, 7]

# Creates an instance of a GritsNodeLayer, extends  GritsLayer
#
# @param [Object] map, an instance of GritsMap
# @param [String] displayName, the displayName for the layer selector
class GritsNodeLayer extends GritsLayer
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
      self._displayName = 'Nodes'
    else
      self._displayName = displayName

    self._name = 'Nodes'
    self._map = map

    self._layer = L.d3SvgOverlay(_.bind(self._drawCallback, this), {})

    self._prefixDOMID = 'node-'

    self.hasLoaded = new ReactiveVar(false)
    # stores the current visible nodes based on the slider filder
    self.visibleNodes = new ReactiveVar([])
    self.min = new ReactiveVar(0)
    self.max = new ReactiveVar(100)
    self.trackMinMaxThroughput()

    self.currentNode = _previousNode
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
    self._layer.draw()
    self._moveOriginsToTop()
    self._moveMetaNodeBoxesToBottom()
    # set visiblePaths to the current paths on every draw so that current slider
    # inputs are applied.
    min = self.min.get()
    max = self.max.get()
    self.visibleNodes.set(self.filterMinMaxThroughput(min, max))
    return

  # moves the origins to the top of the node layer
  _moveOriginsToTop: ->
    self = this
    originMarkers = $('.origin.marker-icon')
    _.each(originMarkers, (el) ->
      $g = $(el).closest('g')
      $(el).detach().appendTo($g)
    )
    metaNodeLabels = $('.origin.metanode-label')
    _.each(metaNodeLabels, (el) ->
      $g = $(el).closest('g')
      $(el).detach().appendTo($g)
    )
    return

  _moveMetaNodeBoxesToBottom: ->
    self = this
    metaNodeBoxes = $('.origin.metanode-bounding-box')
    _.each(metaNodeBoxes, (el) ->
      $g = $(el).closest('g')
      $(el).detach().prependTo($g)
    )

  # gets the nodes from the layer
  #
  # @return [Array] array of nodes
  getNodes: ->
    self = this
    return _.values(self._data)

  # gets the origins from the layer
  #
  # @return [Array] array of nodes
  getOrigins: ->
    self = this
    nodes = self.getNodes()
    origins = _.filter(nodes, (node) ->
      if node.hasOwnProperty('isOrigin')
        if node.isOrigin
          return node
    )
    return origins

  # gets the destinations from the layer
  #
  # @return [Array] array of nodes
  getDestinations: ->
    self = this
    nodes = self.getNodes()
    destinations = _.filter(nodes, (node) ->
      if !node.hasOwnProperty('isOrigin')
        return node
      else
        if !node.isOrigin
          return node
    )
    return destinations

  # gets the element ID within the DOM of a path
  #
  # @param [Object] obj, a gritsNode object
  # @return [String] elementID
  getElementID: (obj) ->
    self = this
    return self._prefixDOMID + obj._id

  # find a node by the latLng pair
  #
  # @param [Array] an array [lat,lng]
  # @return [Object] a GritsNode object
  findByLatLng: (latLng) ->
    self = this
    nodes = self.getNodes()
    node = _.find(nodes, (node) ->
      return _.isEqual(node.latLng, latLng)
    )
    if _.isUndefined(node)
      return null
    return node

  # The D3 callback that renders the svg elements on the map
  #
  # @see https://github.com/mbostock/d3/wiki/API-Reference
  # @see https://github.com/mbostock/d3/wiki/Selections
  # @param [Object] selection, the array of elements pulled from the current document, also includes helper methods for filtering similar to jQuery
  # @param [Object] projection, the current scale
  _drawCallback: (selection, projection) ->
    self = this
    self._destinationDrawCallback(selection, projection)
    self._originDrawCallback(selection, projection)
    return

  _destinationDrawCallback: (selection, projection) ->
    self = this
    if Session.keys['grits-net-meteor:mode'] is "\"ANALYZE\""
      return

    destinations = self.getDestinations()
    destinationCount = destinations.length
    if destinationCount <= 0
      return

    # since the map may be updated asynchronously the sums of the throughput
    # counters must be calcuated on every draw and the self._normalizedCI set
    # @note we only normalize the destinations.
    sums = _.map(destinations, (destination) ->
      destination.incomingThroughput + destination.outgoingThroughput
    )
    # store the max value to the layer
    self._normalizedCI = _.max(sums)

    # select any existing circles and store data onto elements
    destinationMarkers = selection.selectAll('.destination.marker-icon').data(destinations, (destination) ->
      destination._id
    )

    #work on existing nodes
    destinationMarkers
      .attr('cx', (node) ->
        return self._projectCX(projection, node)
      )
      .attr('cy', (node) ->
        return self._projectCY(projection, node)
      )
      .attr('r', (node) ->
        return (self._getNormalizedWidth(node)) / projection.scale
      )
      .attr('fill', (node) ->
        return self._getNormalizedColor(node)
      )
      .attr('fill-opacity', .8)
      .attr('stroke-width', (node) ->
        return (self._getNormalizedWidth(node)) / 6 / projection.scale
      )
      .attr("stroke", "white")
      .sort((a,b) ->
        return d3.descending(a.latLng[0], b.latLng[0])
      )

    # add new elements workflow (following https://github.com/mbostock/d3/wiki/Selections#enter )
    destinationMarkers.enter().append('circle')
      .attr('cx', (node) ->
        return self._projectCX(projection, node)
      )
      .attr('cy', (node) ->
        return self._projectCY(projection, node)
      )
      .attr('r', (node) ->
        return (self._getNormalizedWidth(node)) / projection.scale
      )
      .attr('fill', (node) ->
        return self._getNormalizedColor(node)
      )
      .attr('stroke-width', (node) ->
        return (self._getNormalizedWidth(node)) / 6 / projection.scale
      )
      .attr("stroke", "white")
      .attr('fill-opacity', .8)
      .attr('class', (node) ->
        return 'destination marker-icon'
      )
      .attr('id', (node) ->
        node.elementID = self.getElementID(node)
        return node.elementID
      )
      .sort((a,b) ->
        return d3.descending(a.latLng[0], b.latLng[0])
      )
      .on('click', (node) ->
        d3.event.stopPropagation();
        # manual trigger node click handler
        if node.hasOwnProperty('eventHandlers')
          if node.eventHandlers.hasOwnProperty('click')
            node.eventHandlers.click(this, selection, projection)
        return
      )
      .on('mouseover', (node) ->
        d3.event.stopPropagation();
        # manual trigger node mouseover handler
        if node.hasOwnProperty('eventHandlers')
          if node.eventHandlers.hasOwnProperty('mouseover')
            node.eventHandlers.mouseover(this, selection, projection)
        return
      )
    destinationMarkers.exit()
    return

  _originDrawCallback: (selection, projection) ->
    self = this

    origins = self.getOrigins()
    metaNodes = _.filter(origins, (origin) ->
      if origin instanceof GritsMetaNode
        return origin
    )
    # select any existing circles and store data onto elements
    originMarkers = selection.selectAll('.origin.marker-icon').data(origins, (node) ->
      return node._id
    )
    # select any existing metanode labels and store data onto elements
    metaNodeLabels = selection.selectAll('.origin.metanode-label').data(metaNodes, (node) ->
      return node._id
    )
    # select any existing metanode boxes and store data onto elements
    metaNodeBoxes = selection.selectAll('.origin.metanode-bounding-box').data(metaNodes, (node) ->
      return node._id
    )

    #work on existing origins (update projection)
    originMarkers
      .attr('x', (node) ->
        x = projection.latLngToLayerPoint(node.latLng).x
        return x - (self._getNormalizedWidth(node) / projection.scale)
      )
      .attr('y', (node) ->
        y = projection.latLngToLayerPoint(node.latLng).y
        return y - (node.marker.height / projection.scale)
      )
      .attr('width', (node) ->
        return (self._getNormalizedWidth(node) * 2) / projection.scale
      )
      .attr('height', (node) ->
        return (node.marker.height * 2) / projection.scale
      )
      .sort((a,b) ->
        return d3.descending(a.latLng[0], b.latLng[0])
      )

    #work on existing origins (update projection)
    metaNodeLabels
      .attr('x', (node) ->
        return self._projectTextX(projection, node)
      )
      .attr('y', (node) ->
        return self._projectTextY(projection, node)
      )
      .attr('dy', (node) ->
        if typeof node.fontSize != 'undefined'
          return (node.fontSize / projection.scale) + 'pt'
        else
          return '0pt'
      )
      .attr('font-size', (node) ->
        if typeof node.fontSize != 'undefined'
          return (node.fontSize / projection.scale) + 'pt'
        else
          return '0pt'
      )

    #work on existing boxes (update projection)
    metaNodeBoxes
      .attr('x', (node) ->
        return self._projectRectX(projection, node)
      )
      .attr('y', (node) ->
        return self._projectRectY(projection, node)
      )
      .attr('width', (node) ->
        return self._projectRectWidth(projection, node)
      )
      .attr('height', (node) ->
        return self._projectRectHeight(projection, node)
      )

    # add new elements workflow (following https://github.com/mbostock/d3/wiki/Selections#enter )
    originMarkers.enter().append('image')
      .attr('xlink:href', (node) ->
        href = self.getMarkerHref(node)
        return href
      )
      .attr('x', (node) ->
        x = projection.latLngToLayerPoint(node.latLng).x
        return x - (node.marker.width / projection.scale)
      )
      .attr('y', (node) ->
        y = projection.latLngToLayerPoint(node.latLng).y
        return y - (node.marker.height / projection.scale)
      )
      .attr('width', (node) ->
        return (node.marker.width * 2) / projection.scale
      )
      .attr('height', (node) ->
        return (node.marker.height * 2) / projection.scale
      )
      .attr('class', (node) ->
        return 'origin marker-icon'
      )
      .attr('id', (node) ->
        return self.getElementID(node)
      )
      .sort((a,b) ->
        return d3.descending(a.latLng[0], b.latLng[0])
      )
      .on('click', (node) ->
        d3.event.stopPropagation();
        # manual trigger node click handler
        if node.hasOwnProperty('eventHandlers')
          if node.eventHandlers.hasOwnProperty('click')
            node.eventHandlers.click(this, selection, projection)
        return
      )
      .on('mouseover', (node) ->
        d3.event.stopPropagation()
        # manual trigger node mouseover handler
        if node.hasOwnProperty('eventHandlers')
          if node.eventHandlers.hasOwnProperty('mouseover')
            node.eventHandlers.mouseover(this, selection, projection)
        return
      )
    originMarkers.exit()

    metaNodeLabels.enter().append('text')
      .attr('x', (node) ->
        return self._projectTextX(projection, node)
      )
      .attr('y', (node) ->
        return self._projectTextY(projection, node)
      )
      .attr('dy', (node) ->
        if typeof node.fontSize != 'undefined'
          return (node.fontSize / projection.scale) + 'pt'
        else
          return '0pt'
      )
      .attr('font-size', (node) ->
        if typeof node.fontSize != 'undefined'
          return (node.fontSize / projection.scale) + 'pt'
        else
          return '0pt'
      )
      .attr('font-weight', 'bold')
      .attr('class', (node) ->
        return 'origin metanode-label'
      )
      .text((node) ->
        if node instanceof GritsMetaNode
          return node._children.length
        else
          return node._id
      )
    metaNodeLabels.exit()

    metaNodeBoxes.enter().append('rect')
      .attr('x', (node) ->
        return self._projectRectX(projection, node)
      )
      .attr('y', (node) ->
        return self._projectRectY(projection, node)
      )
      .attr('class', (node) ->
        return 'origin metanode-bounding-box'
      )
      .attr('width', (node) ->
        return self._projectRectWidth(projection, node)
      )
      .attr('height', (node) ->
        return self._projectRectHeight(projection, node)
      )
      .attr('style', (node) ->
        style = node.getBoxStyle()
        return style
      )
    metaNodeBoxes.exit()
    return

  _projectTextX: (projection, node, initialTextWidth) ->
    x = projection.latLngToLayerPoint(node.latLng).x
    if typeof node.labelMetrics != 'undefined'
      return x - (node.labelMetrics.width / 2) / projection.scale
    else
      return x - 1 / projection.scale

  _projectTextY: (projection, node) ->
    y = projection.latLngToLayerPoint(node.latLng).y
    if typeof node.labelMetrics != 'undefined'
      return y - (node.labelMetrics.height / 2) / projection.scale
    else
      return y - 1 / projection.scale

  _projectRectX: (projection, node) ->
    if typeof node.bounds != 'undefined'
      x = projection.latLngToLayerPoint(node.bounds.getNorthWest()).x
      return x
    else
      return 0

  _projectRectY: (projection, node) ->
    if typeof node.bounds != 'undefined'
      y = projection.latLngToLayerPoint(node.bounds.getNorthWest()).y
      return y
    else
      return 0

  _projectRectWidth: (projection, node) ->
    if typeof node.bounds != 'undefined'
      x1 = projection.latLngToLayerPoint(node.bounds.getNorthWest()).x
      x2 = projection.latLngToLayerPoint(node.bounds.getNorthEast()).x
      return Math.abs(x2 - x1)
    else
      return 0

  _projectRectHeight: (projection, node) ->
    if typeof node.bounds != 'undefined'
      y1 = projection.latLngToLayerPoint(node.bounds.getNorthWest()).y
      y2 = projection.latLngToLayerPoint(node.bounds.getSouthWest()).y
      return Math.abs(y2 - y1)
    else
      return 0

  _projectCX: (projection, node) ->
    x = projection.latLngToLayerPoint(node.latLng).x
    r = 1 / projection.scale
    return x - r

  _projectCY: (projection, node) ->
    y = projection.latLngToLayerPoint(node.latLng).y
    r = 1 / projection.scale
    return y - r

  # converts domain specific flight data into generic GritsNode nodes
  #
  # @param [Object] flight, an Astronomy class 'Flight' represending a single record from a MongoDB collection
  # @param [Array] list of originTokens (_id) from the query that should be exclude from the throughput
  # @return [Array] array containing the [originNode, destinationNode]
  convertFlight: (flight, level, originTokens) ->
    self = this

    # container to be populated with set of metanode's children
    metaNodeChildren = {}
    # does a metaToken exist in the originTokens from GritsFilterCriteria?
    metaToken = _.find(originTokens, (token) -> return token.indexOf(GritsMetaNode.PREFIX) >= 0)
    if typeof metaToken != 'undefined'
      # metanodes are previously created by the GritsBoundingBox
      metaNode = GritsMetaNode.find(metaToken)
      if metaNode != null
        # set eventHandlers
        if metaNode.hasOwnProperty('eventHandlers')
          if Object.keys(metaNode.eventHandlers) <= 0
            metaNode.setEventHandlers(_eventHandlers)
        # add metanode to the layer data
        self._data[metaToken] = metaNode
        # metanodes are always origins
        metaNode.isOrigin = true
        # place children into a set
        _.each(metaNode._children, (child) ->
          tokens = metaNodeChildren[child._id]
          if typeof tokens == 'undefined'
            tokens = {}
          tokens[metaToken] = metaToken
          metaNodeChildren[child._id] = tokens
        )

    originNode = null
    destinationNode = null
    # the departureAirport of the flight
    origin = _.find(Meteor.gritsUtil.airports, (airport) -> return airport._id == flight.departureAirport._id)
    if (typeof origin != 'undefined' and origin != null and origin.hasOwnProperty('_id'))
      if origin._id in Object.keys(metaNodeChildren)
        node = self._data[metaToken]
        node.level = level
        node.outgoingThroughput += flight.totalSeats
        originNode = node
      else
        originNode = self._data[origin._id]
        if (typeof originNode == 'undefined' or originNode == null)
          try
            marker = new GritsMarker(_size[0], _size[1], _colorScale, _widthScale)
            originNode = new GritsNode(origin, marker)
            originNode.level = level
            originNode.setEventHandlers(_eventHandlers)
            originNode.outgoingThroughput = flight.totalSeats
            if originNode._id in originTokens
              originNode.isOrigin = true
          catch e
            console.error(e.message)
            return [null, null]
          self._data[origin._id] = originNode
        else
          originNode.outgoingThroughput += flight.totalSeats

    # the arrivalAirport of the flight
    destination = _.find(Meteor.gritsUtil.airports, (airport) -> return airport._id == flight.arrivalAirport._id)
    if (typeof destination != "undefined" and destination != null and destination.hasOwnProperty('_id'))
      destinationNode = self._data[destination._id]
      if (typeof destinationNode == "undefined" or destinationNode == null)
        try
          marker = new GritsMarker(_size[0], _size[1], _colorScale, _widthScale)
          destinationNode = new GritsNode(destination, marker)

          # if the originNode is a metaNode, check the destination to be within
          # its bounds, if so discard.
          if originNode instanceof GritsMetaNode
            if originNode.bounds.contains(new L.LatLng(destinationNode.latLng[0], destinationNode.latLng[1]))
              return [null, null]

          destinationNode.level = level
          destinationNode.setEventHandlers(_eventHandlers)
          destinationNode.incomingThroughput = flight.totalSeats
        catch e
          console.error(e.message)
          return
        self._data[destination._id] = destinationNode
      else
        destinationNode.incomingThroughput += flight.totalSeats

    return [originNode, destinationNode]

  convertItineraries: (itinerary, originToken) ->
    self = this

    originNode = null
    destinationNode = null

    origin = _.find(Meteor.gritsUtil.airports, (airport) -> return airport._id == itinerary.origin)
    if (typeof origin == 'undefined' or origin == null)
      return [null, null]

    originNode = self._data[origin._id]
    if (typeof originNode == 'undefined' or originNode == null)
      try
        marker = new GritsMarker(_size[0], _size[1], _colorScale, _widthScale)
        originNode = new GritsNode(origin, marker)
        originNode.setEventHandlers(_eventHandlers)
        self._data[origin._id] = originNode
        if originNode._id == originToken
          originNode.isOrigin = true
      catch e
        console.error(e.message)
        return [null, null]

    destination = _.find(Meteor.gritsUtil.airports, (airport) -> return airport._id == itinerary.destination)
    if (typeof destination == 'undefined' or destination == null)
      return [null, null]

    destinationNode = self._data[destination._id]
    if (typeof destinationNode == 'undefined' or destinationNode == null)
      try
        marker = new GritsMarker(_size[0], _size[1], _colorScale, _widthScale)
        destinationNode = new GritsNode(destination, marker)
        destinationNode.setEventHandlers(_eventHandlers)
        self._data[destination._id] = destinationNode
        destinationNode.incomingThroughput = 1
      catch e
        console.error(e.message)
        return [null, null]
    else
      destinationNode.incomingThroughput += 1

    return [originNode, destinationNode]

  # returns the normalized throughput for a node
  #
  # @return [Number] normalizedThroughput, 0 >= n <= .9
  _getNormalizedThroughput: (node) ->
    self = this
    maxAllowed = 100
    r = 0
    if self._normalizedCI > 0
      r = ((node.incomingThroughput + node.outgoingThroughput) / self._normalizedCI) * 100
    if r > maxAllowed
      return maxAllowed
    node.normalizedPercent = +(r).toFixed(0)
    return node.normalizedPercent

  _getNormalizedWidth: (node) ->
    self = this
    np = self._getNormalizedThroughput(node)
    if np < 10
      node.width = node.marker.widthScale[0]
    else if np < 20
      node.width = node.marker.widthScale[1]
    else if np < 30
      node.width = node.marker.widthScale[2]
    else if np < 40
      node.width = node.marker.widthScale[3]
    else if np < 50
      node.width = node.marker.widthScale[4]
    else if np < 60
      node.width = node.marker.widthScale[5]
    else if np < 70
      node.width = node.marker.widthScale[6]
    else if np < 80
      node.width = node.marker.widthScale[7]
    else if np < 90
      node.width = node.marker.widthScale[8]
    else if np <= 100
      node.width = node.marker.widthScale[9]
    else
      node.width = node.marker.widthScale[9]
    return node.width

  # returns the color to use as the marker fill
  #
  # @return [String] color, the marker image color
  _getNormalizedColor: (node) ->
    self = this
    np = self._getNormalizedThroughput(node)
    if np < 10
      node.color = node.marker.colorScale[10]
    else if np < 20
      node.color = node.marker.colorScale[20]
    else if np < 30
      node.color = node.marker.colorScale[30]
    else if np < 40
      node.color = node.marker.colorScale[40]
    else if np < 50
      node.color = node.marker.colorScale[50]
    else if np < 60
      node.color = node.marker.colorScale[60]
    else if np < 70
      node.color = node.marker.colorScale[70]
    else if np < 80
      node.color = node.marker.colorScale[80]
    else if np < 90
      node.color = node.marker.colorScale[90]
    else if np <= 100
      node.color = node.marker.colorScale[100]
    else
      node.color = node.marker.colorScale[10]
    return node.color

  # returns the visible paths based on min,max values
  #
  # @param [Integer] min, the minimum value
  # @param [Integer] max, the maximum value
  # @return [Array] visible, the visible paths
  filterMinMaxThroughput: (min, max) ->
    self = this
    nodes = self.getNodes()
    if _.isEmpty(nodes)
      return
    visible = _.filter(nodes, (node) ->
      $element = $('#' + node.elementID)
      np = self._getNormalizedThroughput(node)
      if (np < min) || (np > max)
        $element.css({'display': 'none'})
        node.visible = false
      else
        $element.css({'display': ''})
        node.visible = true
        n = node
      if n
        return n
    )
    return visible

  # tracks min,max set by the UI slider
  trackMinMaxThroughput: ->
    self = this
    Meteor.autorun ->
      min = self.min.get()
      max = self.max.get()
      self.visibleNodes.set(self.filterMinMaxThroughput(min, max))
    return

  # return image file for the marker
  getMarkerHref: (node) ->
    if node.isOrigin
      return '/packages/grits_grits-net-meteor/public/images/origin-marker-icon.svg'
    else
      return ''

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

# Static reference to the colorScale and widthScale
GritsNodeLayer.colorScale = _colorScale
GritsNodeLayer.widthScale = _widthScale
