# devbox
Collection of all devbox configuration (dotfiles, ansible, bootstrap)

```
curl https://raw.githubusercontent.com/devinsba/devbox/master/bootstrap.sh | zsh
```

## Testing ansible roles

Requires Docker. `test.sh` builds a throwaway Debian container and runs
`ansible-playbook` inside it, so a role can be tried out without touching
the real machine:

```
./test.sh                 # run the fnm + uv roles
./test.sh fnm,uv,antidote # run a custom set of tagged roles
./test.sh shell           # drop into the container instead of running the playbook
```

This only exercises the OS-agnostic roles (tags match `ansible/site.yml`:
`antidote`, `fnm`, `sdkman`, `uv`, `debian`). The `osx` role (Homebrew
casks, `/etc/shells`, login shell changes) can't be tested this way since
it's macOS-only — review it by reading the diff instead.

## Work mode

On machines without your personal 1Password, set `DEVBOX_MODE=work`. The
repo is cloned anonymously over HTTPS (no GitHub auth needed), the 1Password ssh agent setup is skipped, and
`devbox-private` is not cloned or added to `DOTFILES_DIRS`. The `osx` role also skips all
Homebrew casks (Chrome, iTerm2, JetBrains Toolbox, VS Code, Divvy, Rancher Desktop).

```
curl -fsSL https://raw.githubusercontent.com/devinsba/devbox/master/bootstrap.sh | DEVBOX_MODE=work sh
```

## Testing bootstrap.sh

Requires Docker. `test-bootstrap.sh` runs bootstrap.sh's Linux path
end-to-end in a fresh Debian container, seeded from this repo's local
working tree (uncommitted changes included) and `../devbox-private` if
present:

```
./test-bootstrap.sh
```

It sets `DEVBOX_LOCAL_TEST=1`, which makes bootstrap.sh skip the steps a
container can't do non-interactively: pulling an ssh key from 1Password,
and cloning from GitHub over SSH (the mounted local copy is used instead).
Everything else — package installs, the full `ansible-playbook` run,
`rcup` — runs for real inside the container. Not covered: the macOS path,
and the real 1Password ssh-key flow.
