Template.gritsMap.onRendered ->
  info = L.control(position: 'topleft')
  info.onAdd = (map) ->
    @_div = L.DomUtil.create('div', 'info')
    Blaze.render(Template.infoBar, @_div)
    @update()
    @_div
  info.update = (props) ->
    if props
      L.DomUtil.addClass(@_div, 'active')
    else
      L.DomUtil.removeClass(@_div, 'active')

  @autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady
      map = Template.gritsMap.getInstance()
      info.addTo(map)


Template.infoBar.helpers
  dateRangeStart: ->
    moment.utc( Session.get('dateRangeStart') ).format('MM/DD/YYYY')
  dateRangeEnd: ->
    moment.utc( Session.get('dateRangeEnd') ).format('MM/DD/YYYY')
