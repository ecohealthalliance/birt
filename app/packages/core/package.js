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
    'http',
    'jagi:astronomy@1.2.5',
    'jagi:astronomy-validators@1.1.1',
    'peerlibrary:async@0.9.2_1',
    'jparker:crypto-md5@0.1.1',
    'bevanhunt:leaflet@0.3.18',
    'fourq:typeahead@1.0.0',
    'ajduke:bootstrap-tokenfield@0.5.0',
    'flawless:meteor-toastr@1.0.1',
    'meteorhacks:aggregate@1.3.0',
    'momentjs:moment@2.10.6',
    'jaywon:meteor-node-uuid@1.0.1',
    'tsega:bootstrap3-datetimepicker@4.17.37_1',
    'halunka:i18n@1.1.1',
    'kevbuk:moment-range@2.2.2',
    'andrei:tablesorter@0.0.1',
    'okgrow:analytics@1.0.4',
  ]);

  // client only packages
  api.use([
    'templating',
    'minimongo',
    'session',
    'mquandalle:jade@0.4.9',
    'twbs:bootstrap@3.3.5',
    'stylus',
    'fortawesome:fontawesome@4.5.0',
    'sidebar-main',
    'sidebar-tabular'
  ], 'client');

  // both client and server files
  api.addFiles([
    'models/birds.coffee',
    'models/migrations.coffee'
  ]);

  // client-side only files
  // IMPORTANT: these files are loaded in order
  api.addFiles([
    'client/stylesheets/globals.import.styl',
    'client/stylesheets/birt.import.styl',
    'client/stylesheets/main.styl',
    'client/stylesheets/map.import.styl',
    'client/stylesheets/overlay.import.styl',
    'client/stylesheets/tables.import.styl',
    'client/stylesheets/tokens.import.styl',
    'client/stylesheets/toasts.import.styl',
    'client/stylesheets/lists.import.styl',
    'client/stylesheets/layers.import.styl',
    'client/lib/tableExport.min.js',
    'client/lib/webgl-heatmap.js',
    'client/lib/webgl-heatmap-leaflet.js',
    'client/animation/FrameBuffer.coffee',
    'client/animation/Frame.coffee',
    'client/grits_constants.coffee',
    'client/mapper/grits_layer.coffee',
    'client/mapper/grits_map.coffee',
    'client/startup.coffee',
    'client/grits_util.coffee',
    'client/grits_filter_criteria.coffee',
    'client/layers/grits_layer_group.coffee',
    'client/layers/grits_heatmap.coffee',
    'client/templates/header.jade',
    'client/templates/grits_dataTable.jade',
    'client/controllers/grits_dataTable.coffee',
    'client/templates/grits_layerSelector.jade',
    'client/controllers/grits_layerSelector.coffee',
    'client/templates/grits_map.jade',
    'client/controllers/grits_map.coffee',
    'client/templates/grits_search.jade',
    'client/controllers/grits_search.coffee',
    'client/templates/grits_overlay.jade',
    'client/controllers/grits_overlay.coffee',
    'client/postMessageHandler.coffee'
  ], 'client');

  // static assets
  api.addAssets([
    'public/images/asc.png',
    'public/images/birt.png',
    'public/images/birt-logo-inline.png',
    'public/images/desc.png',
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
    'Bird',
    'Birds',
    'Migrations',
    'MiniMigrations',
    'GroupedMigrations',
    'GritsConstants',
    'GritsFilterCriteria',
    'GritsLayer',
    'GritsLayerGroup',
    'GritsMap',
    'GritsHeatmapLayer',
    'Frame',
    'FrameBuffer',
    'i18n'
  ]);
});

Package.onTest(function(api) {
  api.versionsFrom('1.2.1');
  api.use('xolvio:cucumber');
});
