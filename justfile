# Justfile — bebash task runner.
# Recipes are thin: linters and tests run through pre-commit (never invoked
# directly), and dev tooling runs inside the pinned Nix devShell (flake.nix).
# Indentation is TAB (see .editorconfig [justfile]).

# Current version. The committed VERSION file is the authoring source of truth
# (ADR-0018); the signed v* tag is cut to mirror it. A dev checkout without a
# VERSION file falls back to `git describe`; a leading `v` is stripped so the
# number is always a bare X.Y.Z.
version := `{ cat VERSION 2>/dev/null || git describe --tags --dirty --always 2>/dev/null || echo 0.0.0; } | sed 's/^v//'`

# List available recipes.
default:
	@just --list

# Install bebash for the current user (or system paths under root).
install:
	./install.sh

# Remove bebash using the recorded install manifest.
uninstall:
	./uninstall.sh

# Lint: shellcheck + shfmt + markdown, all via pre-commit.
lint:
	nix develop --command pre-commit run --all-files

# Test: bats unit + integration, driven through pre-commit stages.
test:
	nix develop --command pre-commit run test-unit --all-files --hook-stage pre-commit
	nix develop --command pre-commit run test-integration --all-files --hook-stage pre-push

# Build the man page from its scdoc source.
man:
	nix develop --command sh -c 'scdoc < man/bebash.1.scd > man/bebash.1'

# Bash has no package registry — the signed tag + GitHub Release is the release.
# VERSION is committed, so `git archive HEAD` already carries it; no injection.
# `git archive` pins every entry's mtime to the commit and emits tree-sorted
# entries; `gzip -n` drops the gzip timestamp, so the tarball is reproducible.
# Distribution: reproducible tarball + sha256sum for the GitHub Release.
dist:
	mkdir -p dist
	git archive --format=tar --prefix=bebash-{{version}}/ HEAD \
		| gzip -n > dist/bebash-{{version}}.tar.gz
	cd dist && sha256sum bebash-{{version}}.tar.gz > bebash-{{version}}.tar.gz.sha256

# Cut a release from the current branch (run this on `develop`). git-cliff
# computes the next version from Conventional Commits, writes CHANGELOG.md and
# the bare VERSION, commits, and cuts a SIGNED annotated v* tag. The final
# `git push --follow-tags` is left to you (confirm before CI publishes).
# The committed VERSION is the authoring source of truth; the tag mirrors it.
release:
	nix develop --command git-cliff --bump -o CHANGELOG.md
	nix develop --command sh -c 'printf "%s\n" "$(git-cliff --bumped-version)" | sed "s/^v//" > VERSION'
	@new="v$(cat VERSION)"; \
		git commit -am "chore(release): $new"; \
		git tag -s "$new" -m "$new"; \
		echo "Tagged $new. Now run: git push --follow-tags"
