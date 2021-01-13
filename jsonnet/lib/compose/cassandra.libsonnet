{
  _images+:: {
    cassandra: 'cassandra:3.11.9',
  },

  new(
    name='cassandra',
    namespace='default',
    data_path='/var/lib/cassandra'
  ):: {
    'docker-compose.yaml'+: {
      services+: {
        [name]+:
          {

            image: $._images.cassandra,
            volumes: [
              '%s-data:%s' % [name, data_path],
            ],
          },
      },
      volumes+: {
        ['%s-data' % name]+: {},
      },

    },
  },
}
