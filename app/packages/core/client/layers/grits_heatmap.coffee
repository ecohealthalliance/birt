HEATMAP_INTENSITY_MULTIPLIER = 1
FRAME_INTERVAL = 125 # milliseconds
_locations = [] # container to store heatmap data
_animation = null # stores the setInterval id of the animation


alpha = /[^a-zA-Z]/g
numeric = /[^0-9]/g
###
# locationsComparator is a custom comparator to sort alphanumeric MD5 hash
# of a location.
# @param [Array] a, the mid element from the location array
# @param [String] b, the id we are searching for
# @note postion 4 of the array is the hash, this can be seen in GritsHeatmapLayer.createLocation
###
locationsComparator = (a, b) ->
  if typeof a == 'undefined' || typeof b == 'undefined'
    return -1
  aAlpha = a[4].replace(alpha, '')
  bAlpha = b.replace(alpha, '')
  if aAlpha == bAlpha
    aNumeric = parseInt(a[4].replace(numeric, ''), 10)
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
# binarySearch
#
# @param [Array] array, the sorted array to search
# @param [Array] value, the element to search
# @return [Number] idx, the index or the position to insert
###
binarySearch = (array, value, cmp) ->
  if cmp == undefined
    throw new Error('Comparator function is required.')
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
  draw: ->
    # An extra point with no intensity is added because passing in an empty
    # array causes a bug where the previous heatmap is frozen in view.
    #if _locations.length <= 0
    data = _locations.concat([[0.0, 0.0, 0]])
    #else
    #  data = _locations

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
    _locations = []
    this._layer.setData(_locations)
    this.hasLoaded.set(false)
    return

  _trackTokens: ->
    self = this
    Meteor.autorun ->
      tokens = GritsFilterCriteria.tokens.get()
      if tokens.length == 0
        self.clear()

  # get the heatmap data
  #
  # @return [Array] array of the heatmap data
  getData: ->
    self = this
    if _.isEmpty(_locations)
      return []
    return _locations

  # binds to the Tracker.gritsMap.getInstance() map event listener .on
  # 'overlyadd' and 'overlayremove' methods
  _bindMapEvents: ->
    self = this
    if typeof self._map == 'undefined'
      return
    self._map.on(
      overlayadd: (e) ->
        if e.name == self._displayName
          if Meteor.gritsUtil.debug
            console.log("#{self._displayName} layer was added")
        self._perturbMap()
      overlayremove: (e) ->
        if e.name == self._displayName
          if Meteor.gritsUtil.debug
            console.log("#{self._displayName} layer was removed")
    )


# static methods
# Reactive vars to keep track of the animation
GritsHeatmapLayer.animationRunning = new ReactiveVar(false)
GritsHeatmapLayer.animationProgress = new ReactiveVar(0)
GritsHeatmapLayer.animationFrame = new ReactiveVar(null)
GritsHeatmapLayer.animationCompleted = new ReactiveVar(false)
GritsHeatmapLayer.animationPaused = new ReactiveVar(false)

# find the index of the heatmap data matching the id
#
# @param [String] id, the animation frame id
# @return [Number] idx, if positive it is the index of the matching element.
#   if negative, it is the sorted insertion point of a new element.
GritsHeatmapLayer.findIndex = (id) ->
  return binarySearch(_locations, id, locationsComparator)

# resets the array of locations
GritsHeatmapLayer.resetLocations = ->
  _locations.length = 0
  return

# creates a migration location element based on a mongodb document
#
# @param [String] dateKey, the current animation frame
# @param [Array] doc, the GeoJSON mongoDB document
# @param [Array] tokens, the tokens from the filter
GritsHeatmapLayer.createLocation = (dateKey, doc, tokens) ->
  #id = CryptoJS.MD5("#{JSON.stringify(doc.loc)}#{dateKey}").toString()
  id = CryptoJS.MD5("#{JSON.stringify(doc.loc)}").toString()
  count = doc.sightings?.reduce((sofar, sighting) ->
    if _.contains(tokens, sighting.bird_id)
      sofar + (sighting?.count or 0)
    else
      sofar
  , 0)

  idx = GritsHeatmapLayer.findIndex(id)
  if idx < 0
    location = [] # create new location if undefined
    location.push(doc.loc.coordinates[1])
    location.push(doc.loc.coordinates[0])
    location.push(count) # the count for this date
    location.push(dateKey)
    location.push(id)
    # binarySearch will give us the insertion point as -idx
    _locations.splice(Math.abs(idx), 0, location)
  else
    # do we have a count for this date?
    location = _locations[idx]
    location[2] += count # increment by the count

# decrements the value of the locations
#
# @param [Integer] nextIdx, the next index of the animtaion loop
# @param [Array] frames, the datetime objects that create the animation loop
# @param [String] period, the period determines the number of frames to the animation, 'days', 'weeks', 'months', 'years'
# @param [Array] documents, the array of GeoJSON documents from mongoDB
# @param [Array] tokens, the tokens from the filter
# @param [Function] done, the callback when done decrementing the filteredLocations
GritsHeatmapLayer.decrementPreviousLocations = (nextIdx, frames, period, documents, tokens, done) ->
  if nextIdx <= 1
    done(null, true)
    return
  # the previous frame
  f = frames[nextIdx - 2]
  dateKey = f.utc().format('MMDDYYYY')

  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)

  # throttle how many time the heatmap can be drawn
  throttleDraw = _.throttle(->
    heatmapLayerGroup.draw()
  , 750)

  # get the documents for this period
  #filteredDocuments = GritsHeatmapLayer.filteredDocuments(f, period, documents)
  filteredDocuments = documents[dateKey]

  async.eachSeries(filteredDocuments, (doc, next) ->
    if doc == null
      return
    id = CryptoJS.MD5(JSON.stringify(doc.loc)).toString()
    idx = GritsHeatmapLayer.findIndex(id)
    if idx >= 0
      count = doc.sightings?.reduce((sofar, sighting) ->
        if _.contains(tokens, sighting.bird_id)
          sofar + (sighting?.count or 0)
        else
          sofar
      , 0)
      location = _locations[idx]
      existing = location[2]
      if existing - count < 0
        location[2] = 0
      else
        location[2] = existing - count
      throttleDraw()
    async.nextTick(->
      next()
    )
  , (err) ->
    done(null, true)
  )

# pause the heatmap animation
GritsHeatmapLayer.pauseAnimation = ->
  GritsHeatmapLayer.animationPaused.set(true)

# stop the heatmap animation
GritsHeatmapLayer.stopAnimation = ->
  GritsHeatmapLayer.animationCompleted.set(true)
  GritsHeatmapLayer.animationRunning.set(false)
  GritsHeatmapLayer.animationPaused.set(false)
  async.nextTick ->
    clearInterval(_animation)
    _animation = null
    # TODO, we may want to clear the session counters and/or clear the map

# start the heatmap animation
#
# @note: this method sets the ReactiveVar for the animation: animationProgress, animationRunning, and animationFrame
# @param [Date] startDate, the startDate from the filter
# @param [Date] endDate, the endDate from the filter
# @param [String] period, the period determines the number of frames to the animation, 'days', 'weeks', 'months', 'years'
# @param [Array] documents, the array of GeoJSON documents from mongoDB
# @param [Array] tokens, the tokens from the filter
# @param [Number] offset, the offset from the filter
GritsHeatmapLayer.startAnimation = (startDate, endDate, period, flatMigrations, documents, tokens, offset) ->
  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
  heatmapLayerGroup.add()

  # Fit map to bounds of all locations
  locations = _.map flatMigrations, (doc) ->
    [doc.loc.coordinates[1], doc.loc.coordinates[0]]
  map.fitBounds(L.latLngBounds(locations))

  # if the offset is equal to zero, clear the layers
  if offset == 0
    heatmapLayerGroup.reset()

  # throttle how many time the heatmap can be drawn
  throttleDraw = _.throttle(->
    heatmapLayerGroup.draw()
  , 250)

  # throttle how many updates to the global session counter
  throttleCount = _.throttle((count) ->
    Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, count)
  , 250)

  # reset the locations
  GritsHeatmapLayer.resetLocations()

  # reset the reactive vars
  GritsHeatmapLayer.animationRunning.set(true)
  GritsHeatmapLayer.animationCompleted.set(false)
  GritsHeatmapLayer.animationPaused.set(false)

  # determine the range from the filter, this will drive the animation loop
  range = moment.range(startDate, endDate)
  frames = range.toArray(period)
  framesLen = frames.length
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
    paused = GritsHeatmapLayer.animationPaused.get()
    if paused
      return
    if processedFrames >= framesLen
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
        return
      # the animation has reached the end handle; stop
      else
        GritsHeatmapLayer.stopAnimation()
        return
    # check if the current scrubber caused a fast-forward
    if processedFrames < currentScrubber[0]
      processedFrames = currentScrubber[0]
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      return
    # check if the current scrubber caused a re-wind
    if lastScrubber != null and currentScrubber[0] < lastScrubber[0]
      processedFrames = currentScrubber[0]
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      lastScrubber = null
      return
    lastScrubber = currentScrubber
    # guard against frames that take longer to process than the interval
    if processedFrames == lastFrame
      console.log('too fast')
      return
    completed = GritsHeatmapLayer.animationCompleted.get()
    if !completed
      # the dateKey is the current animation frame identifier
      f = frames[processedFrames]
      # guard against timing issues from the next setInterval firing before the
      # current frame is done processing by setting lastFrame
      lastFrame = processedFrames
      dateKey = f.utc().format('MMDDYYYY')
      # set the ReactiveVar so the UI may listen to changes to the animation frame
      GritsHeatmapLayer.animationFrame.set(dateKey)
      # get the documents for this period
      filteredDocuments = documents[dateKey]
      processedLocations = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
      async.eachSeries filteredDocuments, (doc, next) ->
        if doc == null
          # we expect the null case for when there are no documents for the
          # date range.  call the next callback of the series and return.
          next()
          return
        # create the location based off the mongodb document
        GritsHeatmapLayer.createLocation(dateKey, doc, tokens)
        # limit how many times we perform the draw
        throttleDraw()
        # update the global counter
        throttleCount(++processedLocations)
        async.nextTick ->
          next()
      , (err) ->
        # final update the global counter
        Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, processedLocations)
        # set progress
        GritsHeatmapLayer.animationProgress.set((processedFrames + 1) / framesLen)
        # start decaying these locations after the FRAME_INTERVAL, but do not decay the last frame
        if (processedFrames + 1) < framesLen
          GritsHeatmapLayer.decrementPreviousLocations processedFrames, frames, period, documents, tokens, (err, res) ->
            # don't allow the animation to proceed until the previous frame has been decremented
            processedFrames++
        else
          processedFrames++
  , FRAME_INTERVAL

# get mirgations from mongo by an array of dates and token from the UI filter
#
# @param [Array] dates, the array of dates to match
# @param [String] token, the token from the filter
# @param [Number] limit, the limit from the filter
# @param [Number] offset, the offset from the filter
# @param [Function] done, callback when done
GritsHeatmapLayer.migrationsByDate = (dates, token, limit, offset, period, done) ->
  console.log('migrations by date')
  # show the loading indicator and call the server-side method
  GritsHeatmapLayer.animationRunning.set(true)
  async.auto({
    # get the totalRecords count first
    'getCount': (callback, result) ->
      Meteor.call('countMigrationsByDates', dates, token, (err, totalRecords) ->
        if (err)
          callback(err)
          return

        if Meteor.gritsUtil.debug
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

        if Meteor.gritsUtil.debug
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
    migrations = result.getMigrations

    # check if migrations is undefiend or empty
    if _.isUndefined(migrations) || _.isEmpty(migrations)
      toastr.info(i18n.get('toastMessages.noResults'))
      GritsHeatmapLayer.animationRunning.set(false)
      return

    # server is preprocessing the documents into frames, this concats this
    # object back into an array for ...
    flatMigrations = _.reduce(migrations, (frame, nextFrame) ->
      return frame.concat(nextFrame)
    , [])

    groupedResults = _.groupBy(flatMigrations, (result) ->
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
      MiniMigrations.insert(flatMigrations[i])
      i++

    # execute the callback to process the migrations
    done(null, {flatMigrations: flatMigrations, migrations: migrations})
    return
  )
  return
