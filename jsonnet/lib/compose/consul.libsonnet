{
  _images+:: {
    consul: 'consul:1.9.1',
  },

  new(
    name='consul',
    namespace='default',
    data_path='/consul/data'
  ):: {
    'docker-compose.yaml'+: {
      services+: {
        [name]+:
          {

            image: $._images.consul,
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
