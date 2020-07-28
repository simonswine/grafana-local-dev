local prometheus = import 'compose/prometheus.libsonnet';
{
  _images+:: {
    pulsar: 'apachepulsar/pulsar:2.6.0',
    'pulsar-dashboard': 'apachepulsar/pulsar-dashboard:2.6.0',
  },

  new(name='pulsar')::
    {
      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images.pulsar,
            command: |||
              /bin/bash -c "bin/apply-config-from-env.py conf/standalone.conf && exec bin/pulsar standalone"
            |||,
            ports: [
              8080,
              6650,
            ],
            environment: {
              PULSAR_MEM: ' -Xms512m -Xmx512m -XX:MaxDirectMemorySize=1g',
            },
          },
          ['%s-dashboard' % name]+: {
            image: $._images['pulsar-dashboard'],
            ports: [
              '8081:80',
            ],
            environment: {
              SERVICE_URL: 'http://pulsar:8080',
            },
          },
        },
      },
    } +
    prometheus.addScrapeConfig(
      'pulsar', {
        static_configs+: [{
          targets: [
            '%s:8080' % name,
          ],

          labels: {
            instance: name,
          },
        }],
      },
    ),
}
