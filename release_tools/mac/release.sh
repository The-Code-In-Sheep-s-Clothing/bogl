#!/bin/bash

#
# Mac release script
#

echo ""
echo -e "\033[92mBuilding 'boglserver' binary for Mac release\033[0m"
echo ""

# freh build with static compilation on
stack clean
stack build

# install to the local bin
stack install

# use the binary to the present location for ease of access
cp $HOME/.local/bin/boglserver .

# Verify there are no dynamic dependencies in this binary
otool -L boglserver

echo ""
echo -e "\033[92mDone building Mac release\033[0m"
echo ""
