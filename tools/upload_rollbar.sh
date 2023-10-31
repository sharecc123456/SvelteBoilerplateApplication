#!/bin/sh

# Save a short git hash, must be run from a git
# repository (or a child directory)
version=$1

# Use the post_server_time access token, you can
# find one in your project access token settings
post_server_item=$2

tempfile=$(mktemp)

echo "Uploading source maps for version $version, using ${tempfile}!"

# We upload a source map for each resulting JavaScript
# file; the path depends on your build config
docker run --rm --entrypoint /bin/sh ${version} -c "ls /app/lib/boilerplate-0.1.0/priv/static/js/ | egrep '\-.*\.js$'" \
| while read -r path; do

  _map=$(echo $path | sed 's/\-.*\.js$/\.js.map/')
  url=https://app.boilerplate.co/js/${path}
  echo "_map=${_map} path=${path} url=${url}"

  # Extract the map
  docker run \
      --rm \
      --entrypoint /bin/sh \
      ${version} -c "cat /app/lib/boilerplate-0.1.0/priv/static/js/${_map}" > ${tempfile}

  # a path to a corresponding source map file
  source_map="@${tempfile}"

  echo "Uploading source map for $url"

  curl --silent --show-error https://api.rollbar.com/api/1/sourcemap \
    -F access_token=$post_server_item \
    -F version=$version \
    -F minified_url=$url \
    -F source_map=$source_map \
    > /dev/null
done

rm ${tempfile}
