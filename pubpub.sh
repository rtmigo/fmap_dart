#!/bin/bash
set -e && cd "${0%/*}"

script_parent_dir="${0%/*}"

# creates a copy of the project in temporary directory
# and prepares the copy to be published

function publish() {

  temp_pub_dir=$(mktemp -d -t pub-XXXXXXX)

  echo "$temp_pub_dir"
  cd "$temp_pub_dir"
  git clone --branch staging https://github.com/rtmigo/fmap .

  rm -rf ./.git*

  # removing everything before "\n# ", the first header
  old_readme=$(cat README.md | tr '\n' '\r')
  new_readme=$(echo "$old_readme" | perl -p0e 's|^.*?\r# |# \1|')
  new_readme=$(echo "$new_readme" |  tr '\r' '\n')
  echo "$new_readme" > "$temp_pub_dir/README.md"

  dartfmt -w .
  dart pub get
  dart analyze

  #dart pub publish --dry-run
  dart pub publish
}

function update_master() {
  cd "$script_parent_dir"
  git checkout master
  git merge staging
  git push -u origin master
  git checkout dev
}

publish
update_master
