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
  Session.setDefault("slider", [0, 100])
  @isPlaying = new ReactiveVar(false)
  @isPaused = new ReactiveVar(false)

  Meteor.autorun =>
    @isPlaying.set( GritsHeatmapLayer.animationRunning.get() )
    @isPaused.set( GritsHeatmapLayer.animationPaused.get() )

Template.scrubber.onRendered ->
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
    console.log Session.get('slider')

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
