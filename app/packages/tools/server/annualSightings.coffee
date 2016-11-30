InvalidBirds = new Mongo.Collection('invalid_birds')
LIMIT = 100000
DEBUG = true
FIRST_YEAR = 1887
LAST_YEAR = 2012
MIN_INSERTION_COUNT = 100
START_TIME = 0

# builds an array of years based on FIRST_YEAR and LAST_YEAR
#
# @return {array} years
getYearlyRange = () ->
  years = []
  low = FIRST_YEAR
  high = LAST_YEAR
  while (low <= high)
    years.push(low++)
  # return
  years

# determines annual counts for species based on signtings
#
# @param {function} done, method to execute when done
getAnnualCounts = (done) ->
  annual = {}
  processed = 0

  years = getYearlyRange()
  years.forEach (year) ->
    startDate = new Date(Date.UTC(year, 1, 1))
    endDate = new Date(Date.UTC(year, 12, 31))
    query = {
      date: {
        $gte: startDate,
        $lt: endDate
      }
    }
    opts = {
      fields: {sightings: 1},
      limit: LIMIT,
      transform: null
    }
    cursor = Migrations.find(query, opts)
    records = cursor.count()
    counts = {}
    cursor.forEach (doc) ->
      if doc
        doc.sightings.forEach (sighting) ->
          bird_id = "#{sighting.bird_id}"
          count = counts[bird_id]
          if typeof count == 'undefined'
            count = sighting.count
          else
            count += sighting.count
          counts[bird_id] = count
          annualCounts = annual[year]
          if typeof annualCounts == 'undefined'
            annualCounts = {}
          annualCount = annualCounts[bird_id]
          if typeof annualCount == 'undefined'
            annualCount = count;
          else
            annualCount += count;
          annualCounts[bird_id] = annualCount
          annual[year] = annualCounts
    if years.length == ++processed
      done(null, annual)

# determines the year with the maximum count for each species
#
# @param {object} annual, hash map of years species counts
# @done {function} done, method to execute when done
selectMax = (annual, done) ->
  max = {}
  Object.keys(annual).forEach (year) ->
    Object.keys(annual[year]).forEach (species) ->
      count = annual[year][species]
      maxCount = max[species]
      if typeof maxCount == 'undefined'
        maxCount = {count: count, year: year}
      else
        if maxCount.count < count
          maxCount.count = count
          maxCount.year = year
      if DEBUG
        console.log "annual[#{year}][#{species}] count:#{count} maxCount: #{maxCount.count}"
      max[species] = maxCount
  # return
  max

# return the recommended dates for a species
#
# @param {number} year, the year to recommend
getRecommendedDates = (year) ->
  recommendedDates = {}
  recommendedDates.startDate = "#{year}-01-01"
  recommendedDates.endDate = "#{year}-12-31"
  # return
  recommendedDates

# sets the recommended_dates within the database on the bird collection
#
# @param {object} max, hash map of species max year
# @done {function} done, method to execute when done
setRecommendedDates = (max, done) ->
  Object.keys(max).forEach (species) ->
    bird = Birds.findOne({_id: species})
    count = max[species].count
    year = max[species].year
    if typeof bird != 'undefined' and count > MIN_INSERTION_COUNT
      recommendedDates = getRecommendedDates(year)
      Birds.update({_id:bird._id}, {$set: {recommended_dates: recommendedDates}})
    else
      InvalidBirds.upsert({_id:species}, {updated: new Date()})
  if DEBUG
    console.log "Finished setting recommended dates for species: #{new Date().getTime() - START_TIME} (ms)"


Meteor.startup ->
  if Meteor.settings.public.runAnnualSightings
    if DEBUG
      START_TIME = new Date().getTime()
      console.log "Started setting recommended dates for species"
    getAnnualCounts (err, res) ->
      if err
        console.error err
      max = selectMax res
      setRecommendedDates max
