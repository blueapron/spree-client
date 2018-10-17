# Blue Apron Ruby Spree Client

## Setup

* Clone the repo
* `rbenv install 2.2.2`
* `rbenv local 2.2.2; rbenv rehash`
* `bundle install`

## Commands

* ```bundle exec rake spec``` to run tests.
* ```bundle console``` and then ``` require 'blue_apron/spree_client' ``` to run the Gem.

## Updating Pre-Release Versions

To update your pre-release version of the gem:

```
bundle outdated spree_client --pre
```
