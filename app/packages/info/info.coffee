Template.gritsMap.onRendered ->
  info = L.control(position: 'topleft')
  info.onAdd = (map) ->
    @_div = L.DomUtil.create('div', 'info')
    @update()
    @_div
  info.update = (props) ->
    if props
      L.DomUtil.addClass(@_div, 'active')
      @_div.innerHTML = """
      <h2>Migration time frame</h2>
      <ul class='list-unstyled'>
        <li><span>Year start:</span> #{yearStart}</li>
        <li><span>Year end:</span> #{yearEnd}</li>
      </ul>
      """
    else
      L.DomUtil.removeClass(@_div, 'active')
      @_div.innerHTML = "<p>----------------------------------------------</p>"

  @autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady
      map = Template.gritsMap.getInstance()
      info.addTo(map)
