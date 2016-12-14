if Meteor.isClient
  Template.mainSidebar.onCreated ->
    @activeTab = new ReactiveVar 1
    @activePane = new ReactiveVar 1

  Template.mainSidebar.helpers
    sideBarOpen: ->
      Session.get('mainSidebarOpen')

    tabActive: (tab)->
      Template.instance().activeTab.get() == tab

    paneActive: (pane)->
      Template.instance().activePane.get() == pane

  Template.mainSidebar.events
    'click .logo': (event, instance) ->
      GritsFilterCriteria.reset()

    'click .sidebar--collapse': (event, instance)->
      state = Session.get('mainSidebarOpen')
      Session.set('mainSidebarOpen', not state)

    'click .zoom-control--in': (event) ->
      Template.gritsMap.getInstance().zoomIn()

    'click .zoom-control--out': (event) ->
      Template.gritsMap.getInstance().zoomOut()

    'click .pane-control': (event, instance) ->
      tab = $(event.currentTarget).data('tab')
      instance.activeTab.set tab
      instance.activePane.set tab
      Session.set('mainSidebarOpen', true)
