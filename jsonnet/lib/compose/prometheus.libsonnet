{
  _images+:: {
    prometheus: 'prom/prometheus:v2.19.2',
  },

  config:: {
    global+: {
      scrape_interval: '15s',
      evaluation_interval: '15s',
    },
    scrape_configs+: [
      {
        job_name: 'prometheus',
        static_configs: [
          {
            targets: [
              'localhost:9090',
            ],
          },
        ],
      },
    ],
  },

  new(name='prometheus', config=$.config):: {
    'docker-compose.yaml'+: {
      services+: {
        [name]+: {
          image: $._images.prometheus,
          ports: [
            '9090:9090',
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
    ['file-%s-config' % name]+: config,
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
