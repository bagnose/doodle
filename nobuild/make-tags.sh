#!/bin/bash

find -L src -name \*.d | ctags -L- --extra=+f -f TAGS ;
