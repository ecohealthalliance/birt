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
  Session.setDefault("slider", [20, 80])
  @isPlaying = new ReactiveVar(false)

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

Template.scrubber.events
  'dblclick .scrubber-container': (event) ->
    event.stopImmediatePropagation()
    event.stopPropagation()
  'click .scrubber-play': (event, instance) ->
    instance.isPlaying.set( not instance.isPlaying.get() )
