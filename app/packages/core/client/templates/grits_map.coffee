# Template.gritsSearch
#
# When another meteor app adds grits:grits-net-meteor as a package
# Template.gritsSearch will be available globally.
_instance = null

# returns the map instance
#
# @return [GritsMap] map, a GritsMap instance
getInstance = ->
  return _instance

# sets the map instance
#
# @param [GritsMap] map, a GritsMap object
setInstance = (map) ->
  if typeof map == 'undefined'
    throw new Error('Requires a map to be defined')
    return
  if !map instanceof GritsMap
    throw new Error('Requires a valid map instance')
    return
  _instance = map

# adds the default controls to the map specified
#
# @param [GritsMap] map - map to apply the default controls
addDefaultControls = (map) ->
  Blaze.render(Template.gritsLegend, $('#sidebar-slider')[0])
  Blaze.render(Template.gritsSearch, $('#sidebar-search')[0])
  Blaze.render(Template.gritsDataTable, $('#sidebar-flightData')[0])
  Blaze.render(Template.gritsLayerSelector, $('#sidebar-layer')[0])

Template.gritsMap.onCreated ->
  # Public API
  # Currently we declare methods above for documentation purposes then assign
  # to the Template.gritsSearch as a global export
  Template.gritsMap.getInstance = getInstance
  Template.gritsMap.setInstance = setInstance
  Template.gritsMap.addDefaultControls = addDefaultControls
