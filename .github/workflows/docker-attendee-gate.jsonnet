(import './docker-build-simple.libsonnet')('attendee-gate', 'us-west-2') {
  jobs+: {
    merge+: {
      steps+: [
        {
          name: 'Push arm64 tag for Lambda',  // doesnt support manifest
          run: |||
            dgst="$(docker buildx imagetools inspect --raw "${REPO}:${SHA}" | jq -r '.manifests[] | select(.platform.architecture == "arm64" and .platform.os == "linux") | .digest')"
            docker buildx imagetools create --tag  "${REPO}:${SHA}-arm64" "${REPO}@${dgst}" 
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
