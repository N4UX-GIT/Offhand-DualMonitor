"""Prevent a tagged workflow from replacing an already-published addon beta."""
import json
import os
import re
import urllib.error
import urllib.request


def check(repository, token, tag='v2.1.5-beta.30'):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+', tag):
        raise ValueError('Invalid addon beta tag')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid GitHub repository')
    request = urllib.request.Request(
        'https://api.github.com/repos/' + repository + '/releases/tags/' + tag,
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'Offhand-addon-beta-release-guard'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            release = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return
        raise RuntimeError('Release-state lookup failed: HTTP ' + str(error.code)) from None
    if release.get('tag_name') != tag or release.get('draft') is not True:
        raise ValueError('Published addon beta assets must not be replaced')


if __name__ == '__main__':
    tag = os.environ.get('OFFHAND_RELEASE_TAG', 'v2.1.5-beta.30')
    check(os.environ['GITHUB_REPOSITORY'], os.environ['GH_TOKEN'], tag)
    print('PASS: ' + tag + ' is absent or remains an unpublished draft')
