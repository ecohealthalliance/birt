Heatmaps = new Mongo.Collection(null)
Heatmap = Astro.Class(
  name: 'Heatmap'
  collection: Heatmaps
  fields:
    'lastModified': 'date'
    'version': 'string'
    'simulatedPassengers': 'number'
    'data': 'array'
  events: { }
  methods: { }
)
Heatmap.createFromDoc = (doc, airportToCoordinates) ->
  heatmap = new Heatmap(doc)
  # ignore the fields of the constructor
  ignore = Object.keys(heatmap.constructor.getFields())
  # the diff is a list of codes
  codes = _.difference(Object.keys(doc), ignore)
  # map the data
  data = []
  _.each(doc, (value, key) ->
    if airportToCoordinates[key]
      data.push([airportToCoordinates[key][1], airportToCoordinates[key][0], value, key])
  )
  heatmap.set("data", data)
  heatmap.save()
  return heatmap
