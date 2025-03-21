(import './docker-build-simple.libsonnet')('attendee-gate', 'us-west-2') {
  jobs+: {
    merge+: {
      steps+: [
        {
          name: 'Push arm64 tag for Lambda',  // doesnt support manifest
          run: |||
            dgst="$(docker buildx imagetools inspect --raw "${REPO}:${SHA}" | jq -r '.manifests[] | select(.platform.architecture == "arm64" and .platform.os == "linux") | .digest')"
            docker pull "${REPO}@${dgst}"
            docker tag  "${REPO}@${dgst}" "${REPO}:${SHA}-arm64"
            docker push "${REPO}:${SHA}-arm64"
          |||,
          env: {
            REPO: std.format('${{ steps.login-ecr.outputs.registry }}/%s', 'attendee-gate'),
            SHA: '${{ github.sha }}',
          },
        },
      ],

    },
  },
}
