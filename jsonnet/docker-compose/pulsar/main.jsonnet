local cortex = import 'compose/cortex.libsonnet';
local grafana = import 'compose/grafana.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';
local pulsar_adapter = import 'compose/pulsar-adapter.libsonnet';
local pulsar = import 'compose/pulsar.libsonnet';
local cortexMixin = import 'cortex-mixin/mixin.libsonnet';

local tls = true;

prometheus.new() +
pulsar.new(tls=tls) +
pulsar_adapter.new() +
{
  'docker-compose.yaml'+: {
    version: '3.3',

    // use local image for pulsar adapter
    services+: {
      pulsaradapter+: {
        image:: null,
        build: '~/git/github.com/grafana/prometheus-pulsar-remote-write',
        command:
          (if tls then [
             '--pulsar.url=pulsar+ssl://pulsar:6651',
             '--pulsar.client-certificate=/certs/client.crt',
             '--pulsar.client-key=/certs/client.key',
             '--pulsar.certificate-authority=/certs/ca.crt',
           ] else [
             '--pulsar.url=pulsar://pulsar:6650',
           ]) + [
            '--log.level=debug',
          ],
        user: 'root',
        volumes+: [
          'pulsar-cert:/certs',
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
