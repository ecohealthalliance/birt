Package.describe({
  name: 'sidebar-tabular',
  version: '0.0.1',
  git: 'https://github.com/ecohealthalliance/flirt',
});

Package.onUse(function(api) {
  api.versionsFrom('1.2.1');

  api.use([
    'coffeescript',
    'blaze-html-templates',
    'mquandalle:jade@0.4.9',
    'stylus',
    'reactive-var',
    'sidebar',
    'stevenn:hintcss'
  ], 'client');


  api.addFiles([
    'main.styl',
    'tabular_sidebar.jade',
    'tabular_sidebar.coffee',
  ], 'client');

});
