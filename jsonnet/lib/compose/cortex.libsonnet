{
  _images+:: {
    cortex: 'cortexproject/cortex:master-77490f99f',
  },

  singleProcess:: {
    auth_enabled: false,
    server: {
      http_listen_port: 9009,
      grpc_server_max_recv_msg_size: 104857600,
      grpc_server_max_send_msg_size: 104857600,
      grpc_server_max_concurrent_streams: 1000,
    },
    distributor: {
      shard_by_all_labels: true,
      pool: {
        health_check_ingesters: true,
      },
    },
    ingester_client: {
      grpc_client_config: {
        max_recv_msg_size: 104857600,
        max_send_msg_size: 104857600,
        use_gzip_compression: true,
      },
    },
    ingester: {
      spread_flushes: true,
      chunk_age_jitter: 0,
      walconfig: {
        wal_enabled: true,
        recover_from_wal: true,
        wal_dir: '/tmp/cortex/wal',
      },
      lifecycler: {
        join_after: 0,
        min_ready_duration: '0s',
        final_sleep: '0s',
        num_tokens: 512,
        tokens_file_path: '/tmp/cortex/wal/tokens',
        ring: {
          kvstore: {
            store: 'inmemory',
          },
          replication_factor: 1,
        },
      },
    },
    schema: {
      configs: [
        {
          from: '2019-07-29',  //T00:00:00.000Z',
          store: 'boltdb',
          object_store: 'filesystem',
          schema: 'v10',
          index: {
            prefix: 'index_',
            period: '1w',
          },
        },
      ],
    },
    storage: {
      boltdb: {
        directory: '/tmp/cortex/index',
      },
      filesystem: {
        directory: '/tmp/cortex/chunks',
      },
      delete_store: {
        store: 'boltdb',
      },
    },
    purger: {
      object_store_type: 'filesystem',
    },
    frontend_worker: {
      match_max_concurrent: true,
    },
    ruler: {
      enable_api: true,
      enable_sharding: false,
      storage: {
        type: 'local',
        'local': {
          directory: '/tmp/cortex/rules',
        },
      },
    },
  },

  new(
    name='cortex',
    config=$.singleProcess,
    namespace='default',
    cluster='cortex',
  ):: {
    'docker-compose.yaml'+: {
      services+: {
        [name]+: {
          image: $._images.cortex,
          ports: [
            '9009:9009',
          ],
          volumes: [
            './file-%s-config:/etc/cortex/cortex.yml:z' % name,
            '%s-data:/tmp/cortex' % name,
          ],
          command: [
            'cortex',
            '-config.file=/etc/cortex/cortex.yml',
          ],
        },
      },
      volumes+: {
        ['%s-data' % name]+: {},
      },

    },
    ['file-%s-config' % name]+: config,

    // add scrape config
    'file-prometheus-config'+: {
      scrape_configs+: [{
        job_name: '%s/%s' % [namespace, name],
        static_configs: [
          {
            targets: [
              '%s:9009' % name,
            ],

            labels: {
              cluster: cluster,
              namespace: namespace,
            },
          },
        ],
      }],
    },

    // add datasource for grafana
    ['grafana-datasources/%s.yaml' % name]+: {
      apiVersion: 1,
      datasources: [{
        name: name,
        type: 'prometheus',
        access: 'proxy',
        orgId: 1,
        uid: name,
        url: 'http://%s:9009/api/prom' % name,
      }],
    },
  },
}
