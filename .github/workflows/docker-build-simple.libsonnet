// Convention:
//   Workflow definition: .github/workflow/docker-#{name}.yml
//   Docker manifest #{name}/Dockerfile
//   ECR repository: #{name}

function(name, region='ap-northeast-1', platforms=['linux/arm64']) {
  common:: {
    setupSteps: [
      { uses: 'docker/setup-buildx-action@v3' },
      {
        uses: 'aws-actions/configure-aws-credentials@v4',
        with: {
          'aws-region': region,
          'role-to-assume': 'arn:aws:iam::005216166247:role/GhaDockerPush',
          'role-skip-session-tagging': true,
        },
      },
      {
        uses: 'aws-actions/amazon-ecr-login@v2',
        id: 'login-ecr',
      },
    ],

    runnersMap: {
      'linux/amd64': 'ubuntu-24.04',
      'linux/arm64': 'ubuntu-24.04-arm',
    },
  },

  name: std.format('docker-%s', name),
  on: {
    push: {
      branches: ['main', 'test'],
      paths: [
        std.format('%s/**', name),
        std.format('.github/workflows/docker-%s.yml', name),
      ],
    },
  },
  jobs: {
    build: {
      strategy: {
        matrix: {
          include: std.map(function(platform) {
            key: std.strReplace(platform, '/', '-'),  // for artifact name
            platform: platform,
            runner: $.common.runnersMap[platform],
          }, platforms),
        },
      },
      name: 'build (${{ matrix.platform }})',
      'runs-on': '${{ matrix.runner }}',
      permissions: { 'id-token': 'write', contents: 'read' },
      steps: $.common.setupSteps + [
        {
          uses: 'docker/build-push-action@v6',
          id: 'build-push',
          with: {
            context: std.format('{{defaultContext}}:%s', name),
            platforms: '${{ matrix.platform }}',
            outputs: std.format('type=image,"name=${{ steps.login-ecr.outputs.registry }}/%s",push-by-digest=true,name-canonical=true,push=true', name),
          },
        },
        {
          name: 'Export digests',
          run: |||
            mkdir -p "${RUNNER_TEMP}/digests"
            printenv DIGEST > "${RUNNER_TEMP}/digests/${PLATFORM}"
          |||,
          env: {
            RUNNER_TEMP: '${{ runner.temp }}',
            DIGEST: '${{ steps.build-push.outputs.digest }}',
            PLATFORM: '${{ matrix.key }}',
          },
        },
        {
          name: 'Upload digests',
          uses: 'actions/upload-artifact@v4',
          with: {
            name: 'digests-${{ matrix.key }}',
            path: '${{ runner.temp }}/digests/*',
            'if-no-files-found': 'error',
            'retention-days': 1,
          },
        },
      ],
    },
    merge: {
      'runs-on': 'ubuntu-latest',
      needs: ['build'],
      permissions: { 'id-token': 'write' },
      steps: $.common.setupSteps + [
        {
          name: 'Download digests',
          uses: 'actions/download-artifact@v4',
          with: {
            path: '${{ runner.temp }}/digests',
            pattern: 'digests-*',
            'merge-multiple': true,
          },
        },
        {
          name: 'Push manifest',
          run: |||
            cat "${RUNNER_TEMP}"/digests/* | xargs -I{} printf "%s@%s" "${REPO}" {} | docker buildx imagetools create -f /dev/stdin -t "${REPO}:latest" -t "${REPO}:${SHA}"
            docker buildx imagetools inspect "${REPO}:${SHA}"
          |||,
          env: {
            RUNNER_TEMP: '${{ runner.temp }}',
            REPO: std.format('${{ steps.login-ecr.outputs.registry }}/%s', name),
            SHA: '${{ github.sha }}',
          },
        },
      ],
    },
  },
}
