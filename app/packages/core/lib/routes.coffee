# FlowRouter adds lightweight client-side routing

# Keep track of the currentURL reactively
FlowRouter.currentURL = new ReactiveVar('')
FlowRouter.triggers.enter([(context) ->
  FlowRouter.currentURL.set(FlowRouter.url(context.path))
])

# This route will set the SESSION_KEY_SHARED_SIMID to the matching
# url param.
FlowRouter.route('/simulation/:simId', {
  action: (params, queryParams) ->
    if !params.hasOwnProperty('simId')
      return
    if _.isEmpty(params.simId)
      return
    Session.set(GritsConstants.SESSION_KEY_SHARED_SIMID, params.simId)
})
# The index route just lets the normat app flow happen
FlowRouter.route('/', {
  action: (params, queryParams) -> return
})
# silently ignore invalid client urls; it will not have any effect on the app
FlowRouter.notFound = {
  action: () -> return
}
