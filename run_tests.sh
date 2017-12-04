#!/bin/bash

function check() {
  cmd=$1
  expected_out_file=$2

  differences=$(diff "${expected_out_file}" <(ruby ${cmd}))

  if [[ -z "$differences" ]] ; then
    echo "Pass"
  else
    echo "Failed"
    echo "$differences"
  fi
}

check "pp.rb testdata/pp.in" "testdata/pp.out"
check "main.rb testdata/main.train testdata/main.test" "testdata/main.out"
