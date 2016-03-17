# the maximum amount of nodes for a bounding box selection
_maxSelection = 1000
# draws a rectangle on the map, filters nodes within its bounds, and applies
# the filter against a GritsMetaNode
#
# @param [Object] sidebarElement, a jQuery object of the sidebar
# @param [Object] map, the current GritsMap instance
# @note inspiration from https://github.com/Leaflet/Leaflet.draw
class GritsBoundingBox
  constructor: (sidebarElement, map) ->
    self = this
    self._container = sidebarElement
    self._map = map
    # keep track of the initial zoom and center to reset the map upon leaving
    # the selection mode.
    self._initialZoom = self._map.options.zoom
    self._initialCenter = self._map.options.center

    # reset the current layerGroup
    layerGroup = GritsLayerGroup.getCurrentLayerGroup()
    if layerGroup != null
      layerGroup.reset()

    # the bounding box works on the 'AllNodes' layer group
    self._allNodesLayerGroup = self._map.getGritsLayerGroup(GritsConstants.ALL_NODES_GROUP_LAYER_ID)
    self._allNodesLayerGroup.add()
    self._allNodesLayer = self._allNodesLayerGroup.getNodeLayer()



    # underscore templates that represent the action menu and actions
    self._actionMenuTmpl = _.template('<ul id="<%= obj.id %>" class="action-menu"></ul>')
    self._actionTmpl = _.template('<li><div class="btn btn-sm btn-primary action-menu-btn" id="action-menu-<%= obj.name %>"><span><%= obj.name %></span></div></li>')
    self._actions = {} # container for the actions of the action menu

    # the starting coordinate of the bounding box
    self._start = null
    # the stopping coordinate of the bounding box
    self._stop = null

    # is the user drawing?, is true mousedown then false on mouseup
    self._drawing = false

    # the temporary L.Rectangle bounding box (selection)
    self._shape = null
    # the options for drawing the L.Rectangle that represents the temporary bounding box (selection)
    self._options =
      stroke: true
      color: 'blue',
      weight: 2
      opacity: 0.5
      fill: true
      fillColor: null
      fillOpacity: 0.2
      clickable: true

    # enable selecting, selecting is disabled by default
    self._selecting = false

    # the actions menu appears to the right of the sidebar
    self._buildActionMenu()

    # add default actions [Apply, Select] to the action menu
    self.addAction('Apply', (e) -> self.apply())
    self.addAction('Select', _.bind(self._selectToggle, self))
    return
  # binds the map events that enable selecting and disable panning
  _bindMapEvents: ->
    self = this
    self._map.dragging.disable()
    self._map._container.style.cursor = 'crosshair'
    self._map.on('mousedown', self.onMouseDown, self)
    self._map.on('mouseup', self.onMouseUp, self)
    self._map.on('mousemove', self.onMouseMove, self)
    return self
  # unbinds the map events to the default
  _unbindMapEvents: ->
    self = this
    self._map.off('mouseup', self.onMouseUp, self)
    self._map.off('mousedown', self.onMouseDown, self)
    self._map.off('mousemove', self.onMouseMove, self)
    self._map._container.style.cursor = ''
    self._map.dragging.enable()
    return self
  # toggles on/off select mode
  _selectToggle: ->
    self = this
    self._selecting = !self._selecting
    if self._selecting
      self._selectOn()
    else
      self._selectOff()
    return
  # turns on select mode
  _selectOn: ->
    self = this
    self._selecting = true
    self._bindMapEvents()
    $('#action-menu-Select').addClass('action-menu-btn-selected')
  # turns off select mode
  _selectOff: ->
    self = this
    self._selecting = false
    self._unbindMapEvents()
    $('#action-menu-Select').removeClass('action-menu-btn-selected')
    return
  # adds an action to the action menu item
  #
  # @param [String] name, the name of the action
  # @param [Object] handler, the on click handler
  addAction: (name, handler) ->
    self = this
    self._actionMenu.append(self._actionTmpl({name: name}))
    $action = $('#action-menu-'+name)
    $action.on('click', handler)
    self._actions[name] = $action
  # builds the action menu to show on the DOM
  _buildActionMenu: ->
    self = this
    self._actionMenuId = uuid.v4()
    self._actionMenu = $(self._actionMenuTmpl({id: self._actionMenuId})).appendTo(self._container)
    self._actionMenu.show()
    return
  # onmouseup event handler
  onMouseUp: (e) ->
    self = this
    self._stop = e.latlng
    self._drawing = false
    return
  # onmousedown event handler
  onMouseDown: (e) ->
    self = this
    self._start = e.latlng
    self._drawing = true
    return
  # onmousemove event handler
  onMouseMove: (e) ->
    self = this
    if (self._drawing && self.isStartNotEqualEnd())
      self.draw(e.latlng)
    return
  # determines if the use clicked and not dragged the mouse
  isStartNotEqualEnd: ->
    self = this
    return JSON.stringify(self._start) != JSON.stringify(self._stop)
  # draws a rectangle
  #
  # @param [Object] latLng, a Leaflet latLng object
  draw: (latLng) ->
    self = this
    if self._shape != null
      self._shape.setBounds(new L.LatLngBounds(self._start, latLng))
    else
      self._shape = new L.Rectangle(new L.LatLngBounds(self._start, latLng), self.options)
      self._map.addLayer(self._shape)
    return
  # filters nodes that are within the bounding box
  #
  # @return [Object] metaNode, returns a GritsMetaNode or object with error.message
  _filterNodes: ->
    self = this
    nodes = []
    if self._shape != null
      bounds = self._shape.getBounds()
      nodes = _.filter(self._allNodesLayer.getNodes(), (node) -> bounds.contains(new L.LatLng(node.latLng[0], node.latLng[1])))
    if nodes.length > _maxSelection
      return {error: true, message: 'Please narrow your selection. ' + nodes.length + ' is greater than ' + _maxSelection}
    return GritsMetaNode.create(nodes)
  # applies the selection to GritsFilterCriteria
  apply: ->
    self = this
    if self._shape != null
      Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, true)
      # apply the boundingbox filter
      metaNode = self._filterNodes()
      if metaNode.hasOwnProperty('error') && metaNode.error == true
        toastr.warning(metaNode.message)
        Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
        self.reset()
        return
      # erase any previous departures
      GritsFilterCriteria.setDepartures(null)
      # set the meta node as the new origin
      departureSearchMain = Template.gritsSearch.getDepartureSearchMain()
      departureSearchMain.tokenfield('setTokens', metaNode._id)
      async.nextTick( ->
        # apply the filter
        GritsFilterCriteria.apply((err, res) ->
          Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
          self.reset()
        )
      )
  # resets the bounding box so that another may be drawn
  reset: ->
    self = this
    if self._shape != null
      self._map.removeLayer(self._shape)
      self._shape = null
    self._start = null
    self._stop = null
    self._selectOff()
    return
  # removes the bounding box layers and event handlers from the map, resets
  # map to its initial zoom/center
  remove: ->
    self = this
    if self._shape != null
      self._map.removeLayer(self._shape)
    self._selectOff()
    self._actionMenu.remove()
    self._allNodesLayerGroup.remove()
    self._map.setView(self._initialCenter, self._initialZoom)
    return
