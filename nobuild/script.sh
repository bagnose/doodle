#!/bin/bash

for i in $*; do
    cat $i | sed 's/protected void setStruct/protected override void setStruct/g' >| $i.new && mv -f $i.new $i
done
