_useAggregation = true # enable/disable using the aggregation framework
_profile = false # enable/disable recording method performance to the collection 'profiling'

# collection to record profiling results
Profiling = new Mongo.Collection('profiling')
# records a profile document to mongo when profiling is enabled
#
# @param [String] methodName, the name of the method that is being profiled
# @param [Integer] elsapsedTime, the elapsed time in milliseconds
recordProfile = (methodName, elapsedTime) ->
  Profiling.insert({methodName: methodName, elapsedTime: elapsedTime, created: new Date()})
  return

# determines if the runtime environment is for testing
#
# @return [Boolean] isTest, true or false
isTestEnvironment = ->
  return process.env.hasOwnProperty('VELOCITY_MAIN_APP_PATH')

# finds documents that match the search
#
# @param [String] name, the collection name to search
# @param [String] search, the string to search for matches
# @param [Integer] skip, the amount of documents to skip in limit/offset
# @return [Array] matches, an array of matching documents
typeahead = (name, search, skip) ->
  if _profile
    start = new Date()
  if typeof skip == 'undefined'
    skip = 0
  fields = []
  models = {'birds': Bird}
  model = models[name.toLowerCase()]
  collections = {'birds': Birds}
  collection = collections[name.toLowerCase()]

  for fieldName, matcher of model.typeaheadMatcher()
    field = {}
    field[fieldName] = {$regex: new RegExp(matcher.regexSearch({search: search}), matcher.regexOptions)}
    fields.push(field)

  matches = []
  if _useAggregation
    pipeline = [
      {$match: {$or: fields}},
      {$skip: skip},
      {$limit: 10}
    ]
    matches = collection.aggregate(pipeline)
  else
    query = { $or: fields }
    matches = collection.find(query, {limit: 10, skip: skip, transform: null}).fetch()

  if _profile
    recordProfile('typeahead', new Date() - start)
  return matches

# counts the number of birds that match the search
#
# @param [String] search, the string to search for matches
# @return [Integer] count, the number of documents matching the search
countTypeaheadBirds = (search) ->
  if _profile
    start = new Date()

  fields = []
  for fieldName, matcher of Bird.typeaheadMatcher()
    field = {}
    field[fieldName] = {$regex: new RegExp(matcher.regexSearch({search: search}), matcher.regexOptions)}
    fields.push(field)

  query = { $or: fields }
  count = Birds.find(query, {transform: null}).count()

  if _profile
    recordProfile('countTypeaheadAirports', new Date() - start)
  return count

# find migrations with an optional limit and offset
#
# @param [Object] query, a mongodb query object
# @param [Integer] limit, the amount of records to limit
# @param [Integer] skip, the amount of records to skip
# @return [Array] an array of documents
migrationsByQuery = (startDate, endDate, tokens, limit, skip) ->
  if _profile
    start = new Date()

  if _.isUndefined(startDate) or _.isEmpty(startDate)
    return []
  if _.isUndefined(endDate) or _.isEmpty(endDate)
    return []
  if _.isUndefined(tokens) or _.isEmpty(tokens)
    return []

  if _.isUndefined(limit)
    limit = 0
  if _.isUndefined(skip)
    skip = 0

  query = {
    date: {
      $gte: new Date(startDate),
      $lt: new Date(endDate)
    },
    $or: []
  }
  fields = {date: 1, country: 1, state_province: 1, county: 1, loc: 1, sightings: 1}
  _.each(tokens, (t) ->
    obj = {}
    obj[t] = {$gte: 1}
    query.$or.push(obj)
    fields[t] = 1
  )

  matches = []
  if _useAggregation
    # prepare the aggregate pipeline
    pipeline = [
      {$match: query},
      {$project: fields},
      {$sort: {date: 1}},
      {$skip: skip},
      {$limit: limit}
    ]
    matches = Migrations.aggregate(pipeline)
  else
    matches = Migrations.find(query, {fields: fields, limit: limit, skip: skip, sort: {date: 1}, transform: null}).fetch()

  if _profile
    recordProfile('migrationsByQuery', new Date() - start)
  return matches

# count the total migrations for the specified date range
#
# @param [Object] query, a mongodb query object
# @return [Integer] totalRecorts, the count of the query
countMigrationsByDateRange = (startDate, endDate, tokens) ->
  if _profile
    start = new Date()

  query = {
    date: {
      $gte: new Date(startDate),
      $lt: new Date(endDate)
    }
    $or: []
  }
  _.each(tokens, (t) ->
    obj = {}
    obj[t] = {$gte: 1}
    query.$or.push(obj)
  )

  if _.isUndefined(startDate) or _.isEmpty(startDate)
    return 0
  if _.isUndefined(endDate) or _.isEmpty(endDate)
    return 0

  count = Migrations.find(query, {transform: null}).count()

  if _profile
    recordProfile('countMigrationsByDateRange', new Date() - start)
  return count

# find migrations within an array of dates
#
# @note optional limit and offset
# @param [Array] dates, an array of dates
# @param [String] token, the token from the UI filter
# @param [Integer] limit, the amount of records to limit
# @param [Integer] skip, the amount of records to skip
# @return [Array] an array of documents
migrationsByDates = (dates, tokens, limit, skip) ->
  if _profile
    start = new Date()

  if _.isUndefined(dates) or _.isEmpty(dates)
    return []
  if _.isUndefined(tokens) or _.isEmpty(tokens)
    return []

  if _.isUndefined(limit)
    limit = 0
  if _.isUndefined(skip)
    skip = 0

  query = {
    date: {$in: _.map(dates, (dateStr) -> new Date(dateStr))},
    $or: []
  }
  fields = {date: 1, country: 1, state_province: 1, county: 1, loc: 1}
  _.each(tokens, (t) ->
    obj = {}
    obj[t] = {$gte: 1}
    query.$or.push(obj)
    fields[t] = 1
  )

  _.each(tokens, (t) -> )

  matches = []
  if _useAggregation
    # prepare the aggregate pipeline
    pipeline = [
      {$match: query},
      {$project: fields},
      {$sort: {date: 1}},
      {$skip: skip},
      {$limit: limit}
    ]
    matches = Migrations.aggregate(pipeline)
  else
    matches = Migrations.find(query, {fields: fields, limit: limit, skip: skip, sort: {date: 1}, transform: null}).fetch()

  if _profile
    recordProfile('migrationsByDates', new Date() - start)
  return matches

migrationsBySeason = (params)->
  MAX_RESULTS = 500
  query = switch params.season
    when "autumn" then {
      $and: [{
        month:
          $gte: 9
      }, {
        month:
          $lte: 11
      }]
    }
    when "winter" then {
      $or: [{
        month:
          $gte: 12
      }, {
        month:
          $lte: 2
      }]
    }
    when "spring" then {
      $and: [{
        month:
          $gte: 3
      }, {
        month:
          $lte: 5
      }]
    }
    when "summer" then {
      $and: [{
        month:
          $gte: 6
      }, {
        month:
          $lte: 8
      }]
    }
    else throw new Meteor.Error("Unknown season:" + season)
  if not params.birds or params.birds.length == 0
    throw new Meteor.Error("An array of birds is required.")
  query['sightings.bird_id'] = {$in: params.birds}
  Migrations.find(query, {
    limit: MAX_RESULTS
    fields:
      loc: 1
      sightings: 1
      date: 1
      country: 1
      state_province: 1
      county: 1
  }).fetch()


# count the total migrations for the specified date range
#
# @param [Array] dates, an array of dates
# @return [Integer] totalRecorts, the count of the query
countMigrationsByDates = (dates, tokens) ->
  if _profile
    start = new Date()

  if _.isUndefined(dates) || _.isEmpty(dates)
    return 0

  if _.isUndefined(tokens) || _.isEmpty(tokens)
    return 0

  query = {
    date: {$in: _.map(dates, (dateStr) -> new Date(dateStr))},
    $or: []
  }
  _.each(tokens, (t) ->
    obj = {}
    obj[t] = {$gte: 1}
    query.$or.push(obj)
  )

  count = Migrations.find(query, {transform: null}).count()

  if _profile
    recordProfile('countMigrationsByDateRange', new Date() - start)
  return count


# Public API
Meteor.methods
  typeahead: typeahead
  countTypeaheadBirds: countTypeaheadBirds
  migrationsByQuery: migrationsByQuery
  countMigrationsByDateRange: countMigrationsByDateRange
  migrationsByDates: migrationsByDates
  countMigrationsByDates: countMigrationsByDates
  migrationsBySeason: migrationsBySeason

