#!/bin/bash

PERSONAL=${PERSONAL:-0}
WORK=${WORK:-0}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

init_color() {
  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  BOLD=$(printf '\033[1m')
  DEFAULT_FONT=$(printf '\033[0m')
}

log_error() {
  printf '%sError: %s%s\n' "${BOLD}${RED}" "$*" "$DEFAULT_FONT" >&2
}

log_success() {
  printf '%s%s%s\n' "${GREEN}" "$*" "$DEFAULT_FONT" >&2
}

init_settings() {
  read -p 'Install personal apps? [y/n]: ' ANSWER
  case $ANSWER in  
    y|Y) PERSONAL=1 ;;
  esac

  read -p 'Install work apps? [y/n]: ' ANSWER
  case $ANSWER in  
    y|Y) WORK=1 ;;
  esac
}

setup_ohmyzsh() {
  if ! command_exists zsh; then
      echo "setting up ohmyzsh..."
      sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
      echo 'eval "$(pyenv init -)"' >> ~/.zshrc
      log_success "ohmyzsh setup completed! Please re-run this script."
      exit 0
  fi
}

setup_rosetta() {
  echo "setting up Rosetta 2..."
  arch_name="$(uname -m)"
  if [ "${arch_name}" = "x86_64" ]; then
      HOMEBREW_PREFIX = "/usr/local"
      if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
          log_success "already running on Rosetta 2"
      else
          log_success "running on Intel (Rosetta 2 not needed)"
      fi 
  elif [ "${arch_name}" = "arm64" ]; then
      HOMEBREW_PREFIX = "/opt/homebrew"
      sudo softwareupdate --install-rosetta
      log_success "Rosetta 2 setup completed!"
  else
      log_error "unknown architecture: ${arch_name}!"
      exit 1
  fi
}

setup_brew() {
  echo "setting up homebrew..."
  if ! command_exists brew; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      echo 'eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ~/.zprofile
      eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
  fi
  brew update
  log_success "homebrew setup completed!"
}

install_brew_packages_common() {
  COMMON_PACKAGES=(
    gnupg
    # go
    kubectl
    minikube
    mysql
    pyenv
    python3
  )
  echo "installing common homebrew packages..."
  brew install ${COMMON_PACKAGES[@]}
  log_success "homebrew common packages installed!"
  
  echo "linking homebrew packages..."
  brew link ${COMMON_PACKAGES[@]} # brew link --force ${COMMON_PACKAGES[@]}
  log_success "homebrew packages linked!"
}

install_terraform() {
  echo "installing terraform..."
  if ! command_exists terraform; then
      brew tap hashicorp/tap
      brew install hashicorp/tap/terraform
      terraform -install-autocomplete
  fi
  brew update
  log_success "terraform installed!"
}

install_brew_packages_work() {
  WORK_PACKAGES=(
    cloudflare/cloudflare/cloudflared
  )
  if [ $WORK = 1 ]; then
      echo "installing work homebrew packages..."
      brew install ${WORK_PACKAGES[@]}
      log_success "homebrew work packages installed!"
  fi
}

install_brew_cask_common() {
  COMMON_CASKS=(
    1password
    1password-cli
    apache-directory-studio
    authy
    aws-vault
    brave-browser
    docker
    firefox
    google-chrome
    iterm2
    microsoft-edge
    microsoft-excel
    microsoft-powerpoint
    microsoft-teams
    microsoft-word
    mysqlworkbench
    notion
    onedrive
    openvpn-connect
    postgres-unofficial
    postico
    postman
    slack
    spectacle
    tableplus
    telegram
    temurin
    visual-studio-code
  )
  echo "installing common apps..."
  brew install --cask ${COMMON_CASKS[@]}
  log_success "common apps installed!"
}

install_brew_cask_work() {
  WORK_CASKS=(
    cloudflare-warp
    intune-company-portal
  )
  if [ $WORK = 1 ]; then
      echo "installing work apps..."
      brew install --cask ${WORK_CASKS[@]}
      log_success "work apps installed!"
  fi
}

install_brew_cask_personal() {
  PERSONAL_CASKS=(
    dropbox
    google-drive
    megasync
    vlc
    vmware-fusion
  )
  if [ $PERSONAL = 1 ]; then
      echo "installing personal apps..."
      brew install --cask ${PERSONAL_CASKS[@]}
      log_success "personal apps installed!"
  fi
}

cleanup_brew() {
  echo "cleaning up homebrew..."
  brew cleanup
  log_success "homebrew cleanup completed!"
}

setup_python() {
  echo "updating pip..."
  python3 -m pip install --upgrade pip
  log_success "pip updated!"

  echo "installing python packages..."
  PYTHON_PACKAGES=(
    black
    pylint
    pylint-django
    isort
  )
  sudo pip3 install ${PYTHON_PACKAGES[@]}
  log_success "python packages installed!"

  echo "configuring pyenv..."
  echo 'eval "$(pyenv init --path)"' >> ~/.zprofile
  echo 'eval "$(pyenv init -)"' >> ~/.zshrc
  log_success "pyenv configured!"
}

setup_nodejs() {
  if ! command_exists nvm; then
      echo "installing nvm..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
      export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      log_success "nvm installed!"

      echo "configuring nvm..."
      cat <<'EOT' >> ~/.zshrc

autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
EOT
      echo "nvm configured!"
      
      echo "installing nodejs lts version..."
      nvm install --lts
      log_success "nodejs lts installed!"
  
      echo "updating npm..."
      npm install -g npm@latest
      log_success "npm updated!"

      echo "installing npm global packages..."
      NODEJS_PACKAGES=(
        dynamodb-admin
        serve
      )
      npm install -g ${NODEJS_PACKAGES[@]}
      log_success "npm global packages installed!"
  fi

  if ! command_exists yvm; then
      echo "installing yarn version manager..."
      brew install tophat/bar/yvm
      log_success "yvm installed!"
  fi
}

setup_aws() {
  if ! command_exists aws; then
      echo "installing aws cli..."
      curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
      sudo installer -pkg AWSCLIV2.pkg -target /
      log_success "aws cli installed!"
      
      echo "removing installation package..."
      rm AWSCLIV2.pkg
      log_success "installation package removed!"

      echo "setting up aws config files..."
      mkdir ~/.aws
      touch ~/.aws/config
      touch ~/.aws/credentials
      log_success "aws files configured!"
  fi
}

configure_git() {
  echo "configuring git..."
  git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
  git config --global credential.helper osxkeychain
  log_success "git configured!"
}

configure_preferences() {
  echo "configuring OS preferences..."
  defaults write -g com.apple.mouse.scaling -float 2.5
  defaults write -g com.apple.trackpad.scaling -float 2.5
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock tilesize -int 38
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults -currentHost write -globalDomain com.apple.mouse.tapBehavior -int 1
  log_success "preferences configured!"
}

main() {
  echo "starting Mac OS setup..."

  init_color

  command_exists git || {
    log_error "git is not installed!"
    exit 1
  }

  sudo -v

  init_settings

  setup_rosetta
  setup_brew
  install_brew_packages_common
  install_terraform
  install_brew_packages_work
  install_brew_cask_common
  install_brew_cask_work
  install_brew_cask_personal
  cleanup_brew
  setup_python
  setup_nodejs
  setup_aws
  configure_git
  configure_preferences

  log_success "Mac OS setup completed! Please restart machine."
}

main