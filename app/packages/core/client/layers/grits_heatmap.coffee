HEATMAP_INTENSITY_MULTIPLIER = 1
FRAME_INTERVAL = 2500 # milliseconds
_locations = {} # container to store migration locations

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
    self._data = []

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
  _perturbMap: ()->
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
  draw: () ->
    self = this
    data = self._data.map((d)->
      [d[0], d[1], d[2] * HEATMAP_INTENSITY_MULTIPLIER]
    )
    # An extra point with no intensity is added because passing in an empty
    # array causes a bug where the previous heatmap is frozen in view.
    self._layer.setData(data.concat([[0.0, 0.0, 0.0]]))
    self._perturbMap()
    self.hasLoaded.set(true)
    return

  # clears the heatmap
  #
  # @note method overrides the parent class GritsLayer clear method
  # @override
  clear: () ->
    self = this
    self._data = []
    self._layer.setData(self._data)
    self.hasLoaded.set(false)
    return

  _trackTokens: () ->
    self = this
    Tracker.autorun ->
      tokens = GritsFilterCriteria.tokens.get()
      if tokens.length == 0
        self.clear()

  # update the heatmap data for each location
  #
  # @param [String] dateKey, the animation frame id
  updateLocations: (dateKey) ->
    self = this
    locations = _.filter(_locations, (location) -> location.hasOwnProperty(dateKey))
    if self._data.length == 0
      # the heatmap doesn't have any data, all locations need pushed into the array
      _.each(locations, (location) ->
        self._data.push([location.loc.coordinates[1], location.loc.coordinates[0], location[dateKey]/1000, dateKey, location.id])
      )
    else
      # each location within the heatmap array needs its count updated
      _.each(locations, (location) ->
        elements = _.filter(self._data, (d) -> return d[3] == dateKey && d[4] == location.id)
        if elements.length > 0
          _.each(elements, (element) ->
            element[2] = location[dateKey]/1000
          )
        else
          self._data.push([location.loc.coordinates[1], location.loc.coordinates[0], location[dateKey]/1000, dateKey, location.id])
      )

  # get the heatmap data
  #
  # @return [Array] array of the heatmap data
  getData: () ->
    self = this
    if _.isEmpty(self._data)
      return []
    return self._data

  # binds to the Tracker.gritsMap.getInstance() map event listener .on
  # 'overlyadd' and 'overlayremove' methods
  _bindMapEvents: () ->
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
# find a migration location
#
# @param [String] id, the uniqued id of the location (md5 hash of GeoJSON coordinates)
# @return [Object] location, the location object
GritsHeatmapLayer.findLocation = (id) ->
  if _locations.hasOwnProperty(id)
    return _metaNodes[id]
  else
    return null
# resets the set of locations
GritsHeatmapLayer.resetLocations = () ->
  _locations = {}
  return
# creates a migration location based on a mongodb document
#
# @param [String] dateKey, the current animation frame
# @param [Array] doc, the GeoJSON mongoDB document
# @param [String] token, the token from the filter
GritsHeatmapLayer.createLocation = (dateKey, doc, token) ->
  id = CryptoJS.MD5(JSON.stringify(doc.loc)).toString()
  count = doc[token] # the count that is embedded into the mongo document
  location = _locations[id] # see if a location already exists
  if typeof location == 'undefined'
    location = {} # create new location if undefined
    location[dateKey] = count # the count for this date
    location.loc = doc.loc # the coordinates of the location
    location.id = id
    _locations[id] = location # store into the collection
  else
    # do we have a count for this date?
    if location.hasOwnProperty(dateKey)
      location[dateKey] += count # increment by the count
    else
      # set the initial date count
      location[dateKey] = count
# decrements the value of the locations
#
# @param [String] dateKey, the current animation frame
# @param [Array] documents, the array of GeoJSON documents from mongoDB
# @param [String] token, the token from the filter
GritsHeatmapLayer.decayLocations = (dateKey, documents, token) ->
  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)

  # throttle how many time the heatmap can be drawn
  throttleDraw = _.throttle((dateKey) ->
    heatmapLayerGroup.updateLocations(dateKey)
    heatmapLayerGroup.draw()
  , 250)

  interval = FRAME_INTERVAL/documents.length
  async.eachSeries(documents, (doc, next) ->
    if doc == null
      return
    setTimeout(->
      id = CryptoJS.MD5(JSON.stringify(doc.loc)).toString()
      _.each(_locations, (location) ->
        if location.id == id && location.hasOwnProperty(dateKey)
          location[dateKey] -= doc[token]
      )
      throttleDraw(dateKey)
      next()
    , interval)
  )
# start the heatmap animation
#
# @note: this method sets the ReactiveVar for the animation: animationProgress, animationRunning, and animationFrame
# @param [Date] startDate, the startDate from the filter
# @param [Date] endDate, the endDate from the filter
# @param [String] period, the period determines the number of frames to the animation, 'days', 'weeks', 'months', 'years'
# @param [Array] documents, the array of GeoJSON documents from mongoDB
# @param [String] token, the token from the filter
# @param [Number] offset, the offset from the filter
GritsHeatmapLayer.startAnimation = (startDate, endDate, period, documents, token, offset) ->
  # the GritsMap instance
  map = Template.gritsMap.getInstance()
  heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)

  # if the offset is equal to zero, clear the layers
  if offset == 0
    heatmapLayerGroup.reset()

  # throttle how many time the heatmap can be drawn
  throttleDraw = _.throttle((dateKey) ->
    heatmapLayerGroup.updateLocations(dateKey)
    heatmapLayerGroup.draw()
  , 250)

  # throttle how many updates to the global session counter
  throttleCount = _.throttle((count) ->
    Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS , count)
  , 250)

  # get the current count, may not be zero in case of a limit/offset
  count = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)

  # reset the locations
  GritsHeatmapLayer.resetLocations()

  # reset the reactive vars
  GritsHeatmapLayer.animationProgress.set(0)
  GritsHeatmapLayer.animationRunning.set(true)

  # determine the range from the filter, this will drive the animation loop
  range = moment.range(startDate, endDate)
  # get the frames of the range, currently this is by month.  the UI could show
  # a dropdown to change this value
  frames = range.toArray(period)

  # the animation is uses setTimeout, which is an asynchronous call in
  # JavaScript.  async.eachSeries is used to block until each animation frame
  # is complete.
  processed = 1
  async.eachSeries(frames, (f, nextOuter) ->
    # the dateKey is the current animation frame identifier
    dateKey = f.utc().format('MMDDYYYY')
    # set the ReactiveVar so the UI may listen to changes to the animation frame
    GritsHeatmapLayer.animationFrame.set(dateKey)
    # get the documents for this period
    filteredDocuments = _.filter(documents, (doc) ->
      d = moment.utc(doc.date)
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
    console.log('dateKey: ', dateKey)
    console.log('filteredDocuments: ', filteredDocuments)
    # determine the animation interval by dividing by the lenght of
    # filteredDocuments
    if filteredDocuments.length == 0
      filteredDocuments.push(null)
      interval = FRAME_INTERVAL
    else
      interval = FRAME_INTERVAL/filteredDocuments.length
    async.eachSeries(filteredDocuments, (doc, nextInner) ->
      setTimeout(()->
        if doc == null
          # we expect the null case for when there are no documents for the
          # date range.  call the next callback of the series and return.
          nextInner()
          return
        GritsHeatmapLayer.createLocation(dateKey, doc, token)
        # limit how many times we perform the draw
        throttleDraw(dateKey)
        # update the global counter
        throttleCount(++count)
        # allow next iteration of the eachSeries to animate by calling the
        # nextInner() callback
        nextInner()
      , interval)
    , (err) ->
      # the inner eachSeries is complete
      GritsHeatmapLayer.animationProgress.set(processed/frames.length)
      processed++
      # now that the eachSeries within the closure is done we can release the
      # outer eachSeries to continue
      nextOuter()
      # do not decay the last frame
      if (processed - 1) != frames.length
        # start decaying these locations after the FRAME_INTERVAL
        setTimeout(->
          GritsHeatmapLayer.decayLocations(dateKey, filteredDocuments, token)
        , FRAME_INTERVAL)
    )
  , (err) ->
    # the outer eachSeries is complete
    GritsHeatmapLayer.animationRunning.set(false)
  )


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
      if totalRecords.length <= 0
        toastr.info(i18n.get('toastMessages.noResults'))
        GritsHeatmapLayer.animationRunning.set(false)
        callback(null)
        return

      Meteor.call('migrationsByDates',dates, token, limit, offset, (err, migrations) ->
        if (err)
          callback(err)
          return

        if _.isUndefined(migrations) || migrations.length <= 0
          toastr.info(i18n.get('toastMessages.noResults'))
          GritsHeatmapLayer.animationRunning.set(false)
          callback(null, [])
          return

        callback(null, migrations)
      )
    ]
  }, (err, result) ->
    if err
      GritsHeatmapLayer.animationRunning.set(false)
      Meteor.gritsUtil.errorHandler(err)
      return
    # if there hasn't been any errors, getCount and getMigrations will
    # have completed
    migrations = result.getMigrations
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

      if totalRecords.length <= 0
        toastr.info(i18n.get('toastMessages.noResults'))
        GritsHeatmapLayer.animationRunning.set(false)
        callback(null)
        return

      Meteor.call('migrationsByQuery', startDate, endDate, token, limit, offset, (err, migrations) ->
        if (err)
          callback(err)
          return

        if _.isUndefined(migrations) || migrations.length <= 0
          toastr.info(i18n.get('toastMessages.noResults'))
          GritsHeatmapLayer.animationRunning.set(false)
          callback(null, [])
          return

        callback(null, migrations)
      )
    ]
  }, (err, result) ->
    if err
      GritsHeatmapLayer.animationRunning.set(false)
      Meteor.gritsUtil.errorHandler(err)
      return
    # if there hasn't been any errors, getCount and getMigrations will
    # have completed
    migrations = result.getMigrations
    # execute the callback to process the migrations
    done(null, migrations)
    return
  )
  return
