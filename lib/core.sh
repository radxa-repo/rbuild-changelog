#!/usr/bin/env bash

_gh_repo_changelog() {
    local from="$1" to="$2"
    local release_date="" release_tag="" old_release="" new_release=""

    while read -r
    do
        release_tag="$(cut -f 3 <<< "$REPLY")"
        release_date="$(cut -f 4 <<< "$REPLY")"

        if [[ "$release_date" < "$to" ]] && [[ -z "$new_release" ]]
        then
            new_release="$release_tag"
        elif [[ "$release_date" < "$from" ]] && [[ -z "$old_release" ]]
        then
            old_release="$release_tag"
        fi
    done <<< "$(gh release list --limit 65535 --exclude-drafts --exclude-pre-releases --repo "$GH_REPO")"

    if [[ -z "$old_release" ]]
    then
        cat << EOF
## $GH_REPO

* init at $new_release

EOF
    else
        cat << EOF
## $GH_REPO

* $old_release upgraded to $new_release

EOF
        if wget -O /tmp//tmp/deb_changelog "https://raw.githubusercontent.com/$GH_REPO/main/debian/changelog" &>/dev/null || \
           wget -O /tmp/deb_changelog "https://raw.githubusercontent.com/$GH_REPO/master/debian/changelog" &>/dev/null
        then
        cat << EOF
\`\`\`
$(dpkg-parsechangelog --file /tmp/deb_changelog --since "$old_release" --to "$new_release" --show-field "Changes")
\`\`\`

EOF
        fi
        rm /tmp/deb_changelog
    fi
}

_gh_org_changelog() {
    local org="$1" from="$2" to="$3"

    while read -r
    do
        if [[ -z "$REPLY" ]]
        then
            break
        fi

        _gh_set_repo "$org/$REPLY"
        _gh_repo_changelog "$from" "$to"
    done <<< "$(gh repo list "$org" --limit 65535 --json name,pushedAt --jq ".[] | select( (.pushedAt|fromdateiso8601) >= (\"$from\"|fromdateiso8601) ) | .name")"
}

_git_changelog() {
    local repo="$1" ref="$2" from="$3" to="$4"

    if [[ ! -d "$SCRIPT_DIR/../$repo" ]]
    then
        echo "$(realpath "$SCRIPT_DIR/../$repo") is missing. Skip..." >&2
        return
    fi

    pushd "$SCRIPT_DIR/../$repo" &>/dev/null || return
    cat << EOF
## $repo

\`\`\`
$(git log --oneline --no-merges --since="$from" --until="$to" "$ref")
\`\`\`

EOF
    popd &>/dev/null || (echo "Failed to return to main execution!" >&2; exit 1)
}

_generate_changelog() {
    local product="$1" from_tag="$2" to_tag="$3"
    local from="" to=""

    if [[ -z "$from_tag" ]]
    then
        from_tag="$(_gh_get_last_release)"
        from="$(_gh_get_last_release_date)"
    else
        from="$(_gh_get_release_date "$from_tag")"
    fi

    if [[ -z "$to_tag" ]]
    then
        to_tag="Current"
        to="$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"
    else
        to="$(_gh_get_release_date "$to_tag")"
    fi

    cat << EOF
# rbuild Environment Changelog ($product)

This is an automatically generated changelog for the rbuild environment.

Not all changes listed here will affect the final image. They are listed
because they modified the rbuild environment.

Changes made in radxa/kernel or radxa/u-boot are currently untracked.

* From: $from_tag ($from)
* To: $to_tag ($to)

EOF
    _gh_org_changelog "radxa-pkg" "$from" "$to"

    _git_changelog "rbuild" "origin/main" "$from" "$to"
    _git_changelog "bsp" "origin/main" "$from" "$to"
    _git_changelog "overlays" "origin/main" "$from" "$to"
}
