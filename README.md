# go-ipfs-daemon

**WIP**

This repo builds a Docker image that runs a [js-ceramic](https://github.com/ceramicnetwork/js-ceramic) compatible version of [go-ipfs](https://github.com/ipfs/go-ipfs).

The go-ipfs daemon that this image runs supports resolving dag-jose objects, using S3 for a sharded datastore, and serving a healthcheck endpoint.

## Usage

Simply pull the image from Dockerhub

```sh
docker pull ceramicnetwork/go-ipfs-daemon
```

Or you can download the source code and build the image on your machine

```sh
git clone <this_repo_url>

cd go-ipfs-daemon

docker build . -t go-ipfs-daemon
```

Run a container

```sh
docker run \
  -p 5001:5001 \ # API port
  -p 8011:8011 # Healthcheck port
  go-ipfs-daemon
```

You may want to use S3 for the IPFS Blockstore. See the [go-ds-s3 plugin](https://github.com/3box/go-ds-s3#configuration) for more configuration details.

```sh
# Fill in your credentials below
docker run \
  -p 5001:5001 \ # API port
  -p 8011:8011 \ # Healthcheck port
  -e IPFS_ENABLE_S3=true \
  -e IPFS_S3_REGION= \
  -e IPFS_S3_BUCKET_NAME= \
  -e IPFS_S3_ROOT_DIRECTORY= \
  -e IPFS_S3_ACCESS_KEY_ID= \
  -e IPFS_S3_SECRET_ACCESS_KEY= \
  -e IPFS_S3_KEY_TRANSFORM=next-to-last/2 \
  go-ipfs-daemon

# Get the container id
docker ps

# Run ipfs commands
docker exec -i <container_id> sh -c "ipfs version"
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

## Maintainer

[@v-stickykeys](https://github.com/v-stickykeys)

## Contributing

We are happy to accept small and large contributions.

## License

Dual-licensed under Apache 2.0 and MIT terms:

- Apache License, Version 2.0, ([LICENSE-APACHE](https://github.com/ipfs/go-ipfs/blob/master/LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](https://github.com/ipfs/go-ipfs/blob/master/LICENSE-MIT) or http://opensource.org/licenses/MIT)
