Package.describe({
  name: 'styles-base',
  version: '0.0.1',
  git: 'https://github.com/ecohealthalliance/flirt',
});

Package.onUse(function(api) {
  api.versionsFrom('1.2.1');

  api.use('stylus');

  api.addFiles('variables.styl', 'client', {isImport: true});
  api.addFiles('mixins.styl', 'client', {isImport: true});
  api.addFiles('tooltips.styl', 'client', {isImport: true});
  api.addFiles('rupture.styl', 'client', {isImport: true});
});
