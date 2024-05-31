#!/bin/bash

# Prompt user for input
read -p "What is the image repository URL (SHOW IMAGE REPOSITORIES IN SCHEMA)? " repository_url

# Paths to the files
makefile="./Makefile"

# Copy files
cp $makefile.template $makefile

# Replace placeholders in Makefile file using | as delimiter
sed -i "" "s|<<repository_url>>|$repository_url|g" $makefile

echo "Placeholder values have been replaced!"
