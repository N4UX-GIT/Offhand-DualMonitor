"""Prevent a tagged workflow from replacing an already-published Beta 30."""
import json
import os
import re
import urllib.error
import urllib.request


def check(repository, token):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid GitHub repository')
    request = urllib.request.Request(
        'https://api.github.com/repos/' + repository + '/releases/tags/v2.1.5-beta.30',
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'Offhand-Beta30-release-guard'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            release = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return
        raise RuntimeError('Release-state lookup failed: HTTP ' + str(error.code)) from None
    if release.get('tag_name') != 'v2.1.5-beta.30' or release.get('draft') is not True:
        raise ValueError('Published Beta 30 assets must not be replaced')


if __name__ == '__main__':
    check(os.environ['GITHUB_REPOSITORY'], os.environ['GH_TOKEN'])
    print('PASS: Beta 30 is absent or remains an unpublished draft')
