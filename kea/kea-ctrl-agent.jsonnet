{
  'Control-agent': {
    'http-host': '127.0.0.1',
    'http-port': 10080,
    'control-sockets': {
      dhcp4: {
        comment: 'main server',
        'socket-type': 'unix',
        'socket-name': '/var/run/kea/dhcp4.sock',  // /run/kea/dhcp4.sock via symlink on /var/run; https://gitlab.isc.org/isc-projects/kea/-/issues/3831
      },
      // dhcp6: {
      //   'socket-type': 'unix',
      //   'socket-name': '/path/to/the/unix/socket-v6',
      //   'user-context': { version: 3 },
      // },
    },
    'hooks-libraries': [
      // {
      //   library: '/opt/local/control-agent-commands.so',
      //   parameters: {
      //     param1: 'foo',
      //   },
      // },
    ],
    loggers: [
      {
        name: 'kea-ctrl-agent',
        severity: 'WARN',
        output_options: [{ output: 'stdout' }],
      },
    ],
  },

}
