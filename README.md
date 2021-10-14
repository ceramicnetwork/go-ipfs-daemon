# go-ipfs-daemon

This repo builds a Docker image that runs a [js-ceramic](https://github.com/ceramicnetwork/js-ceramic) compatible version of [go-ipfs](https://github.com/ipfs/go-ipfs).

The go-ipfs daemon that this image runs supports resolving dag-jose objects and using S3 for a datastore with sharding.

## Usage

```sh
git clone <this_repo_url>

cd go-ipfs-daemon

docker build . -t go-ipfs-daemon

# Fill in your credentials below
docker run \
  -e IPFS_ENABLE_S3=true \
  -e IPFS_S3_REGION= \
  -e IPFS_S3_BUCKET_NAME= \
  -e IPFS_S3_ROOT_DIRECTORY= \
  -e IPFS_S3_ACCESS_KEY_ID= \
  -e IPFS_S3_SECRET_ACCESS_KEY= \
  go-ipfs-daemon

```

AWS IAM permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::bucket_name",
                "arn:aws:s3:::bucket_name/*"
            ]
        }
    ]
}
```

## Maintainers

[@v-stickykeys](https://github.com/v-stickykeys)
