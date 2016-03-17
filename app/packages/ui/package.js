Package.describe({
  name: 'birt:ui',
  version: '0.1.0',
  summary: 'Provides geo-spatial/ecological analysis of bird migrations'
});

Package.onUse(function(api){
  // client and server packages
  api.use([
    'underscore',
    'coffeescript',
    'mongo',
    'reactive-var',
    'reactive-dict'
  ]);

  // client only packages
  api.use([
    'templating',
    'minimongo',
    'session'
  ], 'client');

  // client-side only files
  // IMPORTANT: these files are loaded in order
  api.addFiles([
    'html/moduleSelector.html',
    'html/birt.html',

    'css/main.css',

    'ui.coffee'
  ], 'client');
});
