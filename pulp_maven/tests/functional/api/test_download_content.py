# coding=utf-8
"""Tests that verify download of content served by Pulp."""
import hashlib
import unittest
from random import choice
from urllib.parse import urljoin

from pulp_smash import api, config, utils
from pulp_smash.pulp3.constants import BASE_DISTRIBUTION_PATH, REPO_PATH
from pulp_smash.pulp3.utils import (
    gen_distribution,
    gen_repo
)

from pulp_maven.tests.functional.utils import (
    gen_maven_remote,
    get_maven_content_paths
)
from pulp_maven.tests.functional.constants import (
    MAVEN_CONTENT_PATH,
    MAVEN_FIXTURE_URL,
    MAVEN_REMOTE_PATH
)
from pulp_maven.tests.functional.utils import set_up_module as setUpModule  # noqa:F401


MAVEN_DISTRIBUTION_PATH = urljoin(BASE_DISTRIBUTION_PATH, 'maven/maven/')


class DownloadContentTestCase(unittest.TestCase):
    """Verify whether content served by pulp can be downloaded."""

    def test_all(self):
        """Verify whether content served by pulp can be downloaded.

        The process of creating a Maven mirror is simple:

        1. Create a Maven Remote with a URL pointing to the root of a Maven repository.
        2. Create a distribution with the remote set HREF from 1.

        Do the following:

        1. Create a Maven Remote and a Distribution.
        2. Select a random content unit in the distribution. Download that
           content unit from Pulp, and verify that the content unit has the
           same checksum when fetched directly from Maven Central.

        This test targets the following issues:

        * `Pulp #2895 <https://pulp.plan.io/issues/2895>`_
        * `Pulp Smash #872 <https://github.com/PulpQE/pulp-smash/issues/872>`_
        """
        cfg = config.get_config()
        client = api.Client(cfg, api.json_handler)

        repo = client.post(REPO_PATH, gen_repo())
        self.addCleanup(client.delete, repo['_href'])

        body = gen_maven_remote()
        remote = client.post(MAVEN_REMOTE_PATH, body)
        self.addCleanup(client.delete, remote['_href'])

        repo = client.get(repo['_href'])

        # Create a distribution.
        body = gen_distribution()
        body['remote'] = remote['_href']
        response_dict = client.post(MAVEN_DISTRIBUTION_PATH, body)
        dist_task = client.get(response_dict['task'])
        distribution_href = dist_task['created_resources'][0]
        distribution = client.get(distribution_href)
        self.addCleanup(client.delete, distribution['_href'])

        # Pick a content unit, and download it from both Pulp Fixtures…
        unit_path = choice(get_maven_content_paths(repo))
        fixtures_hash = hashlib.sha256(
            utils.http_get(urljoin(MAVEN_FIXTURE_URL, unit_path))
        ).hexdigest()

        # …and Pulp.
        client.response_handler = api.safe_handler

        unit_url = cfg.get_hosts('api')[0].roles['api']['scheme']
        unit_url += '://' + distribution['base_url'] + '/'
        unit_url = urljoin(unit_url, unit_path)

        pulp_hash = hashlib.sha256(client.get(unit_url).content).hexdigest()
        self.assertEqual(fixtures_hash, pulp_hash)

        # Check that Pulp created a MavenArtifact
        content_filter_url = MAVEN_CONTENT_PATH + '?filename=custommatcher-1.0-javadoc.jar.sha1'
        content_unit = client.get(content_filter_url)
        self.assertEqual(1, content_unit.json()['count'])
