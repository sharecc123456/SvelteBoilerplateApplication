###
### First Stage: Build the artifacts
###

# There is a version mismatch between this and the final runner in libcrypto - so use the same base image.
# FROM docker.io/library/elixir:1.13.4-otp-25 as build
FROM docker.io/library/ubuntu:22.04 as build

ARG elixir_version=1.14.5

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
	apt-get -y install curl sudo wget redis mosh inotify-tools bash python3-pip
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get -y install nodejs

# Note that jammy (22.04 LTS) has no esl-erlang and elixir packages...
# TODO use this once the packages are released for 22.04
# RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb
# RUN sudo apt-get update && \

# sudo apt-get install esl-erlang elixir


WORKDIR /elixir

# So the workaround is to grab Erlang with OTP/25 and compile Elixir...
RUN wget https://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_25.0.3-1~ubuntu~jammy_amd64.deb && \
	apt-get -y install libncurses5 libsctp1 libsctp-dev libwxgtk3.0-gtk3-de && \
	sudo dpkg -i esl-erlang_25.0.3-1~ubuntu~jammy_amd64.deb

# Grab Elixir source code
RUN wget https://github.com/elixir-lang/elixir/archive/refs/tags/v$elixir_version.tar.gz
RUN tar xzvf v$elixir_version.tar.gz
RUN cd elixir-$elixir_version && make

WORKDIR /app
ENV PATH="${PATH}:/elixir/elixir-"$elixir_version"/bin"

RUN mix local.hex --force \
	&& mix local.rebar --force

# Install Node v18
RUN npm install -g npm@latest

# misc tools
COPY tools tools
COPY docker_entrypoint.sh docker_entrypoint.sh

ENV MIX_ENV=prod

# dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets install

# compiled assets
COPY priv priv
COPY assets assets
RUN env NODE_OPTIONS=--openssl-legacy-provider npm run --prefix ./assets deploy
RUN mix phx.digest
# code
COPY lib lib
RUN mix do compile --warnings-as-errors --all-warnings, release

###
### Second Stage: Create the runner
###

FROM docker.io/library/ubuntu:22.04 as app
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -y install libssl-dev curl redis ca-certificates python3-pip python3 wkhtmltopdf imagemagick wget

# ghostscript contained vulnerabilities described here -> https://www.kb.cert.org/vuls/id/332928/
# hence ImageMagick v6.* had a safe guard implemented on policy
# This issue is addressed in Ghostscript v9.24. Apt repo has Ghostscript v9.50
# so the policy.xml is safe to remove
RUN sed -i '/disable ghostscript format types/,+6d' /etc/ImageMagick-6/policy.xml

# Install Node v18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get update && \
	apt-get -y install nodejs pkg-config libcairo2 libcairo2-dev

COPY nomad/Boilerplate-RootCA.crt /app/Boilerplate-RootCA.crt

# Install the Doppler CLI
RUN (curl -Ls https://cli.doppler.com/install.sh || wget -qO- https://cli.doppler.com/install.sh) | sh

# RUN apt-get update && \
	# apt-get -y install pdftk
RUN mkdir -p /opt/pdftk-native
RUN curl -L https://gitlab.com/api/v4/projects/5024297/packages/generic/pdftk-java/v3.3.3/pdftk -o /opt/pdftk-native/pdftk
RUN chmod +x /opt/pdftk-native/pdftk

WORKDIR /app
COPY --from=build /app/tools /app/tools
RUN npm --prefix /app/tools/iac/filler install
RUN /bin/bash -c 'cd /app/tools/iac/ && pip install pyPDF2 pdfrw reportlab pillow'

COPY --from=build /app/_build/prod/rel/boilerplate/ /app/
COPY --from=build /app/docker_entrypoint.sh /app/docker_entrypoint.sh

EXPOSE 443
CMD ["/app/docker_entrypoint.sh"]
