_slider = null #container for the noUiSlider element

# determines the current date range of the UI filter
#
# @note: has reactive vars, so calling within autorun will trigger a recomputation
# @return [Object] range, the range with min/max values
_determineRange = () ->
  startDate = GritsFilterCriteria.operatingDateRangeStart.get()
  endDate = GritsFilterCriteria.operatingDateRangeEnd.get()
  period = GritsFilterCriteria.period.get()
  return moment.range(startDate, endDate).toArray(period)

Template.gritsMap.onRendered ->
  scrubber = L.control(position: 'bottomleft')
  scrubber.onAdd = (map) ->
    @_div = L.DomUtil.create('div', 'scrubber')
    Blaze.render(Template.scrubber, @_div)
    @update()
    @_div
  scrubber.update = (props) ->
    if props
      L.DomUtil.addClass(@_div, 'active')
    else
      L.DomUtil.removeClass(@_div, 'active')

  @autorun ->
    isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
    if isReady
      map = Template.gritsMap.getInstance()
      scrubber.addTo(map)

Template.scrubber.onCreated ->
  @isPlaying = new ReactiveVar(false)
  @isPaused = new ReactiveVar(false)
  range = _determineRange()
  if range.length - 1 <= 0
    len = 1
  else
    len = range.length
  Session.setDefault('scrubber', [0, len])

Template.scrubber.onRendered ->
  @autorun =>
    @isPlaying.set( GritsHeatmapLayer.animationRunning.get() )
    @isPaused.set( GritsHeatmapLayer.animationPaused.get() )

  @autorun ->
    # the method _determineRange has reactive vars on the UI filter, for
    # startDate, endDate, and period. any changes will trigger a recompute
    range = _determineRange()
    if range.length - 1 <= 0
      len = 1
    else
      len = range.length
    if _slider == null
      _slider =  document.getElementById('slider')
      noUiSlider.create(_slider,
        start: [0, len]
        connect: true
        step: 1
        range: {min: 0, max: len}
      )
      _slider.noUiSlider.on('update', (val, handle) ->
        beginIdx = parseInt(val[0], 10)
        endIdx = parseInt(val[1], 10)
        # when dragging the beginning handle, the scrubber-progress bar will
        # update its percent left to follow
        percent = (beginIdx/len * 100) + '%'
        $('.scrubber-progress').css('left', percent)
        # if the animation is running then pause
        if GritsHeatmapLayer.animationRunning.get()
          GritsHeatmapLayer.pauseAnimation()
        Session.set('scrubber', [beginIdx, endIdx])
      )
    # the _slider exists, update its options
    else
      _slider.noUiSlider.updateOptions(
        range: {min: 0, max: len}
      )
      _slider.noUiSlider.set([0, len])

Template.scrubber.helpers
  state: ->
    if Template.instance().isPlaying.get()
      'pause'
    else
      'play'
  paused: ->
    if Template.instance().isPaused.get()
      'pulse'
    else
      ''
  progress: ->
    progress = GritsHeatmapLayer.animationProgress.get()
    return progress * 100 + '%'


Template.scrubber.events
  'dblclick .scrubber-container': (event) ->
    event.stopImmediatePropagation()
    event.stopPropagation()
  'click .scrubber-play': (event, instance) ->
    isPlaying = instance.isPlaying.get()
    isPaused = instance.isPaused.get()
    unless isPlaying
      unless isPaused
        $('#applyFilter').click()
    else
      GritsHeatmapLayer.animationPaused.set( not isPaused)
      instance.isPlaying.set( not isPlaying )
