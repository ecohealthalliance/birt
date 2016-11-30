if Meteor.isClient
  Template.mainSidebar.onCreated ->
    @activeTab = new ReactiveVar 1
    @activePane = new ReactiveVar 1
    @open = @data.sidebarOpen

  Template.mainSidebar.helpers
    sideBarOpen: ->
      Template.instance().open.get()
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

    'click .zoom-control--in': (event) ->
      Template.gritsMap.getInstance().zoomIn()

    'click .zoom-control--out': (event) ->
      Template.gritsMap.getInstance().zoomOut()

    'click .pane-control': (event, instance) ->
      tab = $(event.currentTarget).data('tab')
      console.log tab
      instance.activeTab.set tab
      instance.activePane.set tab
      instance.open.set true
