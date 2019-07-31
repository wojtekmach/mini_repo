FROM elixir:1.9-alpine as builder

LABEL author "Emil Bostijancic <emil.bostijancic@gmail.com>"

ENV MIX_ENV prod
#ENV REPLACE_OS_VARS true

RUN apk add --no-cache build-base git bash curl ca-certificates
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mkdir -p /mini_repo

WORKDIR /mini_repo

ADD config  ./config/
ADD lib  ./lib/
ADD priv ./priv/
ADD rel ./rel/
COPY mix.exs mix.lock ./

RUN mix deps.get
RUN mix compile
RUN mix release

FROM alpine:3.9

RUN apk add --no-cache ncurses-libs openssl bash curl ca-certificates

COPY --from=builder /mini_repo/_build/prod/rel/mini_repo /app/

ENTRYPOINT ["/app/bin/mini_repo"]
CMD ["start"]