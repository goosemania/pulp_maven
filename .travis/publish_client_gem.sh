#!/bin/bash

echo "---
:rubygems_api_key: $RUBYGEMS_API_KEY" > ~/.gem/credentials
sudo chmod 600 ~/.gem/credentials

django-admin runserver 24817 >> ~/django_runserver.log 2>&1 &
sleep 5

cd $TRAVIS_BUILD_DIR
export REPORTED_VERSION=$(http :24817/pulp/api/v3/status/ | jq --arg plugin pulp_maven -r '.versions[] | select(.component == $plugin) | .version')
export DESCRIPTION="$(git describe --all --exact-match `git rev-parse HEAD`)"
if [[ $DESCRIPTION == 'tags/'$REPORTED_VERSION ]]; then
  export VERSION=${REPORTED_VERSION}
else
  export EPOCH="$(date +%s)"
  export VERSION=${REPORTED_VERSION}.dev.${EPOCH}
fi

export response=$(curl --write-out %{http_code} --silent --output /dev/null https://rubygems.org/gems/pulp_maven_client/versions/$VERSION)

if [ "$response" == "200" ];
then
    exit
fi

cd
git clone https://github.com/pulp/pulp-openapi-generator.git
cd pulp-openapi-generator

sudo ./generate.sh pulp_maven ruby $VERSION
sudo chown -R travis:travis pulp_maven-client
cd pulp_maven-client
gem build pulp_maven_client
GEM_FILE="$(ls | grep pulp_maven_client-)"
gem push ${GEM_FILE}
