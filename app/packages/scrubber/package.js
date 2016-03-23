Package.describe({
  name: 'birt:scrubber',
  version: '0.1.0',
  summary: 'Controls to play/pause'
});

Package.onUse(function(api){
  api.use([
    'templating',
    'coffeescript',
    'mquandalle:stylus@1.1.1',
    'reactive-var'
  ], 'client');

  api.addFiles([
    'stylesheets/scrubber.styl',

    'templates/scrubber.html',

    'scrubber.coffee'
  ], 'client');
});
