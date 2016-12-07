MiniMigrations = new Mongo.Collection(null)
GroupedMigrations = new Mongo.Collection(null)

Template.gritsDataTable.onCreated ->
  @selectedGroupedMigrations = new ReactiveVar null

Template.gritsDataTable.events
  'click .exportData': (event, instance) ->
    fileType = $(event.currentTarget).attr("data-type")
    activeTable = instance.$('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      activeTable.tableExport(type: fileType)

  'click .pathTableRow': (event, instance) ->
    currentlySelected = instance.selectedGroupedMigrations
    if currentlySelected.get() is @_id
      selected = null
    else
      selected = @_id
    currentlySelected.set(selected)

Template.gritsDataTable.helpers
  migrations: ->
    MiniMigrations.find()

  groupedMigrations: ->
    GroupedMigrations.find()

  format: (date) ->
    moment.utc( date ).format('MM/DD/YYYY')

  dailySightings: ->
    bird = GritsFilterCriteria.tokens.get()[0]
    @[bird] or 0

  groupedMigrationsCount: ->
    bird = GritsFilterCriteria.tokens.get()[0]
    sightings = _.pluck(@data, bird)

    # add all these up
    _.reduce sightings, (a, b) ->
      a + b

  groupsSelected: ->
    Template.instance().selectedGroupedMigrations.get()

  selected: ->
    @_id is Template.instance().selectedGroupedMigrations.get()
