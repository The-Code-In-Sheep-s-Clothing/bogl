##
## Release script for Windows
## Run this in GitBash, works just fine so long
## as 'stack' has already been installed.
## The entire process from scratch will take about 10-20 minutes
##

echo ""
echo -e "\033[92mBuilding 'boglserver' binary for Windows release\033[0m"
echo ""

## Only thing this needs in advance is stack to be installed

## fresh build with static compilation on
stack clean
stack build

## install to local bin
stack install

## move binary to cur location
cp $HOME/AppData/Roaming/local/bin/boglserver.exe .

## no dep verification here...

echo ""
echo -e "\033[92mDone building Windows release\033[0m"
echo ""
