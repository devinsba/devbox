#!/bin/sh
set -o xtrace

DEVBOX_REPO="git@github.com:devinsba/devbox"
LASTPASS_EMAIL_ADDRESS="badevins@gmail.com"

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

  if ! brew commands > /dev/null 2>&1; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  brew install git ansible lastpass-cli
}

debian() {
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get install -y zsh git ansible lastpass-cli
}

sudo -v

case $(uname) in
Darwin)
  macos
  ;;
Linux)
  case $(get_linux_distro) in
  Debian | Ubuntu | "Pop!_OS")
    debian
    ;;
  esac
  ;;
esac

if ! lpass status | grep 'Logged in' > /dev/null; then
  cat << EOF > /tmp/lpass_askpass
#!/bin/bash

echo -n "Enter \$@: " > /dev/stderr

read -s answer
echo \$answer
EOF

  chmod u+x /tmp/lpass_askpass
  export LPASS_ASKPASS=/tmp/lpass_askpass

  mkdir -p "${HOME}/.local/share/lpass"
  lpass login --trust "${LASTPASS_EMAIL_ADDRESS}"
fi
mkdir -p "${HOME}/.ssh"
lpass show --field="Private Key" ssh@personal > "${HOME}/.ssh/personal_key" && chmod 600 "${HOME}/.ssh/personal_key"
lpass show --field="Public Key" ssh@personal > "${HOME}/.ssh/personal_key.pub"

cat << EOF > $HOME/.ssh/config
host github.com
  HostName github.com
  IdentityFile ~/.ssh/personal_key
EOF

# Clone repos
mkdir -p "${HOME}/.local/opt"
if [ -d "${HOME}/.local/opt/devbox" ]; then
  (
    cd "${HOME}/.local/opt/devbox"
    git pull
  )
else
  git clone "${DEVBOX_REPO}" "${HOME}/.local/opt/devbox"
fi
if [ -d "${HOME}/.local/opt/devbox-private" ]; then
  (
    cd "${HOME}/.local/opt/devbox-private"
    git pull
  )
else
  git clone "${DEVBOX_REPO}-private" "${HOME}/.local/opt/devbox-private"
fi

(
  cd "${HOME}/.local/opt/devbox/ansible"
  ansible-playbook -K -i inventory site.yml
)

# rcm
echo "DOTFILES_DIRS=\"${HOME}/.local/opt/devbox/dotfiles ${HOME}/.local/opt/devbox-private/dotfiles\"" > "${HOME}/.rcrc"
echo "TAGS=\"$(uname)\"" >> "${HOME}/.rcrc"
rcup -vf

set +o xtrace