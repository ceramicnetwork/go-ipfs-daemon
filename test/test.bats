@test "Builds the Docker image" {
    docker build . --file Dockerfile --tag go-ipfs-daemon
}

@test "Runs the Docker image" {
    docker run -e UDP_RECV_BUFFER_SIZE="" go-ipfs-daemon dag stat /ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn || exit 1
}
