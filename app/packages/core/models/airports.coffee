Airports = new Mongo.Collection('airports')
Airport = Astro.Class(
  name: 'Airport'
  collection: Airports
  transform: true
  fields:
    'name': 'string'
    'city': 'string'
    'state': 'string'
    'stateName': 'string'
    'loc': 'object'
    'loc.type': 'string'
    'loc.coordinates': 'array'
    'country': 'number'
    'countryName': 'string'
    'globalRegion': 'string'
    'WAC': 'number'
    'notes': 'string'
  events: {}
  methods: {})

#_airportRegexSearchTmpl = _.template(".*?(?:^|\s)(<%=search%>[^\s$]*).*?")
_airportRegexSearchTmpl = _.template("<%=search%>")

# return a shared object between client/server that can be used to determine
# typeahead matches
# @note static method
# @return [Object] typeaheadMatcher, object containing helper values for sharing regex and display options between client and server
Airport.typeaheadMatcher = () ->
  WAC: {weight: 0, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'WAC'}
  notes: {weight: 1, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'Notes'}
  globalRegion: {weight: 2, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'Global Region'}
  countryName: {weight: 3, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'Country Name'}
  country: {weight: 4, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'Country'}
  stateName: {weight: 5, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'State Name'}
  state: {weight: 6, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'State'}
  city: {weight: 7, regexSearch: _airportRegexSearchTmpl, regexOptions: 'ig', display: 'City'}
  name: {weight: 8, regexSearch: _airportRegexSearchTmpl, regexOptions: 'i', display: null}
  _id: {weight: 9, regexSearch: _airportRegexSearchTmpl, regexOptions: 'i', display: null}
