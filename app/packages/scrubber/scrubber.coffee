Template.gritsMap.onRendered ->
  
  scrubber = L.control(position: 'bottomleft')
  scrubber.onAdd = (map) ->
    @_div = L.DomUtil.create('div', 'scrubber')
    @update()
    @_div
  scrubber.update = (props) ->
    if props
      L.DomUtil.addClass(@_div, 'active')
      @_div.innerHTML = '';
    else
      L.DomUtil.removeClass(@_div, 'active')
      @_div.innerHTML = '<div class="scrubber-container"><div class="scrubber-play"><i class="fa fa-play-circle fa-4x"></i></div><div class="right-slider-container"><div id="slider"></div></div></div>'

  sliderLoaded = false

  @autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady and not sliderLoaded
      map = Template.gritsMap.getInstance()
      scrubber.addTo(map)
      
      Session.setDefault("slider", [20, 80]);
      $('#slider').noUiSlider(
        start: Session.get('slider')
        connect: true
        range:
          'min': 0
          'max': 100).on('slide', (ev, val) ->
        # set real values on 'slide' event
        Session.set 'slider', val
      ).on 'change', (ev, val) ->
        # round off values on 'change' event
        Session.set 'slider', [
          Math.round(val[0])
          Math.round(val[1])
        ]
      sliderLoaded = true

    console.log Session.get('slider')
