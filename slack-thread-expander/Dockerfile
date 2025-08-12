FROM public.ecr.aws/docker/library/rust:1.85-trixie as builder
RUN cargo install --git https://github.com/eagletmt/slack-thread-expander --rev cd091d547ac6e6cc478855af887575355018f241

FROM public.ecr.aws/docker/library/debian:trixie-slim
RUN apt-get update && apt-get install -y ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/cargo/bin/slack-thread-expander /usr/local/bin/slack-thread-expander
CMD ["slack-thread-expander"]
