Package.describe({
  summary: 'Geo-spatial/ecological analysis of bird migrations',
  version: '0.0.1',
  name: 'birt:core',
  git: ''
});

Package.onUse(function(api){
  // client and server packages
  api.use([
    'underscore',
    'coffeescript',
    'mongo',
    'reactive-var',
    'reactive-dict',
    'http',
    'jagi:astronomy@1.2.5',
    'jagi:astronomy-validators@1.1.1',
    'peerlibrary:async@0.9.2_1',
    'twbs:bootstrap@3.3.5',
    'mquandalle:stylus@1.1.1',
    'jparker:crypto-md5@0.1.1',
    'bevanhunt:leaflet@0.3.18',
    'brylie:leaflet-heat@0.1.0',
    'fortawesome:fontawesome@4.4.0',
    'd3js:d3@3.5.5',
    'fourq:typeahead@1.0.0',
    'ajduke:bootstrap-tokenfield@0.5.0',
    'flawless:meteor-toastr@1.0.1',
    'meteorhacks:aggregate@1.3.0',
    'momentjs:moment@2.10.6',
    'jaywon:meteor-node-uuid@1.0.1',
    'kidovate:bootstrap-slider@0.0.5',
    'tsega:bootstrap3-datetimepicker@4.17.37_1',
    'halunka:i18n@1.1.1',
    'momentjs:moment@2.10.6',
    'kevbuk:moment-range@2.2.2',
    'kadira:flow-router@2.10.1',
    'zenorocha:clipboard@1.5.8',
    'andrei:tablesorter@0.0.1',
    'okgrow:analytics@1.0.4',
    'grits:flirt-sidebar@0.0.1'
  ]);

  // client only packages
  api.use([
    'templating',
    'minimongo',
    'session',
    'tracker'
  ], 'client');

  // both client and server files
  api.addFiles([
    'models/airports.coffee',
    'models/flights.coffee',
    'models/heatmaps.coffee',
    'models/itineraries.coffee',
    'models/simulations.coffee',
    'models/birds.coffee',
    'models/migrations.coffee',
    'lib/routes.coffee'
  ]);

  // client-side only files
  // IMPORTANT: these files are loaded in order
  api.addFiles([
    'client/stylesheets/variables.import.styl',
    'client/stylesheets/mixins.import.styl',
    'client/stylesheets/globals.import.styl',
    'client/stylesheets/sidebar.import.styl',
    'client/stylesheets/sidebar_table.import.styl',
    'client/stylesheets/birt.import.styl',
    'client/stylesheets/main.styl',
    'client/stylesheets/overlay.styl',
    'client/lib/L.D3SvgOverlay.min.js',
    'client/lib/tableExport.min.js',
    'client/lib/webgl-heatmap.js',
    'client/lib/webgl-heatmap-leaflet.js',
    'client/grits_constants.coffee',
    'client/mapper/grits_layer.coffee',
    'client/mapper/grits_marker.coffee',
    'client/mapper/grits_node.coffee',
    'client/mapper/grits_path.coffee',
    'client/mapper/grits_meta_node.coffee',
    'client/mapper/grits_map.coffee',
    'client/mapper/grits_bounding_box.coffee',
    'client/startup.coffee',
    'client/grits_util.coffee',
    'client/grits_filter_criteria.coffee',
    'client/layers/grits_layer_group.coffee',
    'client/layers/grits_nodes.coffee',
    'client/layers/grits_all_nodes.coffee',
    'client/layers/grits_paths.coffee',
    'client/layers/grits_heatmap.coffee',
    'client/templates/header.html',
    'client/templates/grits_dataTable.html',
    'client/templates/grits_dataTable.coffee',
    'client/templates/grits_layerSelector.html',
    'client/templates/grits_layerSelector.coffee',
    'client/templates/grits_map.html',
    'client/templates/grits_map_sidebar.html',
    'client/templates/grits_map_sidebar.coffee',
    'client/templates/grits_map_table_sidebar.html',
    'client/templates/grits_map.coffee',
    'client/templates/grits_search.html',
    'client/templates/grits_search.coffee',
    'client/templates/grits_legend.html',
    'client/templates/grits_legend.coffee',
    'client/templates/grits_elementDetails.html',
    'client/templates/grits_elementDetails.coffee',
    'client/templates/loading.html',
    'client/templates/grits_overlay.html',
    'client/templates/grits_overlay.coffee'
  ], 'client');

  // static assets
  api.addAssets([
    'public/images/asc.png',
    'public/images/birt-logo-inline.png',
    'public/images/desc.png',
    'public/images/flirt.png',
    'public/images/origin-marker-icon.svg',
    'public/images/viridis.png'
  ], 'client');

  // server-side only files
  api.add_files([
    'server/locale/translations.i18n.json',
    'server/startup.coffee',
    'server/publications.coffee'
  ], 'server');

  // public API, client and server
  api.export([
    'FlowRouter',
    'Airport',
    'Airports',
    'Flight',
    'Flights',
    'Heatmap',
    'Heatmaps',
    'Simulation',
    'Simulations',
    'Bird',
    'Birds',
    'Migrations',
    'GritsConstants',
    'GritsBoundingBox',
    'GritsControl',
    'GritsFilterCriteria',
    'GritsLayer',
    'GritsLayerGroup',
    'GritsMap',
    'GritsMarker',
    'GritsMetaNode',
    'GritsNode',
    'GritsPath',
    'GritsHeatmapLayer',
    'GritsNodeLayer',
    'GritsAllNodesLayer',
    'GritsPathLayer',
    'Itinerary',
    'Itineraries',
    'i18n'
  ]);
});

Package.onTest(function(api) {
  api.versionsFrom('1.2.1');
  api.use('xolvio:cucumber');
});
