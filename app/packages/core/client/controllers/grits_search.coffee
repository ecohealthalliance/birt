# Template.gritsSearch
#
# When another meteor app adds grits:grits-net-meteor as a package
# Template.gritsSearch will be available globally.
_init = true # flag, set to false when initialization is done
_initStartDate = null # onCreated will initialize the date through GritsFilterCriteria
_initEndDate = null # onCreated will initialize the date through GritsFilterCriteria
_initLimit = null # onCreated will initialize the limt through GritsFilterCriteria
_searchBar = null # onRendered will set this to a typeahead object
_endDatePicker = null # onRendered will set this to a datetime picker object
_startDatePicker = null # onRendered will set this to a datetime picker object
_compareDatePicker = null # onRendered will set this to a datetime picker object
_lastPeriod = 'months' # remember the last selected period when enable/disable compare date over interval, defaults to 'months'
_animationRunning = new ReactiveVar(false)
_matchSkip = null # the amount to skip during typeahead pagination
_disableLimit = new ReactiveVar(false) # toggle if we will allow limit/skip
# the underscore template for the typeahead result
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

# returns the typeahead object for the '#searchBar' input
#
# @see: http://sliptree.github.io/bootstrap-tokenfield/#methods
# @return [Object] typeahead
getSearchBar = ->
  return _searchBar

# sets the typeahead object for the '#searchBar' input
_setSearchBar = (typeahead) ->
  _searchBar = typeahead
  return

# returns the datetime picker object for the '#endDate' input  with the label 'End'
#
# @see http://eonasdan.github.io/bootstrap-datetimepicker/Functions/
# @return [Object] datetimePicker object
getEndDatePicker = ->
  return _endDatePicker

# sets the datetime picker object for the '#endDate' input with the label 'End'
_setEndDatePicker = (datetimePicker) ->
  _endDatePicker = datetimePicker
  return

# returns the datetime picker object for the '#startDate' input with the label 'Start'
#
# @see http://eonasdan.github.io/bootstrap-datetimepicker/Functions/
# @return [Object] datetimePicker object
getStartDatePicker = ->
  return _startDatePicker

# sets the datetime picker object for the '#startDate' input
_setStartDatePicker = (datetimePicker) ->
  _startDatePicker = datetimePicker
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

# recursive method to generate suggestions and drive the pagination feature
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
  loadedRecords: ->
    return Session.get(GritsConstants.SESSION_KEY_LOADED_RECORDS)
  totalRecords: ->
    return Session.get(GritsConstants.SESSION_KEY_TOTAL_RECORDS)
  isSimulatorRunning: ->
    return GritsFilterCriteria.isSimulatorRunning.get()
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
  historicalView: ->
    Template.instance().historicalView.get()
  summer: ->
    Template.instance().season.get() == "summer"
  autumn: ->
    Template.instance().season.get() == "autumn"
  winter: ->
    Template.instance().season.get() == "winter"
  spring: ->
    Template.instance().season.get() == "spring"
})

Template.gritsSearch.onCreated ->
  _initStartDate = GritsFilterCriteria.initStart()
  _initEndDate = GritsFilterCriteria.initEnd()
  _initLimit = GritsFilterCriteria.initLimit()
  _init = false # done initializing initial input values

  @season = new ReactiveVar null
  @historicalView = new ReactiveVar true
  @autorun =>
    unless @historicalView.get() == 'historicalView'
      # reset the seaon when the view changes
      @season.set null

  @autorun =>
    season = @season.get()
    tokens = GritsFilterCriteria.tokens.get()
    if season
      params =
        season: season
        birds: tokens
      Template.gritsOverlay.show()
      Meteor.call 'migrationsBySeason', params, (err, result)->
        Template.gritsOverlay.hide()
        if err
          console.log err
          alert("Server error while computing migrations for season.")
          return
        map = Template.gritsMap.getInstance()
        # reset the historical heatmap
        heatmapLayerGroup = map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
        heatmapLayerGroup.reset()
        result.forEach (doc)->
          GritsHeatmapLayer.createLocation(
            season,
            doc,
            tokens)
        heatmapLayerGroup.draw()
  # Public API
  # Currently we declare methods above for documentation purposes then assign
  # to the Template.gritsSearch as a global export
  Template.gritsSearch.getSearchBar = getSearchBar
  Template.gritsSearch.getEndDatePicker = getEndDatePicker
  Template.gritsSearch.getStartDatePicker = getStartDatePicker
  Template.gritsSearch.getCompareDatePicker = getCompareDatePicker
  Template.gritsSearch.disableLimit = _disableLimit

# triggered when the 'gritsSearch' template is rendered
Template.gritsSearch.onRendered ->

  searchBar = $('#searchBar').tokenfield({
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
  _setSearchBar(searchBar)

  # Toast notification options
  toastr.options = {
    positionClass: 'toast-bottom-center',
    preventDuplicates: true,
  }

  # initialize the DateTimePickers
  options = {
    format: 'MM/DD/YY'
  }
  startDatePicker = $('#startDate').datetimepicker(options)
  startDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'bottom', horizontal: 'left'})
  _setStartDatePicker(startDatePicker)
  endDatePicker = $('#endDate').datetimepicker(options)
  endDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'bottom', horizontal: 'left'})
  _setEndDatePicker(endDatePicker)

  options = {
    format: 'MM/DD'
  }
  compareDatePicker = $('#compareDateOverPeriod').datetimepicker(options)
  compareDatePicker.data('DateTimePicker').widgetPositioning({vertical: 'top', horizontal: 'left'})
  compareDatePicker.data('DateTimePicker').disable()
  _setCompareDatePicker(compareDatePicker)

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

_changeSearchBarHandler = (e) ->
  combined = []
  tokens =  _searchBar.tokenfield('getTokens')
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
  if id == 'startDate'
    if _.isNull(_startDatePicker)
      return
    date = _startDatePicker.data('DateTimePicker').date()
    GritsFilterCriteria.operatingDateRangeStart.set(date)
    Session.set('dateRangeStart', date.toDate())
    return
  else if id == 'endDate'
    if _.isNull(_endDatePicker)
      return
    date = _endDatePicker.data('DateTimePicker').date()
    GritsFilterCriteria.operatingDateRangeEnd.set(date)
    Session.set('dateRangeEnd', date.toDate())
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
_applyFilter = (e) ->
  if $(e.target).hasClass('disabled')
    return
  GritsFilterCriteria.apply()
  return
# events
#
# Event handlers for the grits_filter.html template
Template.gritsSearch.events
  'keyup #searchBar-tokenfield': (e) ->
    if e.keyCode == 13
      if $(e.target).hasClass('disabled')
        return
      GritsFilterCriteria.apply()
    return
  'click #applyFilter': _applyFilter
  'change #limit': _changeLimitHandler
  'change #searchBar': _changeSearchBarHandler
  'dp.change': _changeDateHandler
  'dp.show': _showDateHandler
  'click #applyFilter': (event, template) ->
    GritsFilterCriteria.apply()
    return
  'click #loadMore': ->
    GritsFilterCriteria.setOffset()
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
    token = e.attrs.label
    return false
  'change #period': _changePeriodHandler
  'change #enableDateOverPeriod': _changeEnableDateOverPeriodHandler
  'click .historical-view': (e, instance)->
    instance.historicalView.set true
  'click .seasonal-view': (e, instance)->
    instance.historicalView.set false
  'click .seasons a': (e, instance)->
    console.log $(e.target).text().toLowerCase()
    instance.season.set $(e.target).text().toLowerCase()
