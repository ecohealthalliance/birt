if Meteor.isClient
  Template.tabularSidebar.helpers
    open: ->
      Session.get('tabularSidebarOpen')

  Template.tabularSidebar.events
    'click .sidebar--table--tab': (event, instance) ->
      state = Session.get('tabularSidebarOpen')
      Session.set('tabularSidebarOpen', not state)
