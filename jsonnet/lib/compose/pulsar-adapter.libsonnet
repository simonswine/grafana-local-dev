local prometheus = import 'compose/prometheus.libsonnet';
{
  _images+:: {
    'pulsar-adapter': 'todo',
  },

  new(name='pulsaradapter')::
    {
      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images['pulsar-adapter'],
            ports: [
              9201,
            ],
          },
        },
      },
    } +
    prometheus.addScrapeConfig(
      'pulsar-adapter', {
        static_configs+: [{
          targets: [
            '%s:9201' % name,
          ],

          labels: {
            instance: name,
          },
        }],
      },
    ),
}
