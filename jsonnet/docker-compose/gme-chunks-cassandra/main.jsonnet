local cassandra = import 'compose/cassandra.libsonnet';
local compose = import 'compose/compose.libsonnet';
local consul = import 'compose/consul.libsonnet';
local cortex = (import 'compose/cortex.libsonnet') {
  _images+:: {
    cortex: 'us.gcr.io/kubernetes-dev/metrics-enterprise:v1.0.2',
  },
};

local minio = import 'compose/minio.libsonnet';
local prometheus = import 'compose/prometheus.libsonnet';

local bucket_name = 'cortex-chunks';


{
  minio:: {
    access_key_id: 'minio123',
    secret_access_key: 'minio123',
    s3forcepathstyle: true,
    insecure: true,
    endpoint: 'minio:9000',
    buckets:: {
      ruler: 'cortex-ruler',
      admin: 'cortex-admin',
      storage: 'cortex-chunks',
    },
  },


  cortex:: {
    local kvconsul = {
      store: 'consul',
      consul: {
        host: 'consul:8500',
      },
    },
    config:: cortex.singleProcess {
      cluster_name: 'metrics-enterprise-test-fixturee',
      admin_client+: {
        storage+: {
          type: 's3',
          s3+: $.minio {
            bucket_name: $.minio.buckets.admin,
            s3forcepathstyle:: null,
          },
        },
      },

      schema+: {
        local store = 'cassandra',
        configs: [
          c {
            object_store: store,
            store: store,
            index: {
              prefix: 'index_',
              period: '1w',
            },
            chunks: {
              prefix: 'chunk_',
              period: '1w',
            },
          }
          for c in super.configs
        ],
      },
      storage+: {
        cassandra+: {
          addresses: 'cassandra',
          port: 9042,
          keyspace: 'cortex',
          replication_factor: 1,
        },
      },
      distributor+: {
        ring+: {
          kvstore+: kvconsul,
        },
        ha_tracker: {
          enable_ha_tracker: true,
          kvstore+: kvconsul,
        },


      },
      ingester+: {
        max_stale_chunk_idle_time: '30m',
        lifecycler+: {
          ring+: {
            kvstore+: kvconsul,
          },
        },
      },
    },

    config_ruler:: $.cortex.config {
      target: 'ruler',
      ruler+: {
        enable_sharding: true,
        storage+: {
          type: 's3',
          s3+: $.minio {
            bucketnames: $.minio.buckets.ruler,
          },
          'local':: null,
        },
        ring+: {
          kvstore+: kvconsul,
        },
      },
      limits+: {
        ruler_evaluation_delay_duration: '1m',
      },
    },
  },

  files:
    prometheus.new() +
    cortex.new(config=$.cortex.config, scale=3, port=null) +
    cortex.new(name='cortex-ruler', config=$.cortex.config_ruler, port=null, log_level='debug') +
    cassandra.new() +
    consul.new() +
    minio.new(
      access_key=$.minio.access_key_id,
      secret_key=$.minio.secret_access_key,
      buckets=[
        $.minio.buckets[f]
        for f in std.objectFields($.minio.buckets)
      ]
    ) +
    compose.service('cortex', {
      command: [
        '-config.file=/etc/cortex/cortex.yml',
        '-bootstrap.license.path=/etc/cortex/license.jwt',
      ],
      volumes+: [
        './file-cortex-headers:/etc/cortex/headers.yml:z',
        '~/.grafana/metrics-enterprise-license.jwt:/etc/cortex/license.jwt:z',
      ],
    }) +
    compose.service('remote-write-stale-nans', {
      image: 'simonswine/remote-write-stale-nans@sha256:7cd39abd194d0f90fa20c32af4a0b855142c8f35762fba9fe11c9de8a9064b90',
      command:: [
        '-url=http://cortex:9009/api/v1/push',
      ],
    }) +
    compose.service('cortextool-loadrule', {
      image: 'grafana/cortex-tools:v0.7.0',
      entrypoint: '',
      command: [
        '/bin/sh',
        '-c',
        |||
          set -eu
          set -x

          cat > rule.yaml <<EOS
          namespace: default
          groups:
          - name: grafana_labs_test
            interval: 10s
            rules:
            -
              expr: time()
              record: grafana_labs_test:evaluation_time
          - name: nan_test
            interval: 10s
            rules:
            -
              expr: (100 - ((nan_test_metric_available{instance=~"node.*"} * 100) / nan_test_metric_total{instance=~"node.*"})) / 100
              record: grafana_labs_test:nan
          EOS

          export CORTEX_ADDRESS=http://cortex-ruler:9009
          export CORTEX_TENANT_ID=team-a
          export CORTEX_API_KEY=team-a

          #cortextool rules delete default example_rule_group
          cortextool rules sync ./rule.yaml
        |||,
      ],
      volumes+: [
        './file-cortex-headers:/etc/cortex/headers.yml:z',
        '~/.grafana/metrics-enterprise-license.jwt:/etc/cortex/license.jwt:z',
      ],
    }) +
    {
      'file-prometheus-config'+: {
        remote_write+: [{
          url: 'http://cortex:9009/api/prom/push',
        }],
      },
    },
}.files
