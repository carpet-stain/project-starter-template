# Changelog

All notable changes to this project, generated from Conventional Commits.
## [1.0.0] - 2026-08-19

### Features

- *(git)* Bootstrap with the git-flow governance base
- *(git)* Move copier templates + lint tooling from dotfiles ([#7](https://github.com/carpet-stain/project-starter-template/pull/7))
- *(ci)* Add gitleaks secret scanning to the base lefthook tier ([#33](https://github.com/carpet-stain/project-starter-template/pull/33))
- *(ci)* Add shfmt + shellcheck to the base lefthook tier ([#34](https://github.com/carpet-stain/project-starter-template/pull/34))
- *(ci)* Add editorconfig-checker + justfile-format to the base tier ([#35](https://github.com/carpet-stain/project-starter-template/pull/35))
- *(ci)* Add just format recipe + release-gated cliff-preview ([#36](https://github.com/carpet-stain/project-starter-template/pull/36))
- *(git-flow)* Port pr-code-review.yml, move retrofit/branch-protection scripts in-repo ([#43](https://github.com/carpet-stain/project-starter-template/pull/43))
- *(ci)* Render-and-verify e2e for the copier templates ([#46](https://github.com/carpet-stain/project-starter-template/pull/46))
- *(ci)* Port pr-guards.yml's issue-link job from dotfiles#449 ([#58](https://github.com/carpet-stain/project-starter-template/pull/58))
- *(ci)* Governance-surface propagation reminder ([#59](https://github.com/carpet-stain/project-starter-template/pull/59))
- *(ci)* Crash-cleanup preamble for stale e2e sandbox branches/PRs ([#61](https://github.com/carpet-stain/project-starter-template/pull/61))
- *(ci)* Dispatch-triggered live e2e workflow against template-e2e ([#62](https://github.com/carpet-stain/project-starter-template/pull/62))
- *(ci)* One-time bootstrap workflow for the e2e sandbox's main branch ([#64](https://github.com/carpet-stain/project-starter-template/pull/64))
- *(ci)* Exercise include_release_automation=true live against the sandbox ([#68](https://github.com/carpet-stain/project-starter-template/pull/68))
- *(git-flow)* Port the advisory PR reviewer to dotfiles' OpenRouter DIY reviewer ([#77](https://github.com/carpet-stain/project-starter-template/pull/77))
- *(ci)* Swap the e2e workflows' Bitwarden fetch for infra's OIDC path ([#80](https://github.com/carpet-stain/project-starter-template/pull/80))
- *(git-flow)* Resolve GH_TOKEN via vended token in .envrc ([#86](https://github.com/carpet-stain/project-starter-template/pull/86))
- *(git-flow)* Ship blocking@2 concision lint + yamlfmt fix ([#87](https://github.com/carpet-stain/project-starter-template/pull/87))
- *(git-flow)* Add the epic-complete workflow to the base ([#91](https://github.com/carpet-stain/project-starter-template/pull/91))
- *(typescript)* Add a Node+pnpm language overlay ([#98](https://github.com/carpet-stain/project-starter-template/pull/98))
- *(typescript)* Add project_kind=lib to the overlay ([#108](https://github.com/carpet-stain/project-starter-template/pull/108))

### Bug Fixes

- *(python)* Pin the post-gen task's interpreter to bash ([#9](https://github.com/carpet-stain/project-starter-template/pull/9))
- *(ci)* Drop unprovisioned dependabot labels stanza ([#32](https://github.com/carpet-stain/project-starter-template/pull/32))
- *(python)* Invoke the post-gen task's interpreter directly, not via a shebang ([#38](https://github.com/carpet-stain/project-starter-template/pull/38))
- *(git-flow)* Run md-format before markdownlint ([#56](https://github.com/carpet-stain/project-starter-template/pull/56))
- *(ci)* Target main explicitly when cloning template-e2e ([#63](https://github.com/carpet-stain/project-starter-template/pull/63))
- *(ci)* Install the lefthook binary before rendering the e2e payload ([#65](https://github.com/carpet-stain/project-starter-template/pull/65))
- *(ci)* Handle a no-diff render in the live e2e workflow ([#66](https://github.com/carpet-stain/project-starter-template/pull/66))
- *(ci)* Tolerate GitHub-side timing lag in the live e2e workflow ([#67](https://github.com/carpet-stain/project-starter-template/pull/67))
- *(git-flow)* Normalize the v-prefix on a repo's first-ever release ([#69](https://github.com/carpet-stain/project-starter-template/pull/69))
- *(agent-config)* Force the _retrofit-src fetch to avoid a silent no-op ([#76](https://github.com/carpet-stain/project-starter-template/pull/76))
- *(typescript)* Ship the overlay's .node-version ([#101](https://github.com/carpet-stain/project-starter-template/pull/101))
- *(python)* Rename the overlay format verb to fmt ([#102](https://github.com/carpet-stain/project-starter-template/pull/102))

### Documentation

- Write this repo's own README ([#8](https://github.com/carpet-stain/project-starter-template/pull/8))
- *(git)* Cover infra-provisioned repos in the bootstrap runbook, drop stale apply-labels.sh reference ([#40](https://github.com/carpet-stain/project-starter-template/pull/40))
- Write a guide for authoring a new language overlay ([#44](https://github.com/carpet-stain/project-starter-template/pull/44))
- Fix ADR-0020/0021 location refs ([#55](https://github.com/carpet-stain/project-starter-template/pull/55))
- *(git-flow)* Document the template's unseeded label dependency ([#78](https://github.com/carpet-stain/project-starter-template/pull/78))
- *(scripts)* Point bootstrap at infra admin token ([#81](https://github.com/carpet-stain/project-starter-template/pull/81))
- *(adr)* Skip a devcontainer in the python overlay for now ([#83](https://github.com/carpet-stain/project-starter-template/pull/83))
- *(adr)* Distribute governance workflows as reusable workflows ([#105](https://github.com/carpet-stain/project-starter-template/pull/105))

### CI

- *(adr-guard)* Drop the labeled/unlabeled trigger ([#103](https://github.com/carpet-stain/project-starter-template/pull/103))
- *(reusable)* Host workflow_call versions of the four guards ([#106](https://github.com/carpet-stain/project-starter-template/pull/106))
- *(reusable)* Switch own workflows and payload to thin callers ([#107](https://github.com/carpet-stain/project-starter-template/pull/107))
- *(reusable)* Parameterize issue-link exemptions ([#109](https://github.com/carpet-stain/project-starter-template/pull/109))
- *(release)* Adopt release automation and pin callers to @v1 ([#111](https://github.com/carpet-stain/project-starter-template/pull/111))

### Chore

- *(ci)* Bump actions/setup-node from 4 to 7 ([#4](https://github.com/carpet-stain/project-starter-template/pull/4))
- *(ci)* Bump extractions/setup-just from 3 to 4 ([#5](https://github.com/carpet-stain/project-starter-template/pull/5))
- *(ci)* Bump actions/checkout from 4 to 7 ([#6](https://github.com/carpet-stain/project-starter-template/pull/6))
- *(claude)* Add initial backlog-manager memory ([#14](https://github.com/carpet-stain/project-starter-template/pull/14))
- *(ci)* Bump actions/checkout from 4 to 7 ([#21](https://github.com/carpet-stain/project-starter-template/pull/21))
- *(ci)* Bump actions/setup-node from 4 to 7 ([#23](https://github.com/carpet-stain/project-starter-template/pull/23))
- *(ci)* Bump astral-sh/setup-uv from 3 to 7 ([#22](https://github.com/carpet-stain/project-starter-template/pull/22))
- *(ci)* Bump extractions/setup-just from 3 to 4 ([#24](https://github.com/carpet-stain/project-starter-template/pull/24))
- Merge this repo's own justfile/lefthook composition into single files ([#39](https://github.com/carpet-stain/project-starter-template/pull/39))
- Land the comment-concision lint ([#57](https://github.com/carpet-stain/project-starter-template/pull/57))
- *(claude)* Sync backlog-manager memory ([#54](https://github.com/carpet-stain/project-starter-template/pull/54))
- *(claude)* Sync backlog-manager memory ([#74](https://github.com/carpet-stain/project-starter-template/pull/74))
- *(claude)* Stop committing agent-memory ([#85](https://github.com/carpet-stain/project-starter-template/pull/85))
- *(ci)* Bump payload action pins to latest major ([#92](https://github.com/carpet-stain/project-starter-template/pull/92))
- *(ci)* Guard payload action pins against own workflows ([#93](https://github.com/carpet-stain/project-starter-template/pull/93))

