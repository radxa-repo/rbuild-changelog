#!/usr/bin/env bash

GH_REPO=

_gh_set_repo() {
    GH_REPO="$1"
}

_gh_check_available() {
    gh repo view "$GH_REPO" --json name 2>&1
}

_gh_get_last_release() {
    gh release list --repo "$GH_REPO" --limit 1 | cut -f 3
}

_gh_get_last_release_date() {
    gh release list --repo "$GH_REPO" --limit 1 | cut -f 4
}

_gh_get_release_date() {
    gh release view --json publishedAt --repo "$GH_REPO" "$1" --jq ".publishedAt"
}
