local cortex = import 'compose/cortex.libsonnet';
local grafana = import 'compose/grafana.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';
local cortexMixin = import 'cortex-mixin/mixin.libsonnet';

prometheus.new() +
grafana.new() +
cortex.new() + {
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
