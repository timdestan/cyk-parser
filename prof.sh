#!/bin/bash

# Updates profile data.
# Requires graphviz be installed.

# TODO: Refactor so we don't need to run the expensive part twice.

dot -Tpng <(ruby prof.rb DOT) -o data/profile_output.png
ruby prof.rb HTML > data/profile_output.html
