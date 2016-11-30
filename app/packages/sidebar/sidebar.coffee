if Meteor.isClient
  Template.sidebar.helpers
    customTemplateName: ->
      Template.instance().data.customTemplateName
