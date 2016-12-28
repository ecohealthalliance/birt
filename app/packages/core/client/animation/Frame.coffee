class Frame
  ###
  # builds a new frame
  #
  # @param [Object] data, the data that the frame holds
  # @param [Number] processed, the number of objects processed within this frame
  # @param [String] key, the unique key for the frame
  ###
  constructor: (data, processed, key) ->
    @data = data
    @processed = processed
    @key = key
