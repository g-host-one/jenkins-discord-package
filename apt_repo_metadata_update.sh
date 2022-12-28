#!/usr/bin/env bash

if [ -z "$REPO_DIR" ] || [ -z "$REPO_CONF" ] || [ -z "$GNUPGHOME" ] || [ -z "$ubuntuPgpKey" ] || [ -z "$PGP_KEY_NAME" ]; then
    echo "One of environment variables is not set" 
    exit 1
fi

cd $REPO_DIR

mkdir -p ./dists/stable/main/binary-amd64/

apt-ftparchive --arch amd64 packages -c=$REPO_CONF ./pool/main > ./dists/stable/main/binary-amd64/Packages
gzip -kf9 ./dists/stable/main/binary-amd64/Packages

apt-ftparchive contents -c=$REPO_CONF ./pool/main > ./dists/stable/main/Contents-amd64
gzip -kf9 ./dists/stable/main/Contents-amd64

apt-ftparchive release -c=$REPO_CONF ./dists/stable/main/binary-amd64 > ./dists/stable/main/binary-amd64/Release
apt-ftparchive release -c=$REPO_CONF ./dists/stable > ./dists/stable/Release

mkdir -pm 700 $GNUPGHOME

cat $ubuntuPgpKey | gpg --batch --yes --import

if [ ! -f gpg ]; then
    gpg --batch --yes --armor --export "$PGP_KEY_NAME" > gpg
fi

gpg --batch --yes --default-key "$PGP_KEY_NAME" -abs -o ./dists/stable/main/binary-amd64/Release.gpg ./dists/stable/main/binary-amd64/Release
gpg --batch --yes --default-key "$PGP_KEY_NAME" -abs --clearsign -o ./dists/stable/main/binary-amd64/InRelease ./dists/stable/main/binary-amd64/Release

gpg --batch --yes --default-key "$PGP_KEY_NAME" -abs -o ./dists/stable/Release.gpg ./dists/stable/Release
gpg --batch --yes --default-key "$PGP_KEY_NAME" -abs --clearsign -o ./dists/stable/InRelease ./dists/stable/Release