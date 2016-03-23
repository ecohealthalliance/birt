Template.gritsLegend.events({
  'slide': (event, template) ->
    $slider = $(event.target)
    name = $slider.data('slider-name')
    val = $slider.slider('getValue')
    map = Template.gritsMap.getInstance()
    # determine the current layer group
    layerGroup = GritsLayerGroup.getCurrentLayerGroup()
    if name == GritsConstants.NODE_LAYER_ID
      layer = layerGroup.getNodeLayer()
    if layer == null
      return
    layer.min.set(val[0])
    layer.max.set(val[1])
    return
})

Template.gritsLegend.helpers({
  pathLayerName: ->
    return GritsConstants.PATH_LAYER_ID
  nodeLayerName: ->
    return GritsConstants.NODE_LAYER_ID
  nodeColorScale: (k) ->
    return 0
  pathColorScale: (k) ->
    return 0
})

Template.gritsLegend.onRendered ->
  self = this
  $('.slider').slider()
