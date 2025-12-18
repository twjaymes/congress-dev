#!/bin/bash
# Python cleanup and pyenv installation script
# Generated for Ubuntu 24.04 LTS

set -e  # Exit on error

echo "=== Installing system Python and pip ==="
sudo apt update
sudo apt install -y python3 python3-venv python3-pip python-is-python3

echo ""
echo "=== Verifying Python installation ==="
python3 --version
python --version
pip3 --version

echo ""
echo "=== Installing pyenv build dependencies ==="
sudo apt install -y build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev curl git \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

echo ""
echo "=== Installing pyenv ==="
if [ -d "$HOME/.pyenv" ]; then
    echo "pyenv directory already exists, backing up to ~/.pyenv.backup"
    mv ~/.pyenv ~/.pyenv.backup
fi

curl https://pyenv.run | bash

echo ""
echo "=== Adding pyenv to .zshrc ==="
cat >> ~/.zshrc << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF

echo ""
echo "=== Sourcing .zshrc to load pyenv ==="
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

echo ""
echo "=== Verifying pyenv installation ==="
pyenv --version

echo ""
echo "=== Installing Python 3.12.7 with pyenv ==="
pyenv install 3.12.7

echo ""
echo "=== Setting Python 3.12.7 as global default ==="
pyenv global 3.12.7

echo ""
echo "=== Final verification ==="
python --version
which python python3 pip
pyenv versions

echo ""
echo "=== Testing virtual environment ==="
python -m venv ~/test-venv
source ~/test-venv/bin/activate
python -m pip --version
deactivate
rm -rf ~/test-venv

echo ""
echo "=== Checking for remaining Homebrew paths ==="
echo $PATH | tr ':' '\n' | grep -i brew || echo "No brew paths found ✓"

echo ""
echo "=========================================="
echo "Installation complete!"
echo "Restart your shell or run: exec zsh -l"
echo "=========================================="
