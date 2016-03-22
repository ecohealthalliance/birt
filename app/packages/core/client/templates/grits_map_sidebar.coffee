_isDrawing = false
_boundingBox = null
_lastMode = null

Template.gritsMapSidebar.helpers
  GritsConstants: ->
    return GritsConstants

Template.gritsMapSidebar.events
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
  Meteor.autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady
      $('#mode-toggle').show()
