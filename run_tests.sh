#!/bin/bash

differences=$(diff testdata/output_parse_trees <(ruby pp.rb testdata/input_parse_trees))

if [[ -z "$differences" ]] ; then
  echo "Pass"
else
  echo "Failed"
  echo "$differences"
fi
