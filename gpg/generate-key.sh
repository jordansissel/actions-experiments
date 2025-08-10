#!/bin/sh

if [ -z "$1" ] ; then
  echo "Usage: $0 <email>"
  echo
  echo "This will create a new pgp key for the given email"
  echo "and will output the public and private keys"
  exit 1
fi

tmp="$(mktemp -d)"

email="$1"

# Generate a never-expiring key
gpg --homedir "$tmp" --quiet --batch \
  --passphrase '' --pinentry-mode loopback \
  --quick-generate-key "$email" default default never

gpg --homedir "$tmp" --armor --export "$email"
echo

gpg --homedir "$tmp" --armor --export-secret-keys "$email"
echo

echo -n "Key ID: "
gpg --homedir "$tmp" --quiet --list-keys --list-options show-only-fpr-mbox "$email" | awk '{print $1}'

[ -d "$tmp" ] && rm -r "$tmp"
