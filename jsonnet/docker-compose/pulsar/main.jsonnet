local cortex = import 'compose/cortex.libsonnet';
local grafana = import 'compose/grafana.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';
local pulsar_adapter = import 'compose/pulsar-adapter.libsonnet';
local pulsar = import 'compose/pulsar.libsonnet';
local cortexMixin = import 'cortex-mixin/mixin.libsonnet';

prometheus.new() +
pulsar.new() +
pulsar_adapter.new() +
{
  'docker-compose.yaml'+: {
    version: '3.3',

    // use local image for pulsar adapter
    services+: {
      pulsaradapter+: {
        image:: null,
        build: '~/git/github.com/grafana/prometheus-pulsar-remote-write',
        command: [
          '--pulsar.url=pulsar://pulsar:6650',
        ],
      },
    },
  },
  'file-prometheus-config'+: {
    remote_write+: [{
      url: 'http://pulsaradapter:9201/write',
    }],
  },
}
