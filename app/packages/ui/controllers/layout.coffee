Template.layout.onCreated ->
  @classes = new ReactiveVar ''
  @autorun =>
    mainState = Session.get('mainSidebarOpen')
    tabularState = Session.get('tabularSidebarOpen')
    classes = ''
    if not mainState
      classes += ' main-sidebar-closed'
    if not tabularState
      classes += ' tabular-sidebar-closed'
    @classes.set classes

Template.layout.helpers
  sidebarStates: ->
    Template.instance().classes.get()
