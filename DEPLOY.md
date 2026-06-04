# Deployment Notes

This site is based on the open-source al-folio academic website template:

- Repository: https://github.com/alshedivat/al-folio
- License: MIT
- GitHub stars checked on 2026-06-04: about 15.7k

## Current GitHub Pages State

The current `tju-yxq.github.io` repository already contains a generated static site for `www.yxq0413.top`.
Its latest commit says it was deployed from `tju-yxq/yxq-blog-source`.

Because of that, replacing the live homepage should be done from the source repository or by intentionally
switching the deployment pipeline. Do not accidentally push this source tree to `alshedivat/al-folio`.

## Recommended Deployment Path

1. Back up or branch the existing `tju-yxq/yxq-blog-source` repository.
2. Replace its source tree with this al-folio source tree.
3. Keep `CNAME` in the repository root to preserve `www.yxq0413.top`.
4. Confirm the source repository still has the `PERSONAL_TOKEN` secret. The existing Hugo workflow already used this secret.
5. Push to `tju-yxq/yxq-blog-source:main`.
6. `.github/workflows/deploy.yml` will build the Jekyll site and publish `_site` to `tju-yxq/tju-yxq.github.io:main`.

## Local Verification Status

Static YAML parsing passed for `_config.yml`, `_data/cv.yml`, and `_data/socials.yml`.
Full local Jekyll build was not completed because local RubyGems downloads stalled while installing missing gems
`jekyll-scholar` and `csl-styles`. The bundled GitHub Actions workflow installs dependencies on GitHub-hosted
Linux runners during deployment.
