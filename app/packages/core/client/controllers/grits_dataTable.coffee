MiniMigrations = new Mongo.Collection(null)

# Template.gritsDataTable
Template.gritsDataTable.events

Template.gritsDataTable.helpers
  migrations: ->
    MiniMigrations.find()
  format: (date) ->
    moment.utc( date ).format('MM/DD/YYYY')

# Template.gritsDataTable.onRendered ->
#   return
