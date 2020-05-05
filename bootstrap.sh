#!/bin/sh
DEVBOX_REPO="git@github.com:devinsba/devbox"
LASTPASS_EMAIL_ADDRESS="badevins@gmail.com"

function get_linux_distro() {
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

function macos() {
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

  if ! brew commands > /dev/null 2>&1; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  brew install git ansible lastpass-cli
}

function debian() {
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get install -y git ansible lastpass-cli
}

sudo -v

case $(uname) in
Darwin)
  macos
  ;;
Linux)
  case $(get_linux_distro) in
  Debian)
    debian
    ;;
  esac
  ;;
esac

lpass login "${LASTPASS_EMAIL_ADDRESS}"
mkdir -p "${HOME}/.ssh"
lpass show --field="Private Key" ssh@personal > "${HOME}/.ssh/id_rsa" && chmod 600 "${HOME}/.ssh/id_rsa"
lpass show --field="Public Key" ssh@personal > "${HOME}/.ssh/id_rsa.pub"

# Clone repo
mkdir -p "${HOME}/.local/opt"
if [ -d "${HOME}/.local/opt/devbox" ]; then
  (
    cd "${HOME}/.local/opt/devbox"
    git pull
  )
else
  git clone "${DEVBOX_REPO}" "${HOME}/.local/opt/devbox"
fi

(
  cd "${HOME}/.local/opt/devbox/ansible"
  ansible-playbook -K -i inventory site.yml
)

# rcm
echo "DOTFILES_DIRS=\"${HOME}/.local/opt/devbox/dotfiles\"" > "${HOME}/.rcrc"
echo "TAGS=\"$(uname)\"" >> "${HOME}/.rcrc"
rcup -vf