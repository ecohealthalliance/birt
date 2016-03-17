_isDrawing = false
_boundingBox = null
_lastMode = null

Template.gritsMapSidebar.helpers
  GritsConstants: ->
    return GritsConstants

Template.gritsMapSidebar.events
  'change #mode-toggle': (event) ->
    # reset counters and heatmap
    Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
    Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, 0)
    # the trigger to toggle the mode can happen before the map is initialized
    # check that its not undefined or null
    map = Template.gritsMap.getInstance()
    if !(_.isUndefined(map) || _.isNull(map))
      map._layers.heatmap.reset()
    mode = $(event.target).data('mode')
    if _lastMode == mode
      return
    Session.set(GritsConstants.SESSION_KEY_MODE, mode)
    return
  'click #sidebar-plus-button': (event) ->
    Template.gritsMap.getInstance().zoomIn()
    return
  'click #sidebar-minus-button': (event) ->
    Template.gritsMap.getInstance().zoomOut()
    return
  'click #sidebar-draw-rectangle-tool': (event) ->
    map = Template.gritsMap.getInstance()
    _isDrawing = !_isDrawing # toggle
    if _isDrawing
      $('#sidebar-draw-rectangle-tool').addClass('sidebar-highlight')
      _boundingBox = new GritsBoundingBox($('.sidebar-tabs'), map)
      $("#action-menu-Select").click()
    else
      $('#sidebar-draw-rectangle-tool').removeClass('sidebar-highlight')
      if _boundingBox != null
        _boundingBox.remove()

Template.gritsMapSidebar.onRendered ->
  self = this

  # keep the UI reactive with the current mode
  Meteor.autorun ->
    _lastMode = Session.get(GritsConstants.SESSION_KEY_MODE)
    $('#mode-toggle :input[data-mode="' + _lastMode + '"]').click()

  Meteor.autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady
      $('#mode-toggle').show()
