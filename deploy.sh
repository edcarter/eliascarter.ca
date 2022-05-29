# Deploy jekyll static website to s3 and then invalidate cloudfront cache
#
# environment variable parameters:
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_DEFAULT_REGION
# AWS_S3_BUCKET
# AWS_CLOUDFRONT_DISTRIBUTION

# Print each command run and exit on non-zero exit code of subcommands.
# Some people don't like -e: http://mywiki.wooledge.org/BashFAQ/105
set -ex

# Strip all exif data off of assets
#exiftool -overwrite_original_in_place -m -all= assets/*

# Build jekyll project
bundle exec jekyll build

# Install aws cli from here: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
source .env
aws s3 sync _site/ ${AWS_S3_BUCKET}
aws cloudfront create-invalidation --distribution-id ${AWS_CLOUDFRONT_DISTRIBUTION} --paths "/*"
