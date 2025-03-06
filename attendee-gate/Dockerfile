FROM public.ecr.aws/lambda/ruby:3.3 as builder
RUN dnf install -y gcc gcc-c++ make pkg-config git

COPY Gemfile* ${LAMBDA_TASK_ROOT}/
WORKDIR ${LAMBDA_TASK_ROOT}/app

ENV BUNDLE_GEMFILE ${LAMBDA_TASK_ROOT}/Gemfile
ENV BUNDLE_PATH ${LAMBDA_TASK_ROOT}/vendor/bundle
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_JOBS 16
ENV BUNDLE_WITHOUT development:test
RUN bundle install

COPY . ${LAMBDA_TASK_ROOT}/app

FROM public.ecr.aws/lambda/ruby:3.3

COPY --from=builder ${LAMBDA_TASK_ROOT}/vendor ${LAMBDA_TASK_ROOT}/vendor
COPY . ${LAMBDA_TASK_ROOT}/app

WORKDIR ${LAMBDA_TASK_ROOT}/app

ENV BUNDLE_GEMFILE ${LAMBDA_TASK_ROOT}/Gemfile
ENV BUNDLE_PATH ${LAMBDA_TASK_ROOT}/vendor/bundle
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_WITHOUT development:test
CMD [ "index.AttendeeGate::Handlers.http" ]
