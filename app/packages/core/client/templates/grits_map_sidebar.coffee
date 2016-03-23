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

Template.gritsMapSidebar.onRendered ->
  self = this
