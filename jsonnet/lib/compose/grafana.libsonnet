local prometheus = import 'compose/prometheus.libsonnet';
{
  _images+:: {
    grafana: 'grafana/grafana:7.3.1',
  },

  new(name='grafana')::
    {
      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images.grafana,
            ports: [
              '3000:3000',
            ],
            environment: {
              GF_AUTH_ANONYMOUS_ENABLED: 'true',
              GF_AUTH_ANONYMOUS_ORG_ROLE: 'Admin',
            },
            volumes+: [
              '%s-data:/var/lib/grafana' % name,
              './%s-datasources:/etc/grafana/provisioning/datasources:z' % name,
              './%s-dashboards:/etc/dashboards:z' % name,
              './file-%s-dashboards:/etc/grafana/provisioning/dashboards/dashboards.yaml:z' % name,
            ],
          },
        },
        volumes+: {
          ['%s-data' % name]+: {},
        },
      },
      // add dashboard discovery
      ['file-%s-dashboards' % name]+: {
        apiVersion: 1,
        providers: [
          {
            name: 'dashboards',
            type: 'file',
            updateIntervalSeconds: 30,
            options: {
              path: '/etc/dashboards',
              foldersFromFilesStructure: true,
            },
          },
        ],
      },
    } +
    prometheus.addScrapeConfig(
      'grafana', {
        static_configs+: [{
          targets: [
            '%s:3000' % name,
          ],

          labels: {
            instance: name,
          },
        }],
      },
    ),

  // add dashboard to spec to the correct folder
  addDashboard(name, dashboard, grafana_name='grafana'):: {
    ['%s-dashboards/%s.json' % [grafana_name, name]]+:
      dashboard,
  },
}
