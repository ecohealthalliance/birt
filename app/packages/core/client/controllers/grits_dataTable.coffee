MiniMigrations = new Mongo.Collection(null)
GroupedMigrations = new Mongo.Collection(null)

# Template.gritsDataTable
Template.gritsDataTable.events
  'click .exportData': (event, instance) ->
    fileType = $(event.currentTarget).attr("data-type")
    activeTable = instance.$('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      activeTable.tableExport(type: fileType)
  'click .pathTableRow': (e) ->
    e.preventDefault();
    $('#' + this._id).toggle()
    debugger

Template.gritsDataTable.helpers
  migrations: ->
    MiniMigrations.find()
  groupedMigrations: ->
    GroupedMigrations.find()
  format: (date) ->
    moment.utc( date ).format('MM/DD/YYYY')
  currentBird: (record) ->
    bird = $("#searchBar").tokenfield('getTokens')[0].label
    record[bird] || 0
  groupedMigrationsCount: (record) ->
    bird = $("#searchBar").tokenfield('getTokens')[0].label
    sightings = _.pluck(record.data, bird) 
    
    # add all these up   
    _.reduce(sightings, (a, b) ->
      a + b
    )