# FIFO buffer
class FrameBuffer
  constructor: ->
    @_beginningIndex = 1
    @_endingIndex = 1
    @_data = {}

  ###
  # @return [Number] size, the size of the queue
  ###
  size: ->
    @_endingIndex - @_beginningIndex;

  ###
  # enqueue adds an object to the end of the queue
  # @param [Object] obj, the object to add
  # @return [Object] this
  ###
  enqueue: (obj) ->
    @_data[@_endingIndex] = obj
    @_endingIndex++
    return @

  ###
  # dequeue removes an object from the beginning of the queue
  # @return [Object] obj, the object to remove
  ###
  dequeue: ->
    beginningIndex = @_beginningIndex
    endingIndex = @_endingIndex
    if beginningIndex != endingIndex
      obj = @_data[beginningIndex]
      delete @_data[beginningIndex]
      @_beginningIndex++
      return obj
