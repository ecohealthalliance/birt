_loading = false

show = ->
  _loading = true
  $('.grits-overlay').show()
  return
hide = ->
  # force UI clicks to be ignored
  async.nextTick( ->
    _loading = false
    $('.grits-overlay').hide()
  )

isLoading = ->
  return _loading

# Template.gritsOverlay.onCreated ->
#   # Public API
#   # Currently we declare methods above for documentation purposes then assign
#   # to the Template.gritsSearch as a global export
Template.gritsOverlay.show = show
Template.gritsOverlay.hide = hide
Template.gritsOverlay.isLoading = isLoading
