DEBUG = Meteor.gritsUtil.debug
HEATMAP_INTENSITY_MULTIPLIER = 1
FRAME_INTERVAL = 125 # milliseconds
BUFFER_READY_THRESHOLD = 0.20 # amount of the buffer that should be filled before allowing dequeue
_buffer = null # fifo buffer for pre-processed locations
_animation = null # stores the setInterval id of the animation


alpha = /[^a-zA-Z]/g
numeric = /[^0-9]/g
###
# locationsComparator is a custom comparator to sort alphanumeric MD5 hash
# of a location.
# @param [Array] a, the mid element from the location array
# @param [String] b, the id we are searching for
# @note postion 5 of the array is the hash, this can be seen in GritsHeatmapLayer.createLocation
###
locationsComparator = (a, b) ->
  idPos = 5 # zero-based position of the location array that contains the id
  if typeof a[idPos] == 'undefined'
    return -1
  aAlpha = a[idPos].replace(alpha, '')
  bAlpha = b.replace(alpha, '')
  if aAlpha == bAlpha
    aNumeric = parseInt(a[idPos].replace(numeric, ''), 10)
    bNumeric = parseInt(b.replace(numeric, ''), 10)
    if aNumeric == bNumeric
      return 0
    else if aNumeric > bNumeric
      return 1
    else
      return -1
  else
    if aAlpha > bAlpha
      return 1
    else
      return -1

###
# locationsComparator is a custom comparator to sort alphanumeric MD5 hash
# of a location.
# @param [Object] a, the mid object from the frames array
# @param [String] b, the period we are searching for
# @note `_id.period` is returned from the mongodb aggregate function
###
periodComparator = (a, b) ->
  if typeof a == 'undefined'
    return -1
  return a._id.period - b

###
# binarySearch
#
# @param [Array] array, the sorted array to search
# @param [Array] value, the element to search
# @return [Number] idx, the index or the position to insert
###
binarySearch = (array, value, cmp) ->
  low = 0
  high = array.length - 1
  while low <= high
    mid = Math.floor(low + ((high - low) / 2))
    c = cmp(array[mid], value)
    if c > 0
      high = mid - 1
    else if c < 0
      low = mid + 1
    else
      return mid
  return -low - 1

###
# decrementLocations subtracts the previousFrame from the locations array
#
# @param [Array] locations, the locations array
# @param [Object] previousFrame, the previousFrame from the buffer
###
decrementLocations = (locations, lastFrame) ->
  lastFrame.forEach (loc) ->
    location = binarySearch(locations, loc[5], locationsComparator)
    if location
      location[2] -= loc[3]

###
# creates a migration location element based on a mongodb document
#
# @param [Array] locations, the locations array
# @param [Array] doc, the GeoJSON mongoDB document
# @param [Array] tokens, the tokens from the filter
###
updateLocations = (locations, doc, tokens, dateKey) ->
  id = CryptoJS.MD5("#{JSON.stringify(doc.loc)}").toString()
  count = doc.sightings?.reduce((sofar, sighting) ->
    if _.contains(tokens, sighting.bird_id)
      sofar + (sighting?.count or 0)
    else
      sofar
  , 0)
  idx = binarySearch(locations, id, locationsComparator)
  if idx < 0
    location = [] # create new location if undefined
    location.push(doc.loc.coordinates[1])
    location.push(doc.loc.coordinates[0])
    location.push(count) # the count for this date
    location.push(count) # the previous count
    location.push(dateKey) # the previous dateKey
    location.push(id)
    # binarySearch will give us the insertion point as -idx
    locations.splice(Math.abs(idx), 0, location)
  else
    location = locations[idx]
    location[2] += count # increment by the count
    location[3] = count # store next previous count
    location[4] = dateKey # store next previous dateKey

###
# bufferFrames, creates a FIFO buffer of frames
#
# @param [Array] matches, the result of the mongodb query
# @param [Array] tokens, the result of the typeahead filter
# @param [Array] frameNames, an array of moment objects from the startDate and endDate
###
bufferFrames = (matches, tokens, frameNames) ->
  _locations = []
  _buffer = new FrameBuffer()
  setReady = _.once(() -> GritsHeatmapLayer.animationReady.set(true))
  isReadySize = Math.floor(frameNames.length * BUFFER_READY_THRESHOLD)
  previousFrame = null
  count = 0
  async.eachSeries frameNames, (frameName, next) ->
    # decrement the previous frame count
    if previousFrame
      decrementLocations(_locations, previousFrame.data)
    # get the results for this frameName
    idx = binarySearch(matches, frameName, periodComparator)
    if idx >= 0
      migrations = matches[idx]
      migrations.results.forEach (migration) ->
        updateLocations(_locations, migration, tokens, frameName)
      currentFrame = new Frame(_locations.slice(0), migrations.results.length, frameName)
    else
      # this frame should be empty
      currentFrame = new Frame([], 0, frameName)
    # queue the pre-processed frame into the buffer
    _buffer.enqueue(currentFrame)
    # copy the previousFrame so that its values can be decremented
    previousFrame = Object.assign({}, currentFrame)
    # we are using async.eachSeries as to not lock the event-loop
    # call next()
    async.nextTick ->
      # once the buffer has been filled to 35% of total frames, mark is as ready
      if _buffer.size() > isReadySize
        setReady()
      next()

# Creates an instance of a GritsHeatmapLayer, extends  GritsLayer
#
# @param [Object] map, an instance of GritsMap
# @param [String] displayName, the displayName for the layer selector
class GritsHeatmapLayer extends GritsLayer
  constructor: (map, displayName) ->
    GritsLayer.call(this) # invoke super constructor
    self = this
    if typeof map == 'undefined'
      throw new Error('A layer requires a map to be defined')
      return
    if !map instanceof GritsMap
      throw new Error('A layer requires a valid map instance')
      return
    if typeof displayName == 'undefined'
      self._displayName = 'Heatmap'
    else
      self._displayName = displayName

    self._name = 'Heatmap'
    self._map = map

    self._layer = new L.TileLayer.WebGLHeatMap(
      size: 1609.34 * 150 # meters equals 250 miles
      alphaRange: 0.1
      gradientTexture: '/packages/' + GritsConstants.PACKAGE_NAME + '/public/images/viridis.png'
      opacity: 0.55
    )

    self.hasLoaded = new ReactiveVar(false)

    self._bindMapEvents()
    self._trackTokens()
    return

  # This is a workaround for a bug where the heatmap library's gradient doesn't
  # load in chrome sometimes.
  _perturbMap: ->
    _.defer =>
      @_layer.update()

  # draws the heatmap
  #
  # @note method overrides the parent class GritsLayer clear method
  # @override
  draw: (locations) ->
    # An extra point with no intensity is added because passing in an empty
    # array causes a bug where the previous heatmap is frozen in view.
    locations = locations || []
    data = locations.concat([[0.0, 0.0, 0]])

    # Normalize the intensity
    totalSightings = data.reduce(((sofar, d) -> sofar + d[2]), 0)
    data.forEach((d) -> 100 * d[2] /= totalSightings)
    @_layer.setData(data)
    @_perturbMap()
    @hasLoaded.set(true)

  # clears the heatmap
  #
  # @note method overrides the parent class GritsLayer clear method
  # @override
  clear: ->
    this._layer.setData([])
    this.hasLoaded.set(false)
    return

  _trackTokens: ->
    self = this
    Meteor.autorun ->
      tokens = GritsFilterCriteria.tokens.get()
      if tokens.length == 0
        self.clear()

  # binds to the Tracker.gritsMap.getInstance() map event listener .on
  # 'overlyadd' and 'overlayremove' methods
  _bindMapEvents: ->
    self = this
    if typeof self._map == 'undefined'
      return
    self._map.on(
      overlayadd: (e) ->
        if e.name == self._displayName
          if DEBUG
            console.log("#{self._displayName} layer was added")
        self._perturbMap()
      overlayremove: (e) ->
        if e.name == self._displayName
          if DEBUG
            console.log("#{self._displayName} layer was removed")
    )


# static methods
# Reactive vars to keep track of the animation
GritsHeatmapLayer.animationRunning = new ReactiveVar(false)
GritsHeatmapLayer.animationProgress = new ReactiveVar(0)
GritsHeatmapLayer.animationFrame = new ReactiveVar(null)
GritsHeatmapLayer.animationCompleted = new ReactiveVar(false)
GritsHeatmapLayer.animationPaused = new ReactiveVar(false)
GritsHeatmapLayer.animationReady = new ReactiveVar(false)

# pause the heatmap animation
GritsHeatmapLayer.pauseAnimation = ->
  if DEBUG
    console.log 'animationPaused'
  GritsHeatmapLayer.animationPaused.set(true)

# stop the heatmap animation
GritsHeatmapLayer.stopAnimation = ->
  GritsHeatmapLayer.animationCompleted.set(true)
  GritsHeatmapLayer.animationRunning.set(false)
  GritsHeatmapLayer.animationPaused.set(false)
  async.nextTick ->
    if DEBUG
      console.log 'stopAnimation'
    clearInterval(_animation)
    _animation = null
    # TODO, we may want to clear the session counters and/or clear the map

# start the heatmap animation
#
# @note: this method sets the ReactiveVar for the animation: animationProgress, animationRunning, and animationFrame
# @param [Date] startDate, the startDate from the filter
# @param [Date] endDate, the endDate from the filter
# @param [String] period, the period determines the number of frames to the animation, 'days', 'weeks', 'months', 'years'
# @param [Array] migrations, the array of GeoJSON documents from mongoDB
# @param [Array] frames, the preprocessed array of frames from the server
# @param [Array] tokens, the tokens from the filter
# @param [Number] offset, the offset from the filter
GritsHeatmapLayer.startAnimation = (startDate, endDate, period, migrations, frames, tokens, offset) ->
  # protect against fast double-click on play button; there is a few milliseconds
  # delay between setting the reactive var, updating the blaze template from a
  # play button to pause button. Therefore its possible to double-click and get
  # more than once instance of the setInterval animation.
  if _animation != null
    if DEBUG
      console.warn 'cannot startAnimation; _animation interval exists; return;'
    return
  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
  heatmapLayerGroup.add()

  # Fit map to bounds of all locations
  locations = _.map migrations, (doc) ->
    [doc.loc.coordinates[1], doc.loc.coordinates[0]]
  map.fitBounds(L.latLngBounds(locations))

  # if the offset is equal to zero, clear the layers
  if offset == 0
    heatmapLayerGroup.reset()

  # reset the reactive vars
  GritsHeatmapLayer.animationRunning.set(true)
  GritsHeatmapLayer.animationCompleted.set(false)
  GritsHeatmapLayer.animationPaused.set(false)
  GritsHeatmapLayer.animationReady.set(false)

  # determine the range from the filter, this will drive the animation loop
  range = moment.range(startDate.format('YYYY-MM-DD'), endDate.format('YYYY-MM-DD'))
  # default is days
  period_format = 'YYYYMMDD'
  if period == 'weeks'
    period_format = 'YYYYww'
  else if period == 'months'
    period_format = 'YYYYMM'
  else if period == 'years'
    period_format == 'YYYY'
  frameNames = _.map(range.toArray(period), (m) -> m.format(period_format))
  framesLen = frameNames.length

  # start buffering frames
  bufferFrames(frames, tokens, frameNames)

  lastFrame = null
  lastScrubber = null

  # keep track of processedFrames, check the scrubber first
  processedFrames = 0
  initialScrubber = Session.get('scrubber')
  if processedFrames < initialScrubber[0]
    processedFrames = initialScrubber[0]
  GritsHeatmapLayer.animationProgress.set(processedFrames)

  # the animation is uses setInterval
  _animation = setInterval ->
    if DEBUG
      console.log 'processedFrames: ', processedFrames
    paused = GritsHeatmapLayer.animationPaused.get()
    if paused
      return
    # the buffer will set the animation as being ready
    animationReady = GritsHeatmapLayer.animationReady.get()
    if not animationReady
      return
    if processedFrames >= framesLen
      if DEBUG
        console.log 'setInterval.processedFrames >= framesLen; stop; return;'
      GritsHeatmapLayer.stopAnimation()
      return
    # how is the scrubber set?
    currentScrubber = Session.get('scrubber')
    # check if the current scrubber caused the animation to stop
    if processedFrames > currentScrubber[1]
      # the end handle of the scrubber was moved left past the current position; effectively a re-wind
      if lastScrubber != null and currentScrubber[1] < lastScrubber[1]
        processedFrames = currentScrubber[0]
        Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
        lastScrubber = null
        if DEBUG
          console.log 'the end handle of the scrubber was moved left past the current position; effectively a re-wind; return;'
        return
      # the animation has reached the end handle; stop
      else
        GritsHeatmapLayer.stopAnimation()
        if DEBUG
          console.log 'the animation has reached the end handle; stop; return;'
        return
    # check if the current scrubber caused a fast-forward
    if processedFrames < currentScrubber[0]
      processedFrames = currentScrubber[0]
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      if DEBUG
        console.log 'check if the current scrubber caused a fast-forward; return;'
      return
    # check if the current scrubber caused a re-wind
    if lastScrubber != null and currentScrubber[0] < lastScrubber[0]
      processedFrames = currentScrubber[0]
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      lastScrubber = null
      if DEBUG
        console.log 'check if the current scrubber caused a re-wind; return;'
      return
    lastScrubber = currentScrubber
    # guard against frames that take longer to process than the interval
    if processedFrames == lastFrame
      if Meteor.gritsUtil.debug
        console.log 'too fast'
      return
    completed = GritsHeatmapLayer.animationCompleted.get()
    if !completed
      # get the locations for this frame
      currentFrame = _buffer.dequeue()
      if Meteor.gritsUtil.debug
        console.log 'buffer.size(): ', _buffer.size()
      if currentFrame
        # update drawing the heatmap
        heatmapLayerGroup.draw(currentFrame.data)
        # get the number of pre-processed locations for the frame buffer
        preProcessedLocations = currentFrame.processed
        # get any previous processedLocations
        processedLocations = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
        # update the session counter of loaded locations
        Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, preProcessedLocations + processedLocations)
        # guard against timing issues from the next setInterval firing before the
        # current frame is done processing by setting lastFrame
        lastFrame = processedFrames
        # set the ReactiveVar so the UI may listen to changes to the animation frame
        GritsHeatmapLayer.animationFrame.set(currentFrame.key)
        # increment the number of processedFrames
        GritsHeatmapLayer.animationProgress.set((processedFrames + 1) / framesLen)
        processedFrames++
  , FRAME_INTERVAL

# get mirgations from mongo by an array of dates and token from the UI filter
#
# @param [Array] dates, the array of dates to match
# @param [String] token, the token from the filter
# @param [Number] limit, the limit from the filter
# @param [Number] offset, the offset from the filter
# @param [String] period, the period in 'days','weeks','months','years'
# @param [Function] done, callback when done
GritsHeatmapLayer.migrationsByDate = (dates, token, limit, offset, period, done) ->
  # show the loading indicator and call the server-side method
  GritsHeatmapLayer.animationRunning.set(true)
  async.auto({
    # get the totalRecords count first
    'getCount': (callback, result) ->
      Meteor.call('countMigrationsByDates', dates, token, (err, totalRecords) ->
        if (err)
          callback(err)
          return

        if DEBUG
          console.log 'totalRecords: ', totalRecords

        Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, totalRecords)
        callback(null, totalRecords)
      )
    # when count is finished, get the migrations if greater than 0
    'getMigrations': ['getCount', (callback, result) ->
      totalRecords = result.getCount
      if totalRecords == 0
        callback(null, [])
        return
      Meteor.call('migrationsByDates', dates, token, limit, offset, callback)
    ]
  }, (err, result) ->
    if err
      GritsHeatmapLayer.animationRunning.set(false)
      Meteor.gritsUtil.errorHandler(err)
      return
    # if there hasn't been any errors, getCount and getMigrations will
    # have completed
    migrations = result.getMigrations

    # check if migrations is undefiend or empty
    if _.isUndefined(migrations) || _.isEmpty(migrations)
      toastr.info(i18n.get('toastMessages.noResults'))
      GritsHeatmapLayer.animationRunning.set(false)
      return

    groupedResults = _.groupBy(migrations, (result) ->
      moment(result['date']).startOf 'isoWeek'
    )

    # Grouped by Week
    GroupedMigrations.remove({})
    i = 0
    ilen = groupedResults.length
    while i < ilen
      GroupedMigrations.insert(groupedResults[i])
      i++

    debugger
    MiniMigrations.remove({})
    i = 0
    ilen = migrations.length
    while i < ilen
      MiniMigrations.insert(migrations[i])
      i++

    # execute the callback to process the migrations
    done(null, migrations)
    return
  )
  return

# get mirgations from mongo by a startDate, endDate, and token from the UI filter
#
# @param [Date] startDate, the startDate from the filter
# @param [Date] endDate, the endDate from the filter
# @param [String] token, the token from the filter
# @param [Number] limit, the limit from the filter
# @param [Number] offset, the offset from the filter
# @param [Function] done, callback when done
GritsHeatmapLayer.migrationsByDateRange = (startDate, endDate, token, limit, offset, period, done) ->
  console.log('migrations by date range')
  # show the loading indicator and call the server-side method
  GritsHeatmapLayer.animationRunning.set(true)
  async.auto({
    # get the totalRecords count first
    'getCount': (callback, result) ->
      Meteor.call('countMigrationsByDateRange', startDate, endDate, token, (err, totalRecords) ->
        if (err)
          callback(err)
          return

        if DEBUG
          console.log 'totalRecords: ', totalRecords

        Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, totalRecords)
        callback(null, totalRecords)
      )
    # when count is finished, get the migrations if greater than 0
    'getMigrations': ['getCount', (callback, result) ->
      totalRecords = result.getCount
      if totalRecords == 0
        callback(null, [])
        return
      Meteor.call('migrationsByQuery', startDate, endDate, token, limit, offset, period, callback)
    ]
  }, (err, result) ->
    if err
      GritsHeatmapLayer.animationRunning.set(false)
      Meteor.gritsUtil.errorHandler(err)
      return

    # if there hasn't been any errors, getCount and getMigrations will
    # have completed
    migrations = result.getMigrations.migrations
    frames = result.getMigrations.matches

    # check if migrations is undefiend or empty
    if _.isUndefined(migrations) || _.isEmpty(migrations)
      toastr.info(i18n.get('toastMessages.noResults'))
      GritsHeatmapLayer.animationRunning.set(false)
      return

    groupedResults = _.groupBy(migrations, (result) ->
      moment(result['date']).startOf 'isoWeek'
    )
    groupedResults = _.toArray groupedResults

    # Grouped by Week
    GroupedMigrations.remove({})
    i = 0
    ilen = groupedResults.length
    while i < ilen
      GroupedMigrations.insert({date: groupedResults[i][0].date, data: groupedResults[i] })
      i++

    # Not grouped, flat daily
    MiniMigrations.remove({})
    i = 0
    ilen = migrations.length
    while i < ilen
      MiniMigrations.insert(migrations[i])
      i++

    done(null, {migrations: migrations, frames: frames})
    return

  )
  return
