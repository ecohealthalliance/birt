# creates an instance of a path
#
# method GritsPath(obj, throughput, level, origin, destination)
# @param [Object] obj, an object that represents a path, it must contain a
#  unique _id property
# @param [Integer] throughput, the throughput for this path
# @param [Integer] level, the level for this path
# @param [Object] origin, a GritsNode instance
# @param [Object] destination, a GritsNode instance
class GritsPath
  constructor: (obj, throughput, level, origin, destination) ->
    @_name = 'GritsPath'

    if typeof obj == 'undefined' or !(obj instanceof Object)
      throw new Error("#{@_name} - obj must be defined and of type Object")
      return

    if obj.hasOwnProperty('_id') == false
      throw new Error("#{@_name} - obj requires the _id property")
      return

    if typeof throughput == 'undefined'
      throw new Error("#{@_name} - throughput must be defined")
      return

    if typeof level == 'undefined'
      throw new Error("#{@_name} - level must be defined")
      return

    if (typeof origin == 'undefined' or !(origin instanceof GritsNode || origin instanceof GritsMetaNode))
      throw new Error("#{@_name} - origin must be defined and of type GritsNode")
      return

    if (typeof origin == 'undefined' or !(destination instanceof GritsNode))
      throw new Error("#{@_name} - destination must be defined and of type GritsNode")
      return

    # a unique path is defined as an origin to a destination
    @_id = CryptoJS.MD5(origin._id + destination._id).toString()

    @level = level
    @throughput = throughput

    @normalizedPercent = 0
    @occurrences = 1

    @origin = origin
    @destination = destination
    @midPoint = @getMidPoint()

    @element = null # d3 DOM element, updated when the layer draws
    @color = '#fdcc8a' # default color, updated when the layer draws

    @metadata = {}
    _.extend(@metadata, obj)

    @eventHandlers = {}
    return

  # returns the mid point of a path
  #
  # @method getMidPoint()
  getMidPoint: ->
      ud = true
      midPoint = []
      latDif = Math.abs(@origin.latLng[0] - @destination.latLng[0])
      lngDif = Math.abs(@origin.latLng[1] - @destination.latLng[1])
      ud = if latDif > lngDif then false else true
      if @origin.latLng[0] > @destination.latLng[0]
        if ud
          midPoint[0] = @destination.latLng[0] + (latDif / 4)
        else
          midPoint[0] = @origin.latLng[0] - (latDif / 4)
      else
        if ud
          midPoint[0] = @destination.latLng[0] - (latDif / 4)
        else
          midPoint[0] = @origin.latLng[0] + (latDif / 4)
      midPoint[1] = (@origin.latLng[1] + @destination.latLng[1]) / 2
      return midPoint

  # binds eventHandlers to the node
  #
  # @method setEventHandlers(eventHandlers)
  # @param [Object] eventHandlers, an object containing event handlers
  setEventHandlers: (eventHandlers) ->
    for name, method of eventHandlers
      @eventHandlers[name] = _.bind(method, this)
