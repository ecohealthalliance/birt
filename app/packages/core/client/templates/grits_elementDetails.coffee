# shows the path tab
showPath = ->
  $('#element-details').show()
  $('.element-details-nav a[href="#pathDetails"]').tab('show')

# shows the node tab
showNode = ->
  $('#element-details').show()
  $('.element-details-nav a[href="#nodeDetails"]').tab('show')

Template.gritsElementDetails.events
  'click .element-details-close': (e) ->
    $('#element-details').hide()

Template.gritsElementDetails.helpers({
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
  getNodeGlobalRegion: (n) ->
    if _.isUndefined(n)
      return
    if n._id.indexOf(GritsMetaNode.PREFIX) >= 0
      return 'N/A'
    node = _.find(Meteor.gritsUtil.airports, (node) -> node._id == n._id)
    return node.globalRegion
  node: ->
    if _.isUndefined(Template.instance().node)
      return {}
    else
      return Template.instance().node.get()
  path: ->
    return {}
  pathWeight: (path) ->
    return 0
  normalized: (obj) ->
    if _.isUndefined(obj) || _.isNull(obj)
      return ''
    if !obj.hasOwnProperty('normalizedPercent')
      return ''
    return +(obj.normalizedPercent).toFixed(2)
  nodeTotalThroughput: (node) ->
    if _.isUndefined(node) || _.isNull(node)
      return ''
    return node.incomingThroughput + node.outgoingThroughput
})

Template.gritsElementDetails.onCreated ->
  self = this
  self.path = new ReactiveVar(null)
  self.node = new ReactiveVar(null)
  #Public API
  Template.gritsElementDetails.showPath = showPath
  Template.gritsElementDetails.showNode = showNode

Template.gritsElementDetails.onRendered ->
  self = this
  $('.element-details').hide()
  #store reference to the map and layer instances
  self.map = Template.gritsMap.getInstance()
