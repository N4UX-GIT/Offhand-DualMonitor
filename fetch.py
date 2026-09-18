import urllib.request
cf_url = 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/curseforge.svg'
gh_url = 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/github.svg'

with urllib.request.urlopen(cf_url) as response:
    cf_svg = response.read().decode('utf-8')
    print("CF SVG:", cf_svg[:100])
    with open('curseforge.svg', 'w') as f:
        f.write(cf_svg)

with urllib.request.urlopen(gh_url) as response:
    gh_svg = response.read().decode('utf-8')
    with open('github.svg', 'w') as f:
        f.write(gh_svg)

