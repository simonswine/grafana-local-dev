local cortex = import 'compose/cortex.libsonnet';
local grafana = import 'compose/grafana.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';
local pulsar_adapter = import 'compose/pulsar-adapter.libsonnet';
local pulsar = import 'compose/pulsar.libsonnet';
local cortexMixin = import 'cortex-mixin/mixin.libsonnet';

local tls = true;

prometheus.new() +
cortex.new(config=cortex.singleProcess) +
pulsar.new(tls=tls) +
pulsar_adapter.new(name='producer') +
pulsar_adapter.new(name='consumer') +
grafana.new() +
grafana.addDashboard('Pulsar/pulsar-adapter', (import 'dashboard.jsonnet')) +
{
  'docker-compose.yaml'+: {
    version: '3.3',

    // use local image for pulsar adapter
    services+: {
      local pulsarAdapter = {
        image: 'grafana/prometheus-pulsar-remote-write:dev',
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
            '--pulsar.topic=christian-topic',
            '--pulsar.serializer=json-compat',
          ],
        user: 'root',
        volumes+: [
          'pulsar-cert:/certs',
        ],
      },

      producer+: pulsarAdapter {
        build: '~/git/github.com/grafana/prometheus-pulsar-remote-write',
        command+: [
          '--web.max-connection-age=15s',
        ],
      },

      consumer+: pulsarAdapter {
        scale: 3,
        command:
          [
            'consume',
          ]
          +
          super.command
          + [
            '--remote-write.url=http://cortex:9009/api/v1/push',
          ],
      },
    },
  },
  'file-prometheus-config'+: {
    remote_write+: [{
      url: 'http://producer:9201/write',
    }],
  },
}
