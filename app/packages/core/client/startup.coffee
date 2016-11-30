Meteor.startup ->
  # NOTE: *the gritsOverlay indicator will be showing by default*

  # initialize Session variables
  Session.set(GritsConstants.SESSION_KEY_IS_UPDATING, false)
  Session.set(GritsConstants.SESSION_KEY_LOADED_RECORDS, 0)
  Session.set(GritsConstants.SESSION_KEY_TOTAL_RECORDS, 0)
  Session.set(GritsConstants.SESSION_KEY_IS_READY, false) # the map will not be displayed until isReady is set to true

  # async flow control so we can set grits-net-meteor:isReady true when done
  if Meteor.gritsUtil.debug
    start = new Date()
    console.log('start sync [i18n]')
  async.auto
    'i18n': (callback, result) ->
      # string externalization/i18n
      Template.registerHelper('_', i18n.get)
      i18n.loadAll ->
        i18n.setLanguage('en')
        if Meteor.gritsUtil.debug
          console.log('done i18n')
        callback(null, true)

  , (err, result) ->
    if err
      console.error(err)
      return
    if Meteor.gritsUtil.debug
      console.log('end sync [i18n] (ms): ', new Date() - start)

    # Hide the gritsOverlay indicator
    Template.gritsOverlay.hide()
    # Mark the app ready
    Session.set GritsConstants.SESSION_KEY_IS_READY, true
