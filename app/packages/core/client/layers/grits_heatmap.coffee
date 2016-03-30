HEATMAP_INTENSITY_MULTIPLIER = 1
FRAME_INTERVAL = 125 # milliseconds
_locations = [] # container to store heatmap data
_animation = null # stores the setInterval id of the animation

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

  # The heatmap library's gradient doesn't load until the map moves
  # so this moves the map slightly to make it load.
  _perturbMap: ->
    currentCenter = @_map.getCenter()
    @_map.setView(
      lat: currentCenter.lat + 1
      lng: currentCenter.lng + 1
    )
    @_map.setView(currentCenter)

  # draws the heatmap
  #
  # @note method overrides the parent class GritsLayer clear method
  # @override
  draw: ->
    # An extra point with no intensity is added because passing in an empty
    # array causes a bug where the previous heatmap is frozen in view.
    this._layer.setData(_locations.concat([[0.0, 0.0, 0.0]]))
    this._perturbMap()
    this.hasLoaded.set(true)
    return

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
    Tracker.autorun ->
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
    return self._locations

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

# find the index of the heatmap data matching dateKey and locationID
#
# @param [String] dateKey, the animation frame id
GritsHeatmapLayer.findIndex = (dateKey, locationID) ->
  idx = -1
  i = 0
  len = _locations.length
  while (i < len)
    d = _locations[i]
    if d[3] == dateKey && d[4] == locationID
      idx = i
      break
    i++
  return idx
# resets the array of locations
GritsHeatmapLayer.resetLocations = ->
  _locations = []
  return
# creates a migration location element based on a mongodb document
#
# @param [String] dateKey, the current animation frame
# @param [Array] doc, the GeoJSON mongoDB document
# @param [Array] tokens, the tokens from the filter
GritsHeatmapLayer.createLocation = (dateKey, doc, tokens) ->
  id = CryptoJS.MD5(JSON.stringify(doc.loc)).toString()
  count = 0
  _.map(tokens, (t) ->
    if doc.hasOwnProperty(t)
      count += doc[t] / 1000
  )
  idx = GritsHeatmapLayer.findIndex(dateKey, id)
  if idx < 0
    location = [] # create new location if undefined
    location.push(doc.loc.coordinates[1])
    location.push(doc.loc.coordinates[0])
    location.push(count) # the count for this date
    location.push(dateKey)
    location.push(id)
    _locations.push(location)
  else
    # do we have a count for this date?
    location = _locations[idx]
    location[2] += count # increment by the count

# filter migration records by dateKey
#
# @param [Date] f, the current animation frame date
# @param [String] period, the interval/period from the UI 'days', 'months', 'weeks', 'years'
# @param [Array] documents, the array of documents to be filtered
# @return [Array] filteredDocuments, an array of filtered documents base on date
GritsHeatmapLayer.filteredDocuments = (f, period, documents) ->
  return _.filter(documents, (doc) ->
    d = moment(doc.date)
    if period == 'years'
      if d.year() == f.year()
        return doc
    if period == 'months'
      if d.month() == f.month() && d.year() == f.year()
        return doc
    if period == 'weeks'
      if d.weeks() == f.weeks() && d.year() == f.year()
        return doc
    if period == 'days'
      if d.date() == f.date() && d.month() == f.month() && d.year() == f.year()
        return doc
  )

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
  , 250)

  # get the documents for this period
  filteredDocuments = GritsHeatmapLayer.filteredDocuments(f, period, documents)

  async.eachSeries(filteredDocuments, (doc, next) ->
    if doc == null
      return
    id = CryptoJS.MD5(JSON.stringify(doc.loc)).toString()
    idx = GritsHeatmapLayer.findIndex(dateKey, id)
    if idx >= 0
      count = 0
      _.map(tokens, (t) ->
        if doc.hasOwnProperty(t)
          count += doc[t] / 1000
      )
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
GritsHeatmapLayer.pauseAnimation = () ->
  GritsHeatmapLayer.animationPaused.set(true)

# stop the heatmap animation
GritsHeatmapLayer.stopAnimation = () ->
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
GritsHeatmapLayer.startAnimation = (startDate, endDate, period, documents, tokens, offset) ->
  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
  heatmapLayerGroup.add()

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

  # get the current count, may not be zero in case of a limit/offset
  count = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)

  # reset the locations
  GritsHeatmapLayer.resetLocations()

  # reset the reactive vars
  GritsHeatmapLayer.animationProgress.set(0)
  GritsHeatmapLayer.animationRunning.set(true)
  GritsHeatmapLayer.animationCompleted.set(false)
  GritsHeatmapLayer.animationPaused.set(false)

  # determine the range from the filter, this will drive the animation loop
  range = moment.range(startDate, endDate)
  frames = range.toArray(period)
  framesLen = frames.length
  lastFrame = null

  # the animation is uses setInterval
  processedFrames = 0
  _animation = setInterval(->
    paused = GritsHeatmapLayer.animationPaused.get()
    if paused
      console.log('paused: ', paused)
      return
    if processedFrames >= framesLen
      GritsHeatmapLayer.stopAnimation()
      return
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
      filteredDocuments = GritsHeatmapLayer.filteredDocuments(f, period, documents)
      processedLocations = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
      async.eachSeries(filteredDocuments, (doc, next) ->
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
        async.nextTick(->
          next()
        )
      , (err) ->
        # final update the global counter
        Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, processedLocations)
        # set progress
        GritsHeatmapLayer.animationProgress.set(processedFrames/framesLen)
        # start decaying these locations after the FRAME_INTERVAL, but do not decay the last frame
        if (processedFrames + 1) < framesLen
          GritsHeatmapLayer.decrementPreviousLocations(processedFrames, frames, period, documents, tokens, (err, res) ->
            # don't allow the animation to proceed until the previous frame has been decremented
            processedFrames++
            console.log('processedFrames: ', processedFrames)
            console.log('processedLocations: ', processedLocations)
          )
        else
          processedFrames++
          console.log('processedFrames: ', processedFrames)
          console.log('processedLocations: ', processedLocations)
      )
  , FRAME_INTERVAL)

# get mirgations from mongo by an array of dates and token from the UI filter
#
# @param [Array] dates, the array of dates to match
# @param [String] token, the token from the filter
# @param [Number] limit, the limit from the filter
# @param [Number] offset, the offset from the filter
# @param [Function] done, callback when done
GritsHeatmapLayer.migrationsByDate = (dates, token, limit, offset, done) ->
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
GritsHeatmapLayer.migrationsByDateRange = (startDate, endDate, token, limit, offset, done) ->
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
      Meteor.call('migrationsByQuery', startDate, endDate, token, limit, offset, callback)
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

    # execute the callback to process the migrations
    done(null, migrations)
    return
  )
  return
