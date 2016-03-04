# creates an instance of a marker
#
# @param [Integer] width, the width in px of the marker
# @param [Integer] height, the height in px of the marker
# @param [Object] colorScale, an object containing keys as integer values from
#  0 - 9 with HTML color codes associated as the value.
class GritsMarker
  constructor: (width, height, colorScale, widthScale) ->
    @_name = 'GritsMarker'

    if typeof width == 'undefined'
      @height = 25
    else
      @height = height

    if typeof height == 'undefined'
      @width = 15
    else
      @width = width

    if typeof colorScale == 'undefined'
      @colorScale =
        9: '282828'
        8: '383838'
        7: '484848'
        6: '585858'
        5: '686868'
        4: '787878'
        3: '888888'
        2: '989898'
        1: 'A8A8A8'
        0: 'B8B8B8'
    else
      @colorScale = colorScale

    if typeof widthScale == 'undefined'
      @widthScale =
        9: '16'
        8: '15'
        7: '14'
        6: '13'
        5: '12'
        4: '11'
        3: '10'
        2: '9'
        1: '8'
        0: '7'
    else
      @widthScale = widthScale

    return
