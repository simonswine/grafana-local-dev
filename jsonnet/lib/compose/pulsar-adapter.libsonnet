local prometheus = import 'compose/prometheus.libsonnet';
{
  _images+:: {
    'pulsar-adapter': 'todo',
  },

  new(name='pulsaradapter', port=null)::
    {
      local port_mapping =
        if port != null then
          '%d:9201' % port
        else
          '9201',

      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images['pulsar-adapter'],
            ports: [
              port_mapping,
            ],
          },
        },
      },
    } +
    prometheus.addScrapeConfig(
      'pulsar-adapter', {
        dns_sd_configs+: [{
          names: [name],
          type: 'A',
          port: 9201,
          refresh_interval: '5s',
        }],
        relabel_configs: [{
          source_labels: ['__meta_dns_name'],
          action: 'replace',
          target_label: 'dns_name',
          regex: '(.+)',
        }],
      },
    ),
}
