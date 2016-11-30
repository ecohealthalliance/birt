MiniMigrations = new Mongo.Collection(null)

# Template.gritsDataTable
Template.gritsDataTable.events
  'click .exportData': (event, instance) ->
    fileType = $(event.currentTarget).attr("data-type")
    activeTable = instance.$('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      activeTable.tableExport(type: fileType)

Template.gritsDataTable.helpers
  migrations: ->
    MiniMigrations.find()

  format: (date) ->
    moment.utc( date ).format('MM/DD/YYYY')

  currentBird: (record) ->
    bird = $("#searchBar").tokenfield('getTokens')[0].label
    record[bird] || 0
