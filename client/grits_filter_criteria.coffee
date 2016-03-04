_ignoreFields = ['limit', 'offset'] # fields that are used for maintaining state but will be ignored when sent to the server
_validFields = ['startDate', 'endDate', 'limit', 'offset']
_validOperators = ['$gte', '$gt', '$lte', '$lt', '$eq', '$ne', '$in', '$near', null]
_state = null # keeps track of the query string state
# local/private minimongo collection
_Collection = new (Mongo.Collection)(null)
# local/private Astronomy model for maintaining filter criteria
_Filter = Astro.Class(
  name: 'FilterCriteria'
  collection: _Collection
  transform: true
  fields: ['key', 'operator', 'value']
  validators: {
    key: [
        Validators.required(),
        Validators.string()
    ],
    operator: [
        Validators.required(),
        Validators.string(),
        Validators.choice(_validOperators)
    ],
    value: Validators.required()
  }
)

# GritsFilterCriteria, this object provides the interface for
# accessing the UI filter box. The setter methods may be called
# programmatically or the reactive var can be set by event handers
# within the UI.  The entire object maintains its own state.
#
# @note exports as a 'singleton'
class GritsFilterCriteria
  constructor: () ->
    self = this

    # reactive var used to update the UI when the query state has changed
    self.stateChanged = new ReactiveVar(null)

    # setup an instance variable that contains todays date.  This will be used
    # to set the initial Start and End dates to the Operating Date Range
    now = new Date()
    month = now.getMonth()
    date = now.getDate()
    year = now.getFullYear()
    self._today = new Date(year, month, date)
    # this._baseState keeps track of the initial plugin state after any init
    # methods have run
    self._baseState = {}

    # processing queue
    self._queue = null

    # reactive vars to track form binding
    #   tokens from the search bar
    self.tokens = new ReactiveVar([])
    self.trackTokens()

    #   operatingDateRangeStart
    self.operatingDateRangeStart = new ReactiveVar(null)
    self.trackOperatingDateRangeStart()
    #   operatingDateRangeEnd
    self.operatingDateRangeEnd = new ReactiveVar(null)
    self.trackOperatingDateRangeEnd()

    #   limit
    self.limit = new ReactiveVar(1000)
    self.trackLimit()

    #   offset
    self.offset = new ReactiveVar(0)

    # airportCounts
    # during a simulation the airports are counted to update the heatmap
    self.airportCounts = {}

    # is the simulation running?
    self.isSimulatorRunning = new ReactiveVar(false)
    return
  # initialize the start date of the filter 'discontinuedDate'
  #
  # @return [String] dateString, formatted MM/DD/YY
  initStart: () ->
    self = this
    #start = self._today
    start = new Date(2002, 0, 1)
    self.createOrUpdate('startDate', {key: 'startDate', operator: '$gte', value: start})
    query = @getQueryObject()
    # update the state logic for the indicator
    _state = JSON.stringify(query)
    self._baseState = JSON.stringify(query)
    month = start.getMonth() + 1
    date = start.getDate()
    year = start.getFullYear().toString().slice(2,4)
    year = start.getFullYear()
    yearStr = year.toString().slice(2,4)
    self.operatingDateRangeStart.set(new Date(year, month, date))
    return "#{month}/#{date}/#{yearStr}"
  # initialize the end date through the 'effectiveDate' filter
  #
  # @return [String] dateString, formatted MM/DD/YY
  initEnd: () ->
    self = this
    #end = moment(@_today).add(7, 'd').toDate()
    end = new Date(2002, 2, 30)
    self.createOrUpdate('endDate', {key: 'endDate', operator: '$lt', value: end})
    # get the query object
    query = self.getQueryObject()
    # update the state logic for the indicator
    _state = JSON.stringify(query)
    self._baseState = JSON.stringify(query)
    month = end.getMonth() + 1
    date = end.getDate()
    year = end.getFullYear()
    yearStr = year.toString().slice(2,4)
    self.operatingDateRangeEnd.set(new Date(year, month, date))
    return "#{month}/#{date}/#{yearStr}"
  # initialize the limit through the 'effectiveDate' filter
  #
  # @return [Integer] limit
  initLimit: () ->
    self = this
    initLimit = self.limit.get()
    self.setLimit(initLimit)
    self._baseState = JSON.stringify(self.getQueryObject())
    return initLimit
  # Creates a new filter criteria and adds it to the collection or updates
  # the collection if it already exists
  #
  # @param [String] id, the name of the filter criteria
  # @return [Object] Astronomy model 'FilterCriteria'
  createOrUpdate: (id, fields) ->
    self = this
    if _.indexOf(_validFields, id) < 0
      throw new Error('Invalid filter: ' + id)
    obj = _Collection.findOne({_id: id})
    if obj
      obj.set(fields)
      if obj.validate() == false
        throw new Error(_.values(obj.getValidationErrors()))
      obj.save()
      return obj
    else
      _.extend(fields, {_id: id})
      obj = new _Filter(fields)
      if obj.validate() == false
        throw new Error(_.values(obj.getValidationErrors()))
      obj.save()
      return obj
  # removes a FilterCriteria from the collection
  #
  # @param [String] id, the name of the filter criteria
  # @optional [Function] cb, the callback method if removing async
  remove: (id, cb) ->
    self = this
    obj = _Collection.findOne({_id: id})
    if obj and cb
      obj.remove(cb)
      return
    if obj
      return obj.remove()
    else
      return 0
  # returns the query object used to filter the server-side collection
  #
  # @return [Object] query, a mongoDB query object
  getQueryObject: () ->
    self = this
    criteria = _Collection.find({})
    result = {}
    criteria.forEach((filter) ->
      value = {}
      k = filter.get('key')
      o = filter.get('operator')
      v = filter.get('value')
      if _.indexOf(['$eq'], o) >= 0
        value = v
      else
        value[o] = v
      result[k] = value
    )
    return result
  # compares the current state vs. the original/previous state
  compareStates: () ->
    self = this
    # postone execution to avoid 'flash' for the fast draw case.  this happens
    # when the user clicks a node or presses enter on the search and the
    # draw completes faster than the debounce timeout
    async.nextTick(() ->
      current = self.getCurrentState()
      if current != _state
        # do not notifiy on an empty query or the base state
        if current == "{}" || current == self._baseState
          self.stateChanged.set(false)

        else
          self.stateChanged.set(true)
          # disable [More...] button when filter has changed
          $('#loadMore').prop('disabled', true)
      else
        self.stateChanged.set(false)
    )
    return
  # gets the current state of the filter
  #
  # @return [String] the query object JSON.strigify
  getCurrentState: () ->
    self = this
    query = self.getQueryObject()
    return JSON.stringify(query)
  # get the original/previous state of the filter
  #
  # @return [String] the query object JSON.strigify
  getState: () ->
    _state
  # sets the original/previous state of the filter, this method will read the
  # current query object and store is as a JSON string
  setState: () ->
    self = this
    query = self.getQueryObject()
    _state = JSON.stringify(query)
    return
  # process the results of the meteor methods to get flights
  #
  # @param [Array] migrations, an Array of migrations to process
  # @param [Integer] offset, the offset of the query
  process: (migrations, token, offset) ->
    self = this
    if self._queue != null
      self._queue.kill()
      async.nextTick(() ->
        self._queue = null
      )

    map = Template.gritsMap.getInstance()
    #layerGroup = GritsLayerGroup.getCurrentLayerGroup()
    heatmapLayerGroup = Template.gritsMap.getInstance().getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
    # if the offset is equal to zero, clear the layers
    if offset == 0
      #layerGroup.reset()
      heatmapLayerGroup.reset()

    count = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)

    # reset the locations
    self.locations = {}

    updateHeatmap = _.throttle(->
      heatmapLayerGroup.processLocations(self.locations)
    , 500)

    throttleDraw = _.throttle(->
      heatmapLayerGroup.draw()
    , 500)

    self._queue = async.queue(((migration, callback) ->
      setTimeout(() ->
        id = CryptoJS.MD5(JSON.stringify(migration.loc)).toString()
        location = self.locations[id]
        if typeof location == 'undefined'
          self.locations[id] = {
            count: migration[token]
            loc: migration.loc
          }
        else
          location.count += migration[token]

        updateHeatmap()
        # update the layer
        throttleDraw()
        # update the counter
        Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS , ++count)
        # done processing
        async.nextTick(-> callback())
      , migrations.length / 20)
    ), 4)

    # final method for when all items within the queue are processed
    self._queue.drain = ->
      #layerGroup.finish()
      heatmapLayerGroup.finish()
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, count)
      Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)

    # add the migrations to thet queue which will start processing
    self._queue.push(migrations)
    return
  # applies the filter but does not reset the offset
  #
  # @param [Function] cb, the callback function
  more: (cb) ->
    self = this

    # applying the filter is always EXPLORE mode
    Session.set(GritsConstants.SESSION_KEY_MODE, GritsConstants.MODE_EXPLORE)

    query = self.getQueryObject()
    token = self.tokens.get()[0]

    if _.isUndefined(token)
      toastr.error(i18n.get('toastMessages.searchTokenRequired'))
      Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
      return;

    # set the state
    self.setState()
    self.compareStates()

    # set the arguments
    limit = query.limit
    offset = self.offset.get()

    # remove the ignoreFields from the query
    _.each(_ignoreFields, (field) ->
      if query.hasOwnProperty(field)
        delete query[field]
    )

    # show the loading indicator and call the server-side method
    Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, true)
    async.auto({
      # get the totalRecords count first
      'getCount': (callback, result) ->
        Meteor.call('countMigrationsByDateRange', query.startDate, query.endDate, token, (err, totalRecords) ->
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
          Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
          callback(null)
          return

        Meteor.call('migrationsByQuery', query.startDate, query.endDate, token, limit, offset, (err, migrations) ->
          if (err)
            callback(err)
            return

          if _.isUndefined(migrations) || migrations.length <= 0
            toastr.info(i18n.get('toastMessages.noResults'))
            Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
            callback(null, [])
            return

          callback(null, migrations)
        )
      ]
    }, (err, result) ->
      if err
        Meteor.gritsUtil.errorHandler(err)
        return
      # if there hasn't been any errors, getCount and getMigrations will
      # have completed
      migrations = result.getMigrations
      # call the original callback function if its defined
      if cb && _.isFunction(cb)
        cb(null, migrations)
      # process the migrations
      console.log(migrations)
      self.process(migrations, token, offset)
      return
    )
    return
  # applies the filter; resets the offset, loadedRecords, and totalRecords
  #
  # @param [Function] cb, the callback function
  apply: (cb) ->
    self = this
    self.offset.set(0)
    # allow the reactive var to be set before continue
    async.nextTick(() ->
      # reset the loadedRecords and totalRecords
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, 0)
      # re-enable the loadMore button when a new filter is applied
      $('#loadMore').prop('disabled', false)
      # pass the callback function if its defined
      if cb && _.isFunction(cb)
        self.more(cb)
      else
        self.more()
    )
    return
  # sets the 'start' date from the filter and updates the filter criteria
  #
  # @param [Object] date, Date object or null to clear the criteria
  setOperatingDateRangeStart: (date) ->
    self = this

    # do not allow this to run prior to jQuery/DOM
    if _.isUndefined($)
      return
    discontinuedDatePicker = Template.gritsSearch.getDiscontinuedDatePicker()
    if _.isNull(discontinuedDatePicker)
      return

    discontinuedDate = discontinuedDatePicker.data('DateTimePicker').date()

    if _.isNull(date) || _.isNull(discontinuedDate)
      if _.isEqual(date, discontinuedDate)
        self.remove('startDate')
      else
        discontinuedDatePicker.data('DateTimePicker').date(null)
        self.operatingDateRangeStart.set(null)
      return

    if _.isEqual(date.toISOString(), discontinuedDate.toISOString())
      # the reactive var is already set, change is from the UI
      self.createOrUpdate('startDate', {key: 'startDate', operator: '$gte', value: discontinuedDate})
    else
      discontinuedDatePicker.data('DateTimePicker').date(date)
      self.operatingDateRangeStart.set(date)
    return
  trackOperatingDateRangeStart: () ->
    self = this
    Tracker.autorun ->
      obj = self.operatingDateRangeStart.get()
      self.setOperatingDateRangeStart(obj)
      async.nextTick(() ->
        self.compareStates()
      )
    return
  # sets the 'end' date from the filter and updates the filter criteria
  #
  # @param [Object] date, Date object or null to clear the criteria
  setOperatingDateRangeEnd: (date) ->
    self = this

    # do not allow this to run prior to jQuery/DOM
    if _.isUndefined($)
      return
    effectiveDatePicker = Template.gritsSearch.getEffectiveDatePicker()
    if _.isNull(effectiveDatePicker)
      return

    effectiveDate = effectiveDatePicker.data('DateTimePicker').date()

    if _.isNull(date) || _.isNull(effectiveDate)
      if _.isEqual(date, effectiveDate)
        self.remove('endDate')
      else
        effectiveDatePicker.data('DateTimePicker').date(null)
        self.operatingDateRangeEnd.set(null)
      return

    if _.isEqual(date.toISOString(), effectiveDate.toISOString())
      # the reactive var is already set, change is from the UI
      self.createOrUpdate('endDate', {key: 'endDate', operator: '$lt', value: effectiveDate})
    else
      effectiveDatePicker.data('DateTimePicker').date(date)
      self.operatingDateRangeEnd.set(date)
    return
  trackOperatingDateRangeEnd: () ->
    self = this
    Tracker.autorun ->
      obj = self.operatingDateRangeEnd.get()
      self.setOperatingDateRangeEnd(obj)
      async.nextTick(() ->
        self.compareStates()
      )
    return
  trackTokens: () ->
    self = this
    Tracker.autorun ->
      obj = self.tokens.get()
      if _.isEmpty(obj)
        # checks are necessary as Tracker autorun will fire before the DOM
        # is ready and the Template.gritsMap.onRenered is called
        if !(_.isUndefined(Template.gritsMap) || _.isUndefined(Template.gritsMap.getInstance))
          map = Template.gritsMap.getInstance()
          if !_.isNull(map)
            layerGroup = GritsLayerGroup.getCurrentLayerGroup()
            # clears the sub-layers and resets the layer group
            if layerGroup != null
              layerGroup.reset()
    return
  # sets the limit input on the UI to the 'value'
  # specified, as well as, updating the underlying FilterCriteria.
  #
  # @note This is not part of the query, but is included to maintain the UI state.  Upon 'apply' the value is deleted from the query and used as an arguement to the server-side method
  # @param [Integer] value
  setLimit: (value) ->
    self = this

    # do not allow this to run prior to jQuery/DOM
    if _.isUndefined($)
      return

    if _.isUndefined(value)
      throw new Error('Limit must be defined.')

    if _.isEqual(self.limit.get(), value)
      if _.isNull(value)
        self.remove('limit')
      else
        val = Math.floor(parseInt(value, 10))
        if isNaN(val) or val < 1
          throw new Error('Limit must be positive')
        self.createOrUpdate('limit', {key: 'limit', operator: '$eq', value: val})
    else
      self.limit.set(value)
    return
  trackLimit: () ->
    self = this
    Tracker.autorun ->
      obj = self.limit.get()
      try
        self.setLimit(obj)
        async.nextTick(() ->
          self.compareStates()
        )
      catch e
        Meteor.gritsUtil.errorHandler(e)
    return
  # sets the offest as calculated by the current query that has more results
  # than the limit
  #
  # @note This is not part of the query, but is included to maintain the UI state.  Upon 'apply' the value is deleted from the query and used as an arguement to the server-side method
  setOffset: () ->
    self = this
    # do not allow this to run prior to jQuery/DOM
    if _.isUndefined($)
      return

    totalRecords = Session.get(GritsConstants.SESSION_KEY_TOTAL_RECORDS)
    loadedRecords = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)

    if (loadedRecords < totalRecords)
      self.offset.set(loadedRecords)
    else
      self.offset.set(0)
    return

GritsFilterCriteria = new GritsFilterCriteria() # exports as a singleton
