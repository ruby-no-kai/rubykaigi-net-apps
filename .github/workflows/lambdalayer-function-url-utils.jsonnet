(function(name, runtimes, platforms=['linux/arm64']) {
   common:: {
     setupSteps: [
       { uses: 'docker/setup-buildx-action@v3' },
       {
         uses: 'aws-actions/configure-aws-credentials@v4',
         with: {
           'aws-region': 'ap-northeast-1',
           'role-to-assume': 'arn:aws:iam::005216166247:role/GhaDockerPush',
           'role-skip-session-tagging': true,
         },
       },
     ],

     runnersMap: {
       amd64: 'ubuntu-24.04',
       arm64: 'ubuntu-24.04-arm',
     },
   },

   name: std.format('lambdalayer-%s', name),
   on: {
     push: {
       branches: ['main', 'test'],
       paths: [
         std.format('%s/**', name),
         std.format('.github/workflows/lambdalayer-%s.yml', name),
       ],
     },
   },

   permissions: { contents: 'read', 'id-token': 'write' },

   jobs: {
     build: {
       strategy: {
         matrix: {
           include: std.flatMap(
             function(runtime)
               std.map(
                 function(platform) {
                   platform: platform,
                   runtime: runtime,
                   runner: $.common.runnersMap[platform],
                 },
                 platforms
               ),
             runtimes
           ),
         },
       },
       name: 'build (${{ matrix.platform }}/${{ matrix.runtime }})',
       'runs-on': '${{ matrix.runner }}',
       steps: $.common.setupSteps + [
         {
           uses: 'docker/build-push-action@v6',
           id: 'build-push',
           with: {
             context: std.format('{{defaultContext}}:%s', name),
             file: std.format('Dockerfile.%s', '${{ matrix.runtime }}'),
             platforms: 'linux/${{ matrix.platform }}',
             load: true,
             'cache-from': 'type=gha',
             'cache-to': 'type=gha,mode=max',
           },
         },
         {
           name: 'Upload zip',
           run: |||
             set -x
             LAYER_ZIP="${RUNNER_TEMP}/layer.zip"
             docker run --rm "${IMAGE}" cat /var/task/layer.zip > "${LAYER_ZIP}"
             sha384sum "${LAYER_ZIP}"
             aws s3 cp "${LAYER_ZIP}" "s3://rk-tftp/ro/lambda/${REPO}/${SHA}/${PLATFORM}-${RUNTIME}.zip"
           |||,
           env: {
             RUNNER_TEMP: '${{ runner.temp }}',
             SHA: '${{ github.sha }}',
             IMAGE: '${{ steps.build-push.outputs.imageid }}',
             RUNTIME: '${{ matrix.runtime }}',
             PLATFORM: '${{ matrix.platform }}',
             REPO: name,
           },
         },
       ],
     },
   },
 })('function-url-utils', ['ruby33', 'ruby34'], ['arm64', 'amd64'])
