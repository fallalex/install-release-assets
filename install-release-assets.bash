#!/usr/local/bin/bash
#/bin/bash
# You need a github personal token exported before running this script
# Best to avoid writing the token to history

# HISTCONTROL=ignoreboth
#  ./tool-binaries.bash GITHUB_TOKEN

# set +o history
# ./tool-binaries.bash GITHUB_TOKEN
# set -o history

# read stdin to bash array
mapfile -t lines

INSTALL_BIN=/usr/local/bin/
TMP_BIN_DIR=/tmp/github-bin
TMP_ASSET_DIR=/tmp/github-assets

fetch_version=v0.4.6
fetch_url="https://github.com/gruntwork-io/fetch/releases/download/$fetch_version/fetch_linux_amd64"

mkdir -p $TMP_BIN_DIR
mkdir -p $INSTALL_BIN

curl -sL $fetch_url -o $INSTALL_BIN/fetch
chmod +x $INSTALL_BIN/fetch

for line in "${lines[@]}"; do
  bin_name=$(echo $line | cut -d',' -f1)
  repo_name=$(echo $line | cut -d',' -f2)
  release_tag=$(echo $line | cut -d',' -f3)
  asset_regex=$(echo $line | cut -d',' -f4)
  new_bin_name=$(echo $line | cut -d',' -f5)

  if [[ -z $asset_regex ]]; then
    asset_regex="(linux_amd64|86_64.*musl)"
  fi

  mkdir -p $TMP_ASSET_DIR/$bin_name
  echo "https://github.com/$repo_name"
  # The regex for the assest oftens matches more than needed resulting in more download time
  # There is no clear return so we need to use the regex again 
  $INSTALL_BIN/fetch --github-oauth-token="$1" --repo="https://github.com/$repo_name" --tag="$release_tag" --release-asset="$asset_regex" $TMP_ASSET_DIR/$bin_name
  # This sqashes results. Sort matches then only use the first.
  asset=$(find "$TMP_ASSET_DIR/$bin_name" -type f -regextype posix-extended -regex ".*$asset_regex.*" | sort | head -1)

  if [[ $asset == *.tar.gz ]]; then
    bin_path=$(tar -tzf $asset | grep -E "(^|^.*/)$bin_name$")
    tar -O -zxf $asset $bin_path > $TMP_BIN_DIR/$bin_name
  elif [[ $asset == *.tar.xz ]]; then
    bin_path=$(tar -tJf $asset | grep -E "(^|^.*/)$bin_name$")
    tar -O -Jxf $asset $bin_path > $TMP_BIN_DIR/$bin_name
  elif [[ $asset == *.zip ]]; then
    bin_path=$(zipinfo -1 $asset | grep -E "(^|^.*/)$bin_name$")
    unzip -oq -j $asset $bin_path -d $TMP_BIN_DIR
  else
    mv $asset $TMP_BIN_DIR/$bin_name
  fi

  if [[ $? -eq 0 ]] && [[ $(chmod +x $TMP_BIN_DIR/$bin_name && $TMP_BIN_DIR/$bin_name --help) ]]; then
    if [[ -n $new_bin_name ]]; then
      mv -f -v $TMP_BIN_DIR/$bin_name $TMP_BIN_DIR/$new_bin_name
    fi
    echo "  Succeeded"
  else
    rm -f $TMP_BIN_DIR/$bin_name
    echo "  Failed"
  fi
done

bin_count=$(ls -1 $TMP_BIN_DIR | wc -l)
install -v -o $USER -g $(id -gn $USER) $TMP_BIN_DIR/* $INSTALL_BIN
rm -rf $TMP_BIN_DIR $TMP_ASSET_DIR
if [[ ${#BIN_INFO[@]} != $bin_count ]]; then
  echo Error: Expected ${#BIN_INFO[@]} binaries found $bin_count
  exit 1
fi

