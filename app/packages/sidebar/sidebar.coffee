if Meteor.isClient
  Template.sidebar.onCreated ->
    @sidebarOpen = new ReactiveVar @data.open

  Template.sidebar.helpers
    customTemplateName: ->
      Template.instance().data.customTemplateName

    data: ->
      sidebarOpen: Template.instance().sidebarOpen
