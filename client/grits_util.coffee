Meteor.gritsUtil =
  debug: true
  errorHandler: (err) ->
    if typeof err != 'undefined'
      if err.hasOwnProperty('message')
        toastr.error(err.message)
      else
        toastr.error(err)
        console.error(err)
    Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
    GritsFilterCriteria.isSimulationRunning.set(false)
    return
  # smooth out the rate at which the given function is called by queuing up calls
  # and spreading them out over time.
  smoothRate: (func)->
    BASE_CALLS_PER_SECOND = 10
    queue = []
    active = false
    MAX_DELAY_SECONDS = 5
    callsPerSecond = BASE_CALLS_PER_SECOND
    timeoutFunc = ->
      callsToDo = callsPerSecond
      while callsToDo > 0
        callsToDo--
        queuedCall = queue.shift()
        if not queuedCall
          break
        [self, args] = queuedCall
        func.apply(self, args)
      # calls required to keep up with the queue without going over the max delay
      requiredCallsPerSecond = queue.length / MAX_DELAY_SECONDS
      callsPerSecond = Math.max(requiredCallsPerSecond, callsPerSecond)
      if queue.length > 0
        setTimeout(
          timeoutFunc,
          900 # less than 1000 because we assume the calls take 100ms
        )
      else
        callsPerSecond = BASE_CALLS_PER_SECOND
        active = false
    (args...)->
      queue.push([this, args])
      if not active
        active = true
        setTimeout(timeoutFunc, 900)
