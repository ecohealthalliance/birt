Package.describe({
  name: 'birt:tools',
  version: '0.0.1',
  summary: 'Database tools for birt',
});

Package.onUse(function(api) {
  api.versionsFrom('1.2.1');
  api.use([
    'coffeescript',
    'ecmascript',
    'mongo',
    'underscore'
  ]);
  api.addFiles(['server/annualSightings.coffee'], 'server');
});
