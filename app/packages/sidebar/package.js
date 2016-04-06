Package.describe({
  name: 'birt:sidebar',
  version: '0.0.1',
  summary: 'Leaflet sidebar module'
});

Package.onUse(function (api) {
  api.versionsFrom('1.2.1');

  api.addFiles('lib/leaflet-sidebar.js', 'client');
  api.addFiles('stylesheets/leaflet-sidebar.css', 'client');
});
