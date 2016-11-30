if Meteor.isClient
  Template.tabularSidebar.onCreated ->
    @sidebarOpen = @data.sidebarOpen

  Template.tabularSidebar.helpers
    open: ->
      Template.instance().sidebarOpen.get()

  Template.tabularSidebar.events
    'click .sidebar--table--tab': (event, instance) ->
      state = instance.sidebarOpen
      state.set not state.get()
