FROM public.ecr.aws/sorah/ruby:4.0-dev AS builder

RUN  --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists,sharing=locked apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y libssl-dev

WORKDIR /var/task
COPY Gemfile* /var/task/

RUN bundle config set path '/var/task/vendor/bundle' \
 && bundle config set deployment 'true' \
 && bundle install --jobs 30
RUN bundle config set bin /usr/local/bin \
 && bundle binstubs aws_lambda_ric --force

FROM public.ecr.aws/sorah/ruby:4.0

RUN  --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt/lists,sharing=locked apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y skopeo

WORKDIR /var/task
COPY --from=builder /var/task/vendor /var/task/vendor
COPY --from=builder /var/task/.bundle /var/task/.bundle
COPY --from=builder /usr/local/bin/aws_lambda_ric /usr/local/bin/
COPY . /var/task/

ENTRYPOINT ["/usr/local/bin/aws_lambda_ric"]
CMD ["app.handler"]
