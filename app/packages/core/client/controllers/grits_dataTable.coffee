MiniMigrations = new Mongo.Collection(null)

# Template.gritsDataTable
Template.gritsDataTable.events
  'click .exportData': (event, instance) ->
    # $('.dtHidden').show()
    fileType = $(event.currentTarget).attr("data-type")
    activeTable = instance.$('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      activeTable.tableExport({type: fileType})
    # $('.dtHidden').hide()
    return

Template.gritsDataTable.helpers
  migrations: ->
    MiniMigrations.find()
  format: (date) ->
    moment.utc( date ).format('MM/DD/YYYY')

# Template.gritsDataTable.onRendered ->
#   return
