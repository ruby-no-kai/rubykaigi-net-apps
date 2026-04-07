# syntax=docker/dockerfile:1
FROM public.ecr.aws/sorah/ruby:4.0-dev AS builder

WORKDIR /app

COPY app/ ./
RUN bundle config set --local deployment true

ENV BUNDLE_RETRY=3
ENV BUNDLE_USER_CACHE=/cache/bundler
RUN --mount=type=cache,target=/cache bundle install


FROM public.ecr.aws/sorah/ruby:4.0

WORKDIR /app
COPY --from=builder /app/ ./

USER nobody
ENTRYPOINT ["bundle", "exec", "acmesmith"]
