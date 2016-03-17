Package.describe({
  name: 'birt:info',
  version: '0.1.0',
  summary: 'Display current time/date information in overlay'
});

Package.onUse(function(api){
  api.use([
    'templating',
    'coffeescript',
    'mquandalle:stylus@1.1.1'
  ], 'client');

  api.addFiles([
    'stylesheets/info.styl',

    'info.coffee'
  ], 'client');
});
