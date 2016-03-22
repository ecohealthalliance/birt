# Template.gritsSearch
#
# When another meteor app adds grits:grits-net-meteor as a package
# Template.gritsSearch will be available globally.
_init = true # flag, set to false when initialization is done
_initStartDate = null # onCreated will initialize the date through GritsFilterCriteria
_initEndDate = null # onCreated will initialize the date through GritsFilterCriteria
_initLimit = null # onCreated will initialize the limt through GritsFilterCriteria
_departureSearchMain = null # onRendered will set this to a typeahead object
_effectiveDatePicker = null # onRendered will set this to a datetime picker object
_discontinuedDatePicker = null # onRendered will set this to a datetime picker object
_compareDatePicker = null # onRendered will set this to a datetime picker object
_lastPeriod = 'months' # remember the last selected period when enable/disable compare date over interval, defaults to 'months'
_animationRunning = new ReactiveVar(false)
_matchSkip = null # the amount to skip during typeahead pagination
_simulationProgress = new ReactiveVar(0)
_disableLimit = new ReactiveVar(false) # toggle if we will allow limit/skip
_suggestionTemplate = _.template('
  <span class="typeahead-code"><%= raw._id %></span><br/>
  <span class="typeahead-info">
    <%= raw.primary_com_name %>
    <% if (display) { %>
      <span class="typeahead-additional-info">
        <span><%= display %>:</span> <%= value %>
      <span>
    <% } %>
  </span>')
# Unfortunately we need to result to jQuery as twitter's typeahead plugin does
# not allow us to pass in a custom context to the footer.  <%= obj.query %> and
# <%= obj.isEmpty %> are the only things available.
_typeaheadFooter = _.template('
  <div class="typeahead-footer">
    <div class="row">
      <div class="col-xs-6 pull-middle">
        <span id="suggestionCount"></span>
      </div>
      <div class="col-xs-6 pull-middle">
        <ul class="pager">
          <li class="previous-suggestions">
            <a href="#" id="previousSuggestions">Previous</a>
          </li>
          <li class="next-suggestions">
            <a href="#" id="forwardSuggestions">Forward</a>
          </li>
        </ul>
      </div>
    </div>
  </div>')

# returns the first origin within GritsFilterCriteria
#
# @return [String] origin, a string airport IATA code
getOrigin = ->
  query = GritsFilterCriteria.getQueryObject()
  if _.has(query, 'departureAirport._id')
    # the filter has an array of airports
    if _.has(query['departureAirport._id'], '$in')
      origins = query['departureAirport._id']['$in']
      if _.isArray(origins) and origins.length > 0
        return origins[0]
  return null

# returns the typeahead object for the '#departureSearchMain' input
#
# @see: http://sliptree.github.io/bootstrap-tokenfield/#methods
# @return [Object] typeahead
getDepartureSearchMain = ->
  return _departureSearchMain

# sets the typeahead object for the '#departureSearchMain' input
_setDepartureSearchMain = (typeahead) ->
  _departureSearchMain = typeahead
  return

# returns the datetime picker object for the '#effectiveDate' input  with the label 'End'
#
# @see http://eonasdan.github.io/bootstrap-datetimepicker/Functions/
# @return [Object] datetimePicker object
getEffectiveDatePicker = ->
  return _effectiveDatePicker

# sets the datetime picker object for the '#effectiveDate' input with the label 'End'
_setEffectiveDatePicker = (datetimePicker) ->
  _effectiveDatePicker = datetimePicker
  return

# returns the datetime picker object for the '#discontinuedDate' input with the label 'Start'
#
# @see http://eonasdan.github.io/bootstrap-datetimepicker/Functions/
# @return [Object] datetimePicker object
getDiscontinuedDatePicker = ->
  return _discontinuedDatePicker

# sets the datetime picker object for the '#discontinuedDate' input
_setDiscontinuedDatePicker = (datetimePicker) ->
  _discontinuedDatePicker = datetimePicker
  return

# returns the datetime picker object fro the '#compareDateOverPeriod' input with the label 'Compare Single Date'
getCompareDatePicker = ->
  return _compareDatePicker

# sets the datetime picker object for the '#compareDateOverPeriod'
_setCompareDatePicker = (datetimePicker) ->
  _compareDatePicker = datetimePicker
  return

# determines which field was matched by the typeahead into the server response
#
# @param [String] input, the string used as the search
# @param [Array] results, the server response
# @return [Array] array of matches, with all properties of the model to be available in the suggestion template under the key 'raw'.
_determineFieldMatchesByWeight = (input, res) ->
  numComparator = (a, b) ->
    a - b
  strComparator = (a, b) ->
    if a < b
      return -1
    if a > b
      return 1
    return 0
  compare = (a, b) ->
    return strComparator(a.label, b.label) || numComparator(a.weight, b.weight)

  matches = []
  for obj in res
    # get the typeahead matcher from the Astro Class, contains weight, display
    # and regexOptions
    typeaheadMatcher = Bird.typeaheadMatcher()
    for field, matcher of typeaheadMatcher
      regex = new RegExp(matcher.regexSearch({search: input}), matcher.regexOptions)
      value = obj[field]
      # cannot match on an empty value
      if _.isEmpty(value)
        continue
      # apply the regex to the value
      if value.match(regex) != null
        # determine if its a previous match
        match = _.find(matches, (m) -> m.label == obj._id)
        # if not, create a new object and assign the properties
        # note: prefix is added to avoid possible confict with the class fields
        # that are extended.
        if _.isUndefined(match)
          match =
            label: obj._id
            value: value
            field: field
            weight: matcher.weight
            display: matcher.display
            raw: obj
          matches.push(match)
          continue
        else
          # Previous match exists, update the values if its of heigher weight
          if matcher.weight > match.weight
            match.value = value
            match.field = field
            match.weight = matcher.weight
            match.display = matcher.display
  if Meteor.gritsUtil.debug
    console.log('matches:', matches)
  return matches

# method to generate suggestions and drive the pagination feature
_suggestionGenerator = (query, skip, callback) ->
  _matchSkip = skip
  Meteor.call('typeahead', 'birds', query, skip, (err, res) ->
    Meteor.call('countTypeaheadBirds', query, (err, count) ->
      if res.length > 0
        matches = _determineFieldMatchesByWeight(query, res)
        # expects an array of objects with keys [label, value]
        callback(matches)

      # keep going to update the _typeaheadFooter via jQuery
      # update the record count
      if count > 1
        if (_matchSkip + 10) > count
          diff = (_matchSkip + 10) - count
          $('#suggestionCount').html("<span>Matches #{_matchSkip+1}-#{_matchSkip+(10-diff)} of #{count}</span>")
        else
          $('#suggestionCount').html("<span>Matches #{_matchSkip+1}-#{_matchSkip+10} of #{count}</span>")
      else if count == 1
        $('#suggestionCount').html("<span>#{count} match found</span>")
      else
        $('.tt-suggestions').empty()
        $('#suggestionCount').html("<span>No matches found</span>")

      # enable/disable the pager elements
      if count <= 10
        $('.next-suggestions').addClass('disabled')
        $('.previous-suggestions').addClass('disabled')
      if count > 10
        # edge case min
        if _matchSkip == 0
          $('.previous-suggestions').addClass('disabled')
        # edge case max
        if (count - _matchSkip) <= 10
          $('.next-suggestions').addClass('disabled')

      # bind click handlers
      if !$('.previous-suggestions').hasClass('disabled')
        $('#previousSuggestions').bind('click', (e) ->
          e.preventDefault()
          e.stopPropagation()
          if count <= 10 || _matchSkip <= 10
            _matchSkip = 0
          else
            _matchSkip -= 10
          _suggestionGenerator(query, _matchSkip, callback)
        )
      if !$('.next-suggestions').hasClass('disabled')
        $('#forwardSuggestions').bind('click', (e) ->
          e.preventDefault()
          e.stopPropagation()
          if count <= 10
            _matchSkip 0
          else
            _matchSkip += 10
          _suggestionGenerator(query, _matchSkip, callback)
          return
        )
      return
    )
    return
  )
  return

# resets the simulation-progress bars
_resetSimulationProgress = ->
  _simulationProgress.set(0)
  $('.simulation-progress').css({width: '0%'})

# sets an object to be used by Meteors' Blaze templating engine (views)
Template.gritsSearch.helpers({
  isAnimationRunning: ->
    _animationRunning.get()
  periods: ->
    return [
      {value: 'days', displayName: i18n.get('gritsSearch.period-days')},
      {value: 'weeks', displayName: i18n.get('gritsSearch.period-weeks')},
      {value: 'months', displayName: i18n.get('gritsSearch.period-months')},
      {value: 'years', displayName: i18n.get('gritsSearch.period-years')}
    ]
  defaultPeriod: (period) ->
    if period.value == 'months'
      return true
    else
      return false
  GritsConstants: ->
    return GritsConstants
  isSimulatorRunning: ->
    return GritsFilterCriteria.isSimulatorRunning.get()
  isExploreMode: ->
    mode = Session.get(GritsConstants.SESSION_KEY_MODE)
    if _.isUndefined(mode)
      return false
    else
      if mode == GritsConstants.MODE_EXPLORE
        return true
      else
        return false
  isAnalyzeMode: ->
    mode = Session.get(GritsConstants.SESSION_KEY_MODE)
    if _.isUndefined(mode)
      return false
    else
      if mode == GritsConstants.MODE_ANALYZE
        return true
      else
        return false
  loadedRecords: ->
    return Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
  totalRecords: ->
    return Session.get(GritsConstants.SESSION_KEY_TOTAL_RECORDS)
  state: ->
    # GritsFilterCriteria.stateChanged is a reactive-var
    state = GritsFilterCriteria.stateChanged.get()
    if _.isNull(state)
      return
    if state
      return true
    else
      return false
  start: ->
    return _initStartDate
  end: ->
    return _initEndDate
  limit: ->
    if _init
      # set inital limit
      return _initLimit
    else
      # reactive var
      return GritsFilterCriteria.limit.get()
})

Template.gritsSearch.onCreated ->
  _initStartDate = GritsFilterCriteria.initStart()
  _initEndDate = GritsFilterCriteria.initEnd()
  _initLimit = GritsFilterCriteria.initLimit()
  _init = false # done initializing initial input values

  # Public API
  # Currently we declare methods above for documentation purposes then assign
  # to the Template.gritsSearch as a global export
  Template.gritsSearch.getOrigin = getOrigin
  Template.gritsSearch.getDepartureSearchMain = getDepartureSearchMain
  Template.gritsSearch.getEffectiveDatePicker = getEffectiveDatePicker
  Template.gritsSearch.getDiscontinuedDatePicker = getDiscontinuedDatePicker
  Template.gritsSearch.getCompareDatePicker = getCompareDatePicker
  Template.gritsSearch.simulationProgress = _simulationProgress
  Template.gritsSearch.disableLimit = _disableLimit

# triggered when the 'gritsSearch' template is rendered
Template.gritsSearch.onRendered ->

  departureSearchMain = $('#departureSearchMain').tokenfield({
    typeahead: [{hint: false, highlight: true}, {
      display: (match) ->
        if _.isUndefined(match)
          return
        return match.label
      templates:
        suggestion: _suggestionTemplate
        footer: _typeaheadFooter
      source: (query, callback) ->
        _suggestionGenerator(query, 0, callback)
        return
    }]
  })
  _setDepartureSearchMain(departureSearchMain)

  # Toast notification options
  toastr.options = {
    positionClass: 'toast-bottom-center',
    preventDuplicates: true,
  }

  options = {
    format: 'MM/DD/YY'
  }
  effectiveDatePicker = $('#effectiveDate').datetimepicker(options)
  effectiveDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'bottom', horizontal: 'left'})
  _setEffectiveDatePicker(effectiveDatePicker)

  discontinuedDatePicker = $('#discontinuedDate').datetimepicker(options)
  discontinuedDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'bottom', horizontal: 'left'})
  _setDiscontinuedDatePicker(discontinuedDatePicker)

  options = {
    format: 'MM/DD'
  }
  compareDatePicker = $('#compareDateOverPeriod').datetimepicker(options)
  compareDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'top', horizontal: 'left'})
  compareDatePicker.data('DateTimePicker').disable()
  _setCompareDatePicker(compareDatePicker)

  # set the original state of the filter on document ready
  GritsFilterCriteria.setState()

  Meteor.autorun ->
    mode = Session.get(GritsConstants.SESSION_KEY_MODE)
    # do not run if our mode hasn't changed
    if self.mode == mode
      return
    if mode == GritsConstants.MODE_EXPLORE
      _resetSimulationProgress()
      _disableLimit.set(false)
      async.nextTick( ->
        if GritsFilterCriteria.tokens.get().length isnt 0
          $("#showThroughput").click()
      )
      # reset the URL back to the root
      FlowRouter.go('/')
    else
      # initialize the bootstrap slider (this is not rendered by default in grits_search.html)
      # it is done using nextTick to give Blaze template time to render
      async.nextTick(-> $('#simulatedPassengersInputSlider').slider())
      _disableLimit.set(true)
      # only allow startSimulation to be clicked when an existing simulation
      # is not running to avoid duplicate occurrences
      if !GritsFilterCriteria.isSimulatorRunning.get()
        async.nextTick( ->
          if GritsFilterCriteria.tokens.get().length isnt 0
            $("#startSimulation").click()
        )
    self.mode = mode

  Meteor.autorun (c) ->
    departures = GritsFilterCriteria.tokens.get()
    if departures.length == 0
      _resetSimulationProgress()
      if !c.firstRun
        # reset the route when the departures are cleared
        FlowRouter.go('/')

  # enable/disable the compareDatePicker and periods 'days', 'weeks', 'months'
  # when the reactive var enableDateOverPeriod changes.
  Meteor.autorun ->
    enable = GritsFilterCriteria.enableDateOverPeriod.get()
    if enable
      _compareDatePicker.data('DateTimePicker').enable()
      GritsFilterCriteria.period.set('years')
      $('#period').prop('disabled', true)
    else
      _compareDatePicker.data('DateTimePicker').disable()
      _compareDatePicker.data('DateTimePicker').date(null)
      GritsFilterCriteria.period.set(_lastPeriod)
      $('#period').prop('disabled', false)

  # is the animation running
  Meteor.autorun ->
    running = GritsHeatmapLayer.animationRunning.get()
    # update the disabled status of the [More] button based loadedRecords
    loadedRecords = Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
    totalRecords = Session.get(GritsConstants.SESSION_KEY_TOTAL_RECORDS)
    if running
      _animationRunning.set(true)
      $('#loadMore').prop('disabled', true)
    else
      _animationRunning.set(false)
      if loadedRecords < totalRecords
        # enable the [More] button when loaded is less than total
        $('#loadMore').prop('disabled', false)
      else
        # disable the [More] button
        $('#loadMore').prop('disabled', true)

  # Determine if the router set a simId
  # @see lib/router.coffee
  Meteor.autorun (c) ->
    simId = Session.get(GritsConstants.SESSION_KEY_SHARED_SIMID)
    if _.isUndefined(simId)
      return
    # mark the simulator as running
    GritsFilterCriteria.isSimulatorRunning.set(true)
    Meteor.call('findSimulationBySimId', simId, (err, simulation) ->
      if err
        Meteor.gritsUtil.errorHandler(err)
        console.error(err)
        return
      if _.isEmpty(simulation)
        Meteor.gritsUtil.errorHandler({message: 'Invalid simulation'})
        return
      # get the values from the simulation
      startDate = moment.utc(simulation.get('startDate'))
      endDate = moment.utc(simulation.get('endDate'))
      tokens = simulation.get('departureNodes')
      simPas = simulation.get('numberPassengers')
      # update the filter and UI elements
      GritsFilterCriteria.setOperatingDateRangeStart(startDate)
      GritsFilterCriteria.setOperatingDateRangeEnd(endDate)
      GritsFilterCriteria.setDepartures(tokens)
      # GritsFilterCriteria does not have a interface for the simulatedPassengersInputSlider
      async.nextTick(->
        $('#simulatedPassengersInputSlider').slider('setValue', simPas)
        $('#simulatedPassengersInputSliderValIndicator').html(simPas)
      )
      # Update the dataTable
      Template.gritsDataTable.simId.set(simId)
      # Set the total records
      Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, simPas)
      # Process the existing simulation
      GritsFilterCriteria.processSimulation(simPas, simulation.get('simId'))
      # Do not rerun initSharedSim
      c.stop()
    )

_changeSimulatedPassengersHandler = (e) ->
  val = parseInt($("#simulatedPassengersInputSlider").val(), 10)
  if val isnt _wfStartVal
    _wfStartVal = val
    if _.isNaN(val)
      val = null
    $('#simulatedPassengersInputSliderValIndicator').empty().html(val)
  return
_changeDepartureHandler = (e) ->
  combined = []
  tokens =  _departureSearchMain.tokenfield('getTokens')
  codes = _.pluck(tokens, 'label')
  combined = _.union(codes, combined)
  if _.isEqual(combined, GritsFilterCriteria.tokens.get())
    # do nothing
    return
  GritsFilterCriteria.tokens.set(combined)
  return
_changeDateHandler = (e) ->
  $target = $(e.target)
  id = $target.attr('id')
  if id == 'discontinuedDate'
    if _.isNull(_discontinuedDatePicker)
      return
    date = _discontinuedDatePicker.data('DateTimePicker').date()
    GritsFilterCriteria.operatingDateRangeStart.set(date)
    return
  if id == 'effectiveDate'
    if _.isNull(_effectiveDatePicker)
      return
    date = _effectiveDatePicker.data('DateTimePicker').date()
    GritsFilterCriteria.operatingDateRangeEnd.set(date)
    return
  if id == 'compareDateOverPeriod'
    if _.isNull(_compareDatePicker)
      return
    date = _compareDatePicker.data('DateTimePicker').date()
    GritsFilterCriteria.compareDateOverPeriod.set(date)
    return
_showDateHandler = (e) ->
  $target = $(e.target)
  id = $target.attr('id')
  if id == 'compareDateOverPeriod'
    if _.isNull(_compareDatePicker)
      return
  return
_changeLimitHandler = (e) ->
  val = parseInt($("#limit").val(), 10)
  GritsFilterCriteria.limit.set(val)
  return
_changePeriodHandler = (e) ->
  _lastPeriod = $(e.target).val()
  GritsFilterCriteria.period.set(_lastPeriod)
_changeEnableDateOverPeriodHandler = (e) ->
  if $(e.target).is(':checked')
    GritsFilterCriteria.enableDateOverPeriod.set(true)
  else
    GritsFilterCriteria.enableDateOverPeriod.set(false)
  return
_startSimulation = (e) ->
  if $(e.target).hasClass('disabled')
    return
  simPas = parseInt($('#simulatedPassengersInputSlider').slider('getValue'), 10)
  startDate = _discontinuedDatePicker.data('DateTimePicker').date().format('DD/MM/YYYY')
  endDate = _effectiveDatePicker.data('DateTimePicker').date().format('DD/MM/YYYY')
  GritsFilterCriteria.startSimulation(simPas, startDate, endDate)
  return
_showThroughput = (e) ->
  if $(e.target).hasClass('disabled')
    return
  GritsFilterCriteria.apply()
  return
# events
#
# Event handlers for the grits_filter.html template
Template.gritsSearch.events
  'keyup #departureSearchMain-tokenfield': (e) ->
    if e.keyCode == 13
      if $(e.target).hasClass('disabled')
        return
      GritsFilterCriteria.apply()
    return
  'slideStop #simulatedPassengersInputSlider': _changeSimulatedPassengersHandler
  'click #startSimulation': _startSimulation
  'click #showThroughput': _showThroughput
  'change #limit': _changeLimitHandler
  'change #departureSearchMain': _changeDepartureHandler
  'dp.change': _changeDateHandler
  'dp.show': _showDateHandler
  'click #includeNearbyAirports': (event) ->
    miles = parseInt($("#includeNearbyAirportsRadius").val(), 10)
    departures = GritsFilterCriteria.tokens.get()

    if departures.length <= 0
      toastr.error(i18n.get('includeNearbyRequired'))
      return false

    if (departures[0].indexOf(GritsMetaNode.PREFIX) >= 0)
      toastr.error(i18n.get('includeNearbyMetaNode'))
      return false

    if $('#includeNearbyAirports').is(':checked')
      Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, true)
      Meteor.call('findNearbyAirports', departures[0], miles, (err, airports) ->
        if err
          Meteor.gritsUtil.errorHandler(err)
          return

        nearbyTokens = _.pluck(airports, '_id')
        union = _.union(departures, nearbyTokens)
        _departureSearchMain.tokenfield('setTokens', union)
        Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
      )
    else
      departureSearch = getDepartureSearchMain()
      departureSearch.tokenfield('setTokens', departures)
    return
  'click #toggleFilter': (e) ->
    $self = $(e.currentTarget)
    $("#filter").toggle("fast")
    return
  'click #applyFilter': (event, template) ->
    GritsFilterCriteria.apply()
    return
  'click #loadMore': ->
    GritsFilterCriteria.setOffset()
    mode = Session.get(GritsConstants.SESSION_KEY_MODE)
    if mode == GritsConstants.MODE_EXPLORE
      GritsFilterCriteria.more()
    return
  'tokenfield:initialize': (e) ->
    $target = $(e.target)
    $container = $target.closest('.tokenized')
    #the typeahead menu should be as wide as the filter at a minimum
    $menu = $container.find('.tt-dropdown-menu')
    $menu.css('max-width', $('.tokenized.main').width())
    id = $target.attr('id')
    $container.find('.tt-dropdown-menu').css('z-index', 999999)
    $container.find('.token-input.tt-input').css('height', '30px')
    $container.find('.token-input.tt-input').css('font-size', '20px')
    $container.find('.tokenized.main').prepend($("#searchIcon"))
    $('#' + id + '-tokenfield').on('blur', (e) ->
      # only allow tokens
      $container.find('.token-input.tt-input').val("")
    )
    return
  'tokenfield:createtoken': (e) ->
    $target = $(e.target)
    $container = $target.closest('.tokenized')
    tokens = $target.tokenfield('getTokens')
    if tokens.length > 0
      toastr.error(i18n.get('toastMessage.onlyOneToken'))
      e.preventDefault()
      return
    match = _.find(tokens, (t) -> t.label == e.attrs.label)
    if match
      # do not create a token and clear the input
      $target.closest('.tokenized').find('.token-input.tt-input').val("")
      e.preventDefault()
    return
  'tokenfield:createdtoken': (e) ->
    $target = $(e.target)
    tokens = $target.tokenfield('getTokens')
    token = e.attrs.label
    return false
  'tokenfield:removedtoken': (e) ->
    $target = $(e.target)
    tokens = $target.tokenfield('getTokens')
    # determine if the remaining tokens is empty, then show the placeholder text
    if tokens.length == 0
      if $target.attr('id') in ['departureSearchMain']
        $('#includeNearbyAirports').prop('checked', false)

    token = e.attrs.label
    return false
  'change #period': _changePeriodHandler
  'change #enableDateOverPeriod': _changeEnableDateOverPeriodHandler
