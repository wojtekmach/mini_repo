# CHANGELOG

## HEAD

* Add `/public_key`
* Handle outer checksums
* Document minimal IAM policy for accessing S3
* Incoming params should have string (not atom) keys
* Apply `:sync_opts` to syncing releases

## v0.2.0 (2019-10-09)

* Add simple auth
* Validate package metadata on publishing
* Protect against path traversal when storing files
* Use only allowed repos in docs publishing endpoint
* Add more options for s3 store
* Fix reading respons body
* Add `:sync_opts` option to MiniRepo.Mirror

## v0.1.0 (2019-07-30)

* Initial release
