#!/usr/bin/env sh
set -v

COMMIT_MSG=$(git show HEAD^2 -s)
export COMMIT_MSG
export PULP_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/pulpcore\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_PLUGIN_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/pulpcore-plugin\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_SMASH_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/PulpQE\/pulp-smash\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_ROLES_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/ansible-pulp\/pull\/(\d+)' | awk -F'/' '{print $7}')

# dev_requirements should not be needed for testing; don't install them to make sure
pip install -r test_requirements.txt

# check the commit message
./.travis/check_commit.sh

# Lint code.
flake8 --config flake8.cfg || exit 1

cd ..
git clone https://github.com/pulp/ansible-pulp.git
if [ -n "$PULP_ROLES_PR_NUMBER" ]; then
  pushd ansible-pulp
  git fetch origin +refs/pull/$PULP_ROLES_PR_NUMBER/merge
  git checkout FETCH_HEAD
  popd
fi

git clone https://github.com/pulp/pulpcore.git

if [ -n "$PULP_PR_NUMBER" ]; then
  pushd pulpcore
  git fetch origin +refs/pull/$PULP_PR_NUMBER/merge
  git checkout FETCH_HEAD
  popd
fi


git clone https://github.com/pulp/pulpcore-plugin.git

if [ -n "$PULP_PLUGIN_PR_NUMBER" ]; then
  pushd pulpcore-plugin
  git fetch origin +refs/pull/$PULP_PLUGIN_PR_NUMBER/merge
  git checkout FETCH_HEAD
  popd
fi


if [ -n "$PULP_SMASH_PR_NUMBER" ]; then
  git clone https://github.com/PulpQE/pulp-smash.git
  pushd pulp-smash
  git fetch origin +refs/pull/$PULP_SMASH_PR_NUMBER/merge
  git checkout FETCH_HEAD
  popd
fi

if [ "$DB" = 'mariadb' ]; then
  # working around https://travis-ci.community/t/mariadb-build-error-with-xenial/3160
  mysql -u root -e "DROP USER IF EXISTS 'travis'@'%';"
  mysql -u root -e "CREATE USER 'travis'@'%';"
  mysql -u root -e "CREATE DATABASE pulp;"
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'travis'@'%';";
else
  psql -c 'CREATE DATABASE pulp OWNER travis;'
fi

pip install ansible
cp pulp_maven/.travis/playbook.yml ansible-pulp/playbook.yml
cp pulp_maven/.travis/postgres.yml ansible-pulp/postgres.yml
cp pulp_maven/.travis/mariadb.yml ansible-pulp/mariadb.yml

cd pulp_maven

