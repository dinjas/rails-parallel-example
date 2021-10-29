#!/bin/bash

set -eu

bundle update --bundler

bundle install

npm install

bundle exec rake db:reset
