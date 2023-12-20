#!/bin/sh
set -o xtrace

DEVBOX_REPO="git@github.com:devinsba/devbox"
DEVBOX_REPO_HTTP="http://github.com/devinsba/devbox"
onePASSWORD_EMAIL_ADDRESS="badevins@gmail.com"

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
  wait
  if ! op whoami | grep 'Email:' > /dev/null; then
    echo "In another terminal run: op account add --address my.1password.com --email \"${onePASSWORD_EMAIL_ADDRESS}\""
    echo "-- Hit enter once this is done"
    read
  fi
  mkdir -p "${HOME}/.ssh"
  op read --out-file "$HOME/.ssh/personal_key" "op://private/personal ssh key/private key?ssh-format=openssh" && chmod 600 "${HOME}/.ssh/personal_key"
  op read --out-file "$HOME/.ssh/personal_key.pub" "op://private/personal ssh key/public key"

  cat << EOF > $HOME/.ssh/config
host github.com
  HostName github.com
  IdentityFile ~/.ssh/personal_key
EOF
}

public_repo() {
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
  Debian | "Debian GNU/Linux" | Ubuntu | "Pop!_OS")
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
  ansible-playbook -K -i inventory site.yml
)

# rcm
echo "DOTFILES_DIRS=\"${HOME}/.local/opt/devbox/dotfiles ${HOME}/.local/opt/devbox-private/dotfiles\"" > "${HOME}/.rcrc"
echo "TAGS=\"$(uname)\"" >> "${HOME}/.rcrc"
rcup -vf

set +o xtrace