# Template.gritsDataTable
#
# When another meteor app adds grits:grits-net-meteor as a package
# Template.gritsDataTable will be available globally.
_previousPath = null # placeholder for the last clicked path
_previousMode = null # placeholder for thet last mode
_simId = new ReactiveVar(null)
_tablesChanged = new ReactiveVar(false)

# highlights the path table row
#
# @param [Object] a GritsPath object
highlightPathTableRow = (path) ->
  if !(path instanceof GritsPath)
    return
  $row = $("tr[data-id=#{path._id}]")
  # remove any previously clicked rows
  $table = $row.closest('table')
  $table.find('.activeRow').removeClass('activeRow')
  if _previousPath != path
    # add the active class to this row and remove any background-color
    $row.addClass('activeRow').css({'background-color':''})
    # reset the previous path background-color
    if !_.isNull(_previousPath)
      $previousPath = $("tr[data-id=#{_previousPath._id}]")
    # this path becomes the previousPath
    _previousPath = path
  else
    # clicked on same path, reset the color and set _previousPath to null
    $row.css({'background-color':path.color})
    _previousPath = null
  return

# update the simulationProgress bar
_updateSimulationProgress = (progress) ->
  $('.simulation-progress').css({width: progress})
  return progress

# throttle how many time we trigger update during reactive changes to the dataTable
_throttleTablesChanged = _.throttle(->
  if $('#exploreTable').hasClass('tablesorter')
    # the tablesorter has already been applied, trigger an update
    $('#exploreTable').trigger('update')
  else
    # init a new tablesorter
    $('#exploreTable').tablesorter()

  _tablesChanged.set(false)
, 250)

Template.gritsDataTable.events({
  'click .share-btn': (event, template) ->
    # toggle the display of the share-link-container
    $('.share-link-container').slideToggle('fast')
    return
  'click .pathTableRow': (event, template) ->
    # get the clicked row
    $row = $(event.currentTarget)
    # find the path from template.paths using the DOM's id
    _id = $row.data('id')
    paths = template.paths.get()
    path = _.find(paths, (path) -> path._id == _id)
    if _.isUndefined(path)
      return
    element = $('#' + path.elementID)[0]
    if _.isUndefined(element)
      return
    # simulate a click on the path
    path.eventHandlers.click(element)
    return
  'click .exportData': (event) ->
    $('.dtHidden').show()
    fileType = $(event.currentTarget).attr("data-type")
    activeTable = $('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      activeTable.tableExport({type: fileType})
    $('.dtHidden').hide()
    return
})

Template.gritsDataTable.helpers({
  getCurrentURL: ->
    return FlowRouter.currentURL.get()
  getNodeName: (n) ->
    if _.isUndefined(n)
      return
    if n._id.indexOf(GritsMetaNode.PREFIX) >= 0
      return n._id
    node = _.find(Meteor.gritsUtil.airports, (node) -> node._id == n._id)
    return node.name
  getNodeCity: (n) ->
    if _.isUndefined(n)
      return
    if n._id.indexOf(GritsMetaNode.PREFIX) >= 0
      return 'N/A'
    node = _.find(Meteor.gritsUtil.airports, (node) -> node._id == n._id)
    return node.city
  getNodeState: (n) ->
    if _.isUndefined(n)
      return
    if n._id.indexOf(GritsMetaNode.PREFIX) >= 0
      return 'N/A'
    node = _.find(Meteor.gritsUtil.airports, (node) -> node._id == n._id)
    return node.state
  getNodeCountry: (n) ->
    if _.isUndefined(n)
      return
    if n._id.indexOf(GritsMetaNode.PREFIX) >= 0
      return 'N/A'
    node = _.find(Meteor.gritsUtil.airports, (node) -> node._id == n._id)
    return node.countryName
  simulationProgress: ->
    progress = Template.gritsSearch.simulationProgress.get() + '%'
    return _updateSimulationProgress(progress)
  getAdditionalInfo: (airport) ->
    additionalInfo = ''
    if airport.hasOwnProperty('city') && airport.city != ''
      additionalInfo += airport.city
    if airport.hasOwnProperty('state') && airport.state != ''
      additionalInfo += ', ' + airport.state
    if airport.hasOwnProperty('countryName') && airport.countryName != ''
      additionalInfo += ', ' + airport.countryName
    return additionalInfo
  simPas: ->
    if _.isUndefined(Template.instance().simPas)
      return 0
    else
      return Template.instance().simPas.get()
  startDate: ->
    if _.isUndefined(Template.instance().startDate)
      return ''
    else
      return Template.instance().startDate.get()
  endDate: ->
    if _.isUndefined(Template.instance().endDate)
      return ''
    else
      return Template.instance().endDate.get()
  departures: ->
    if _.isUndefined(Template.instance().departures)
      return []
    else
      return Template.instance().departures.get()
  paths: ->
    if _.isUndefined(Template.instance().paths)
      return []
    else
      paths = Template.instance().paths.get()
      return Template.instance().paths.get()
  getPathThroughputColor: (path) ->
    if _.isUndefined(path)
      return ''
    layerGroup = GritsLayerGroup.getCurrentLayerGroup()
    return layerGroup.getPathLayer()._getNormalizedColor(path)
})

Template.gritsDataTable.onCreated ->
  # initialize reactive-var to hold reference to the paths, nodes, and heatmap data
  this.paths = new ReactiveVar([])
  this.heatmaps = new ReactiveVar([])
  this.simId = null
  this.simPas = new ReactiveVar(null)
  this.startDate = new ReactiveVar(null)
  this.endDate = new ReactiveVar(null)
  this.departures = new ReactiveVar([])

  this._reset = ->
    this.paths.set([])
    this.simPas.set(0)
    this.startDate.set('')
    this.endDate.set('')
    this.departures.set([])
    _simId.set(null)
    _tablesChanged.set(true)

  # Public API
  Template.gritsDataTable.highlightPathTableRow = highlightPathTableRow
  Template.gritsDataTable.simId = _simId
  Template.gritsDataTable.reset = this._reset

Template.gritsDataTable.onRendered ->
  self = this

  # setup the clipboard for share-btn-link
  self.clip = new Clipboard('.share-copy-btn')
  self.clip.on('success', ->
    toastr.info(i18n.get('toastMessages.clipboard'))
    $('.share-link-container').hide()
    return
  )

  # get the map instance
  self.map = Template.gritsMap.getInstance()

  # get the heatmap layer
  heatmapLayerGroup = self.map.getGritsLayerGroup(GritsConstants.HEATMAP_GROUP_LAYER_ID)
  self.heatmapLayer = heatmapLayerGroup.find(GritsConstants.HEATMAP_LAYER_ID)

  Meteor.autorun ->
    departures = GritsFilterCriteria.tokens.get()
    # clear the datatable if departures == 0
    if departures.length == 0
      self._reset()
      return

  Meteor.autorun ->
    # what is the current simId
    simId = _simId.get()
    if _.isEmpty(simId)
      return
    Meteor.call('findSimulationBySimId', simId, (err, simulation) ->
      if err
        console.error(err)
        return
      self.simPas.set(simulation.get('numberPassengers'))
      self.startDate.set(moment.utc(simulation.get('startDate')).format('MM/DD/YYYY'))
      self.endDate.set(moment.utc(simulation.get('endDate')).format('MM/DD/YYYY'))
      tokens = simulation.get('departureNodes')
      airports = _.filter(Meteor.gritsUtil.airports, (a) -> _.indexOf(tokens, a._id) >= 0)
      self.departures.set(airports)
      self.simId = simulation.get('simId')
    )

  Meteor.autorun ->
    if _tablesChanged.get()
      _throttleTablesChanged()
