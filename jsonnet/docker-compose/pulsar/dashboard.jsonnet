local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local singlestat = grafana.singlestat;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;

local legend = {
  legend+: {
    rightSide: true,
    show: true,
    alignAsTable: true,
    avg: true,
    total: true,
    values: true,
  },
};

local samplesPerComponent =
  graphPanel.new(
    title='Samples per second per component',
    datasource='$PROMETHEUS_DS',
    stack=true,
    format='short',
  ).addTarget(
    prometheus.target(
      'sum(rate(prometheus_remote_storage_succeeded_samples_total[$__rate_interval]))',
      legendFormat='Prometheus',
    )
  ).addTarget(
    prometheus.target(
      'sum(rate(sent_samples_total[$__rate_interval]))',
      legendFormat='Pulsar (produce)',
    )
  ).addTarget(
    prometheus.target(
      'sum(rate(pulsar_client_messages_received{dns_name="consumer"}[$__rate_interval]))',
      legendFormat='Pulsar (consume)',
    )
  ).addTarget(
    prometheus.target(
      'sum(rate(cortex_distributor_samples_in_total[$__rate_interval]))',
      legendFormat='Cortex',
    )
  ) + legend;

local samplesPerConsumer =
  graphPanel.new(
    title='Samples per consumer',
    datasource='$PROMETHEUS_DS',
    stack=true,
    format='short',
  ).addTarget(
    prometheus.target(
      'sum(rate(pulsar_client_messages_received{dns_name="consumer"}[$__rate_interval])) by (instance)',
      legendFormat='{{instance}}',
    )
  ) + legend;


dashboard.new(
  'Pulsar Adapter',
  schemaVersion=16,
  tags=['pulsar'],
  time_from='now-1h',
)
.addTemplate(
  grafana.template.datasource(
    'PROMETHEUS_DS',
    'prometheus',
    'Prometheus',
  )
)
.addPanel(
  samplesPerComponent,
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 12,
  }
)
.addPanel(
  samplesPerConsumer,
  gridPos={
    x: 0,
    y: 12,
    w: 24,
    h: 12,
  }
)
