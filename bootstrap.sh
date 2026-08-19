#!/bin/sh
set -o xtrace

DEVBOX_REPO="${DEVBOX_REPO:-git@github.com:devinsba/devbox}"
DEVBOX_REPO_HTTP="${DEVBOX_REPO_HTTP:-http://github.com/devinsba/devbox}"

# When set, skips the steps that need real secrets/network access a
# container can't have (1Password ssh-key pull, cloning from GitHub) and
# assumes ${HOME}/.local/opt/devbox[-private] are already populated, and
# that sudo doesn't need a password. See test-bootstrap.sh.
DEVBOX_LOCAL_TEST="${DEVBOX_LOCAL_TEST:-}"

get_linux_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    echo $NAME
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    lsb_release -si
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    echo $DISTRIB_ID
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    echo "Debian"
  else
    # Fall back to uname, e.g. "Linux", also works for BSD, etc.
    uname -s
  fi
}

macos() {
  if ! xcode-select -p > /dev/null 2>&1; then
    xcode-select --install
  fi

  while ! xcode-select -p > /dev/null 2>&1
  do
    sleep 10
  done

  if ! xcode-select -p > /dev/null 2>&1; then
    echo "xcode command line tools not installed"
    exit 1
  fi

  sudo -v

  if ! brew commands > /dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [ "$(uname -m)" != "x86_64" ] ; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  brew install git ansible lastpass-cli
}

debian() {
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get install -y git ansible

  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo apt update && sudo apt install 1password-cli
}

freebsd() {
  sudo pkg install git
}

ssh_key() {
  if [ -n "${DEVBOX_LOCAL_TEST}" ]; then
    echo "DEVBOX_LOCAL_TEST set, skipping ssh_key"
    return
  fi

  case $(uname) in
  Darwin)
    AGENT_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    ;;
  *)
    AGENT_SOCK="${HOME}/.1password/agent.sock"
    ;;
  esac

  echo "In 1Password, enable Settings > Developer > 'Use the SSH Agent', then toggle 'Use for SSH' on your personal ssh key item."
  echo "-- Hit enter once this is done"
  read _

  if [ ! -S "${AGENT_SOCK}" ] && [ "$(uname)" = "Darwin" ]; then
    FOUND_CONTAINER=$(find "${HOME}/Library/Group Containers" -maxdepth 1 -iname '*1password*' 2>/dev/null | head -n1)
    if [ -n "${FOUND_CONTAINER}" ] && [ -S "${FOUND_CONTAINER}/t/agent.sock" ]; then
      AGENT_SOCK="${FOUND_CONTAINER}/t/agent.sock"
    fi
  fi

  if [ ! -S "${AGENT_SOCK}" ]; then
    echo "Warning: no socket found at ${AGENT_SOCK} -- ssh will not authenticate until the 1Password SSH Agent is actually running there."
  fi

  mkdir -p "${HOME}/.ssh"
  cat << EOF > "$HOME/.ssh/config"
host *
  IdentityAgent "${AGENT_SOCK}"
EOF
}

public_repo() {
  if [ -n "${DEVBOX_LOCAL_TEST}" ]; then
    echo "DEVBOX_LOCAL_TEST set, skipping public_repo sync"
    return
  fi

  mkdir -p "${HOME}/.local/opt"
  if [ -d "${HOME}/.local/opt/devbox" ]; then
    (
      cd "${HOME}/.local/opt/devbox"
      git pull
    )
  else
    git clone "${DEVBOX_REPO}" "${HOME}/.local/opt/devbox"
  fi
}

private_repo() {
  if [ -n "${DEVBOX_LOCAL_TEST}" ]; then
    echo "DEVBOX_LOCAL_TEST set, skipping private_repo sync"
    return
  fi

  if [ -d "${HOME}/.local/opt/devbox-private" ]; then
    (
      cd "${HOME}/.local/opt/devbox-private"
      git pull
    )
  else
    git clone "${DEVBOX_REPO}-private" "${HOME}/.local/opt/devbox-private"
  fi
}

case $(uname) in
Darwin)
  macos
  ssh_key
  public_repo
  private_repo
  ;;
Linux)
  case $(get_linux_distro) in
  Debian | "Debian GNU/Linux" | Ubuntu | "Pop!_OS" | "KDE neon")
    debian
    ;;
  esac
  ssh_key
  public_repo
  private_repo
  ;;
FreeBSD)
  freebsd
  DEVBOX_REPO=$DEVBOX_REPO_HTTP
  public_repo
  ;;
esac

(
  cd "${HOME}/.local/opt/devbox/ansible"
  if [ -n "${DEVBOX_LOCAL_TEST}" ]; then
    ansible-playbook -i inventory site.yml
  else
    ansible-playbook -K -i inventory site.yml
  fi
)

# rcm
echo "DOTFILES_DIRS=\"${HOME}/.local/opt/devbox/dotfiles ${HOME}/.local/opt/devbox-private/dotfiles\"" > "${HOME}/.rcrc"
echo "TAGS=\"$(uname)\"" >> "${HOME}/.rcrc"
rcup -vf

set +o xtrace
