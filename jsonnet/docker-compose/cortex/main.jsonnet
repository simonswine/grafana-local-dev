local cortex = import 'compose/cortex.libsonnet';
local grafana = import 'compose/grafana.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';
local cortexMixin = import 'cortex-mixin/mixin.libsonnet';

prometheus.new() +
grafana.new() +
cortex.new() +
cortex.new(
  name='cortex1',
  port=9010,
  config=cortex.singleProcess {
    server+: {
      grpc_server_max_concurrent_streams+: 11,
    },
  }
) + {
  'docker-compose.yaml'+: {
    version: '3.3',
  },
  'file-prometheus-config'+: {
    remote_write+: [{
      url: 'http://cortex:9009/api/prom/push',
    }],
  },
}
+
prometheus.addRules(
  'cortex',
  cortexMixin {
    storage_engine: ['chunks'],
    singleBinary: true,
  }.prometheusAlerts,
)
+
{
  ['grafana-dashboards/cortex/%s' % key]: cortexMixin.grafanaDashboards[key]
  for key in std.objectFields(cortexMixin.grafanaDashboards)
}
