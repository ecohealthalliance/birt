Package.describe({
  name: 'birt:info',
  version: '0.1.0',
  summary: 'Display current time/date information in overlay'
});

Package.onUse(function(api){
  api.use([
    'templating',
    'coffeescript',
    'mquandalle:jade@0.4.9',
    'stylus',
    'momentjs:moment@2.10.6'
  ], 'client');

  api.addFiles([
    'stylesheets/info.styl',

    'templates/info.jade',

    'info.coffee'
  ], 'client');
});
