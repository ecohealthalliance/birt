if Meteor.isClient
  _boundingBox = null
  _lastMode = null

  Template.mainSidebar.onCreated ->
    @activeTab = new ReactiveVar 1
    @activePane = new ReactiveVar 1
    @isDrawing = new ReactiveVar false
    @open = @data.sidebarOpen

  Template.mainSidebar.onRendered ->
    self = this
    # keep the UI reactive with the current mode
    Tracker.autorun ->
      _lastMode = Session.get(GritsConstants.SESSION_KEY_MODE)
      $('#mode-toggle :input[data-mode="' + _lastMode + '"]').click()

    Tracker.autorun ->
      isReady = Session.get(GritsConstants.SESSION_KEY_IS_READY)
      if isReady
        $('#mode-toggle').show()

  Template.mainSidebar.helpers
    sideBarOpen: ->
      Template.instance().open.get()
    MODE_EXPLORE: ->
      return GritsConstants.MODE_EXPLORE
    MODE_ANALYZE: ->
      return GritsConstants.MODE_ANALYZE
    tabActive: (tab)->
      Template.instance().activeTab.get() == tab
    paneActive: (pane)->
      Template.instance().activePane.get() == pane
    drawing: ->
      Template.instance().isDrawing.get()

  Template.mainSidebar.events
    'click .logo': (event, instance) ->
      GritsFilterCriteria.reset()

    'click .sidebar--collapse': (event, instance)->
      instance.open.set not instance.open.get()

    'change #mode-toggle': (event) ->
      # reset counters and heatmap
      Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
      Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, 0)
      # the trigger to toggle the mode can happen before the map is initialized
      # check that its not undefined or null
      map = Template.gritsMap.getInstance()
      if !(_.isUndefined(map) || _.isNull(map))
        map._layers.heatmap.reset()
      mode = $(event.target).data('mode')
      if _lastMode == mode
        return
      Session.set(GritsConstants.SESSION_KEY_MODE, mode)

    'click .zoom-control--in': (event) ->
      Template.gritsMap.getInstance().zoomIn()

    'click .zoom-control--out': (event) ->
      Template.gritsMap.getInstance().zoomOut()

    'click #sidebar-draw-rectangle-tool': (event, instance) ->
      map = Template.gritsMap.getInstance()
      _isDrawing = not instance.isDrawing.get()
      instance.isDrawing.set _isDrawing
      if _isDrawing
        _boundingBox = new GritsBoundingBox($(event.currentTarget), map)
        $("#action-menu-Select").click()
      else
        if _boundingBox != null
          _boundingBox.remove()

    'click .pane-control': (event, instance) ->
      tab = $(event.currentTarget).data('tab')
      instance.activeTab.set tab
      instance.activePane.set tab
      instance.open.set true
