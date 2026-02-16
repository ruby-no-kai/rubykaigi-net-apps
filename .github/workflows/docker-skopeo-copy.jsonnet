(import './docker-build-simple.libsonnet')('skopeo-copy') {
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
            REPO: std.format('${{ steps.login-ecr.outputs.registry }}/%s', 'skopeo-copy'),
            SHA: '${{ github.sha }}',
          },
        },
      ],
    },
  },
}
