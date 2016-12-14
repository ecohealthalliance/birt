Birds = new Mongo.Collection('birds')
Bird = Astro.Class(
  name: 'Bird'
  collection: Birds
  transform: true
  fields:
    'taxon_order': 'number'
    'primary_com_name': 'string'
    'category': 'string'
    'order_name': 'string'
    'family_name': 'string'
    'subfamily_name': 'string'
    'genus_name': 'string'
    'species_name': 'string'
    'recommended_dates': 'object'
  events: {}
  methods: {})

#_regexSearchTmpl = _.template(".*?(?:^|\s)(<%=search%>[^\s$]*).*?")
_regexSearchTmpl = _.template("<%=search%>")

# return a shared object between client/server that can be used to determine
# typeahead matches
# @note static method
# @return [Object] typeaheadMatcher, object containing helper values for sharing regex and display options between client and server
Bird.typeaheadMatcher = () ->
  taxon_order: {weight: 0, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Taxon Order'}
  subfamily_name: {weight: 1, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Subfamily Name'}
  order_name: {weight: 2, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Order Name'}
  family_name: {weight: 3, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Family Name'}
  category: {weight: 4, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Category'}
  genus_name: {weight: 5, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Genus Name'}
  species_name: {weight: 6, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Species Name'}
  primary_com_name: {weight: 7, regexSearch: _regexSearchTmpl, regexOptions: 'ig', display: 'Name'}
  _id: {weight: 8, regexSearch: _regexSearchTmpl, regexOptions: 'i', display: null}
