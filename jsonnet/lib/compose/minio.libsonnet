local prometheus = import 'compose/prometheus.libsonnet';

{
  _images+:: {
    minio: 'minio/minio:RELEASE.2020-07-27T18-37-02Z',
  },

  new(
    name='minio',
    config=$.singleProcess,
    namespace='default',
    buckets=[],
    port=9000,
    access_key='minio123',
    secret_key='minio123',
    data_path='/data',
    command=[
      'server',
      '/data',
    ],
  ):: {
        'docker-compose.yaml'+: {
          services+: {
            [name]+:
              {

                image: $._images.minio,
                ports: [
                  '%d:9000' % port,
                ],
                volumes: [
                  '%s-data:%s' % [name, data_path],
                ],
                entrypoint: '/bin/sh',
                command: command,
                environment: {
                  MINIO_PROMETHEUS_AUTH_TYPE: 'public',
                  MINIO_ACCESS_KEY: access_key,
                  MINIO_SECRET_KEY: secret_key,
                },
              }
              +
              if true then {
                entrypoint: '/bin/sh',
                command: [
                  '-euc',
                  'for dir in %(buckets)s; do mkdir -p %(data_path)s/$${dir}; done && exec /usr/bin/minio %(command)s' % {
                    data_path: data_path,
                    buckets: std.join(' ', buckets),
                    command: std.join(' ', command),
                  },
                ],
              } else {
              },
          },
          volumes+: {
            ['%s-data' % name]+: {},
          },

        },
      } +
      prometheus.addScrapeConfig(
        '%s/%s' % [namespace, 'minio'], {
          metrics_path: '/minio/prometheus/metrics',
          static_configs+: [{
            targets: [
              '%s:9000' % name,
            ],

            labels: {
              instance: name,
              namespace: namespace,
            },
          }],
        },
      ),
}
