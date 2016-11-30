Package.describe({
  name: 'birt:scrubber',
  version: '0.1.0',
  summary: 'Controls to play/pause'
});

Package.onUse(function(api){
  api.use([
    'templating',
    'coffeescript',
    'stylus',
    'mquandalle:jade@0.4.9',
    'momentjs:moment@2.10.6',
    'kevbuk:moment-range@2.2.2',
    'crystalhelix:nouislider@1.0.1',
    'reactive-var'
  ], 'client');

  api.addFiles([
    'stylesheets/scrubber.styl',
    'templates/scrubber.jade',
    'scrubber.coffee'
  ], 'client');


});
