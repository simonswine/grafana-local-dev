local prometheus = import 'compose/prometheus.libsonnet';

local tlsEnsureKey(path) = |||
  test -e %(path)s || openssl genrsa -out %(path)s 2048
||| % { path: path };

local tlsEnsureCA(name, prefixPath, validity=3650) =
  local key = prefixPath + '.key';
  local crt = prefixPath + '.crt';
  local srl = prefixPath + '.srl';
  tlsEnsureKey(key) + |||
    test -e %(crt)s || openssl req -x509 -subj '/CN=%(name)s/' -key %(key)s -sha256 -days 3650 -out %(crt)s
    test -e %(srl)s || echo 00 | tee %(srl)s
  ||| % { key: key, crt: crt, srl: srl, name: name }
;

local tlsEnsureCertificate(
  name,
  prefixPath,
  caKey,
  caCrt,
  validity=365,
  server=true,
  client=false,
  ip=[],
  dns=[],
      ) =
  local key = prefixPath + '.key';
  local crt = prefixPath + '.crt';
  local csr = prefixPath + '.csr';
  local cnf = prefixPath + '.cnf';

  tlsEnsureKey(key) + |||
    cat > %(cnf)s <<EOF
    [req]
    distinguished_name = req_distinguished_name
    req_extensions = v3_req

    [req_distinguished_name]

    [ v3_req ]
    # Extensions to add to a certificate request
    basicConstraints = CA:FALSE
    extendedKeyUsage = %(extendedKeyUsage)s
    subjectAltName = @alt_names

    [alt_names]
    %(ip)s%(dns)s
    EOF
    test -e %(csr)s || openssl req -new -subj '/CN=%(name)s/' -config %(cnf)s -key %(key)s -sha256 -out %(csr)s
    test -e %(crt)s || openssl x509 -req -extensions v3_req -days %(validity)d -in %(csr)s -CA %(caCrt)s -CAkey %(caKey)s -sha256 -out %(crt)s -extfile %(cnf)s
  ||| % {
    caKey: caKey,
    caCrt: caCrt,
    key: key,
    crt: crt,
    csr: csr,
    cnf: cnf,
    validity: validity,
    name: name,
    ip: std.join('', std.mapWithIndex(
      function(pos, ip) 'IP.%d = %s\n' % [pos + 1, ip],
      ip,
    )),
    dns: std.join('', std.mapWithIndex(
      function(pos, dns) 'DNS.%d = %s\n' % [pos + 1, dns],
      dns,
    )),
    extendedKeyUsage: std.join(
      ', ',
      [
      ] +
      (if client then ['clientAuth'] else []) +
      (if server then ['serverAuth'] else [])
    ),
  }
;

local tlsPulsar(tlsPath='/cert') = {
  caPrefix:: tlsPath + '/ca',
  caCrt:: $.caPrefix + '.crt',
  caKey:: $.caPrefix + '.key',
  brokerPrefix:: tlsPath + '/broker',
  clientPrefix:: tlsPath + '/client',
  command:
    'set -x\n' +
    tlsEnsureCA('pulsar-test-ca', $.caPrefix) +
    tlsEnsureCertificate('broker', $.brokerPrefix, $.caKey, $.caCrt, ip=['127.0.0.1'], dns=['pulsar', 'localhost']) +
    tlsEnsureCertificate('client', $.clientPrefix, $.caKey, $.caCrt, client=true, server=false, dns=['client']),
};

{
  _images+:: {
    pulsar: 'apachepulsar/pulsar:2.6.0',
    'pulsar-dashboard': 'apachepulsar/pulsar-dashboard:2.6.0',
  },


  new(name='pulsar', tls=false)::
    {
      'docker-compose.yaml'+: {
        services+: {
          [name]+: {
            image: $._images.pulsar,
            command: [
              '/bin/bash',
              '-euc',
              'bin/apply-config-from-env.py conf/standalone.conf && exec bin/pulsar standalone',
            ],
            ports: [
              8080,
              6650,
            ],
            environment+: {
              PULSAR_MEM: ' -Xms512m -Xmx512m -XX:MaxDirectMemorySize=1g',
            },
          },
          ['%s-dashboard' % name]+: {
            image: $._images['pulsar-dashboard'],
            ports: [
              '8081:80',
            ],
            environment: {
              SERVICE_URL: 'http://pulsar:8080',
            },
          },
        },
      },
    } +
    (if tls then
       local certsPath = '/certs';
       local certs = tlsPulsar(certsPath);
       {
         'docker-compose.yaml'+: {
           services+: {
             [name]+: {
               command: [
                 super.command[0],
                 super.command[1],
                 certs.command + '\n' + super.command[2],
               ],
               ports+: [
                 8443,
                 6651,
               ],
               volumes+: [
                 '%s-cert:%s' % [name, certsPath],
               ],
               environment+: {
                 PULSAR_PREFIX_brokerServicePortTls: '6651',
                 PULSAR_PREFIX_webServicePortTls: '8443',
                 PULSAR_PREFIX_tlsEnabled: 'true',
                 PULSAR_PREFIX_tlsCertificateFilePath: certs.brokerPrefix + '.crt',
                 PULSAR_PREFIX_tlsKeyFilePath: certs.brokerPrefix + '.key',
                 PULSAR_PREFIX_tlsTrustCertsFilePath: certs.caPrefix + '.crt',
               },
             },
           },
           volumes+: {
             ['%s-cert' % name]+: {},
           },
         },
       } else {}) +
    prometheus.addScrapeConfig(
      'pulsar', {
        static_configs+: [{
          targets: [
            '%s:8080' % name,
          ],

          labels: {
            instance: name,
          },
        }],
      },
    ),
}
