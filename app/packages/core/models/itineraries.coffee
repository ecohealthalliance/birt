Itineraries = new Mongo.Collection('simulated_itineraries')
Itinerary = Astro.Class(
  name: 'Itinerary'
  collection: Itineraries
  transform: true
  fields:
    # _id is md5 hash of (effectiveDate, carrier, flightNumber)
    '_id': 'string'
    'simulationId': 'string'
    'origin': 'string'
    'destination': 'string'
  events: {}
  methods: {})
