{
  _images+:: {
    prometheus: 'prom/prometheus:v2.22.1',
  },

  config:: {
    global+: {
      scrape_interval: '15s',
      evaluation_interval: '15s',
    },
  },

  new(name='prometheus', config=$.config, port=9090)::
    local scrape_config = '%s-scrape_configs' % name;
    {
      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images.prometheus,
            ports: [
              '%d:9090' % port,
            ],
            volumes: [
              './file-%s-config:/etc/prometheus/prometheus.yml:z' % name,
              '%s-data:/var/lib/prometheus' % name,
            ],
          },
        },
        volumes+: {
          ['%s-data' % name]+: {},
        },
      },

      local this = self,
      ['file-%s-config' % name]: config {
        scrape_configs: [
          this[scrape_config][job] {
            job_name: job,

          }
          for job in std.objectFields(this[scrape_config])
        ],
      },
      ['grafana-datasources/%s.yaml' % name]+: {
        apiVersion: 1,
        datasources: [{
          name: name,
          type: 'prometheus',
          access: 'proxy',
          orgId: 1,
          uid: name,
          url: 'http://%s:9090' % name,
        }],
      },
    } +
    $.addScrapeConfig(name, {
      static_configs: [
        {
          targets: [
            'localhost:9090',
          ],
        },
      ],
    }, prometheus_name=name)
  ,

  addScrapeConfig(name, config, prometheus_name='prometheus')::
    local scrape_config = '%s-scrape_configs' % prometheus_name;
    {
      [scrape_config]+:: {
        [name]+: config,
      },
    },

  addRules(name, rules, prometheus_name='prometheus')::
    local filekey = 'file-%s-rules-%s' % [prometheus_name, name];
    local filepath = '/etc/prometheus/rules/%s.rules' % name;
    {
      'docker-compose.yaml'+: {
        services+: {
          [prometheus_name]+: {
            volumes+: [
              './%s:%s:z' % [filekey, filepath],
            ],
          },
        },
      },
      [filekey]+: rules,

      // config in prometheus
      ['file-%s-config' % prometheus_name]+: {
        rule_files+: [
          filepath,
        ],
      },
    },
}
