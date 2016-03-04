_redrawLayerList = _.debounce(() ->
  $('#leafletLayers').empty()
  $layerList = $('.leaflet-control-layers-list')
  $layerList.appendTo($('#leafletLayers'))
  $layerList.show()
, 250)

Template.gritsLayerSelector.onRendered ->
  window.addEventListener('mapper.addOverlayControl', (e) ->
    $('.leaflet-control-layers-toggle').hide()
    _redrawLayerList()
  )
  $('.leaflet-control-layers-toggle').hide()
  _redrawLayerList()
