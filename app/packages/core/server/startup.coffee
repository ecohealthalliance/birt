Meteor.startup ->
  # setup i18n
  i18n.addLanguage('en', 'English')

  # Ensure indexes on migrations
  Migrations._ensureIndex(date: 1)
