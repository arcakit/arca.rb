# Contributing to Arca

## Getting up and running

- Clone this repository
- `bundle install`
- `bundle exec rake test` (or `bundle exec rake`), which runs the full test suite

Optional: run RuboCop with `bundle exec rubocop` if you have it; the project uses `.rubocop.yml` for style.

## Test setup

Tests live under `test/` with `*_test.rb` files. Most examples use stubbed SOAP responses; fixtures (WSDL and XML responses) are under `test/fixtures/` per service (e.g. `test/fixtures/wsaa/`, `test/fixtures/wsfe/`). Use `env: :test` in constructors so the client loads the local WSDL and tests don’t hit real endpoints.

## Running tests

- Full suite: `bundle exec rake test` or `bundle exec rake`
- Single file: `ruby -Ilib -Itest test/arca/wsfe_test.rb`
- Or run one file via Rake: `bundle exec rake test TEST=test/arca/wsfe_test.rb`

## Pushing to GitHub and CI

- Push your branch: `git push origin main` (or your branch name).
- **CI** (`.github/workflows/ci.yml`) runs on every push: it installs dependencies and runs `bundle exec rake` (tests). Ensure tests pass before releasing.
- View runs: **Actions** tab at https://github.com/arcakit/arca.rb/actions.

## Publishing to RubyGems via CI

Releases use the official [rubygems/release-gem](https://github.com/rubygems/release-gem) action with **Trusted Publishing** (no API key secrets). The workflow runs tests, then runs `rake release` (build, push gem, create and push the version tag).

### One-time setup: Trusted Publishing

1. On RubyGems.org: log in → your gem **arca** → **Publishing** (or **Edit gem**) → add a **Trusted publisher**.
2. Choose **GitHub Actions** and link this repo: `arcakit/arca.rb` (or your fork). Follow [RubyGems: Adding a publisher](https://guides.rubygems.org/trusted-publishing/adding-a-publisher/).
3. No GitHub secrets are needed; the action uses OIDC to authenticate to RubyGems.

### Release steps

- **Prechecks**
  - [ ] CI is green on the branch you're releasing from.
  - [ ] Update `CHANGELOG.md` and `lib/arca/version.rb` (e.g. `1.0.1`).
  - [ ] Commit and push: `git add -A && git commit -m "Release 1.0.1" && git push`.
- **Run the Release workflow**
  - [ ] Open **Actions** → **Release** → **Run workflow**. Select the branch (e.g. `main`) and run.
  - [ ] The workflow runs tests, then [rubygems/release-gem](https://github.com/rubygems/release-gem) runs `rake release`: builds the gem, pushes to RubyGems.org, and creates/pushes the tag (e.g. `v1.0.1`).
- **After publish**
  - [ ] Create a GitHub release at https://github.com/arcakit/arca.rb/releases (optional; tag is already pushed).
  - [ ] Bump `lib/arca/version.rb` to a prerelease if you use one (e.g. `1.0.2.dev`).
