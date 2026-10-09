#!/bin/bash
#set -x

KENTAVR_URL="https://github.com/kentavr-platform/kentavr-firmware.git"

# entrance dir
START_DIR=$(pwd -P)

# new-project clone dir
CLONE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

# parent dir
PARENT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)

# relative project dir
FIRMWARE_DIR=$CLONE_DIR

# git root dir
GIT_DIR=$(git -C "$PARENT_DIR" rev-parse --show-toplevel 2> /dev/null)

if [[ "$CLONE_DIR" == "$GIT_DIR" ]]; then
    FIRMWARE_DIR="."
else
    FIRMWARE_DIR="${FIRMWARE_DIR#"$GIT_DIR"/}"              # convert to relative
fi

PROJECT_NAME=$(basename -- "$GIT_DIR")


normalize_github_url()
{
    local url="$1"
    case "$url" in
        https://github.com/*|http://github.com/*|git://github.com/*|ssh://git@github.com/*|ssh://github.com/*)
            url="${url#*://github.com/}"
            ;;
        git@github.com:*)
            url="${url#git@github.com:}"
            ;;
        *)
            return 0
            ;;
    esac
    url="${url%/}"
    url="${url%.git}"
    url="${url%/}"
    printf '%s\n' "${url,,}"
}

error() 
{
    printf "%s\n" "$1"
    echo "No files were modified."
    cd $START_DIR
    sleep 1
    exit 1
}


KENTAVR_REPO=$(normalize_github_url "$KENTAVR_URL")

echo
echo "  === KentAVR project startup..."
echo "  === Stage 1: Look for a git repository"

if [[ -z "$GIT_DIR" ]]; then
    echo "'$PARENT_DIR' is NOT a part of git repository."
    error "Run 'git init' in the project's root first."
fi

echo "  Found a git repository in '$GIT_DIR'"

# Check for unstaged changes
if ! git -C "$GIT_DIR" diff --quiet; then
    error "There are unstaged changes in '$GIT_DIR'. Commit, discard or stash them first."
fi

echo
echo "  === Stage 2: User confirmations"

candidate="$GIT_DIR/$FIRMWARE_DIR"
read -r -p "   Confirm or enter firmware root directory [$candidate]: " input
candidate=${input:-$candidate}

case "$candidate" in
    /*) candidate="$candidate" ;;
    *)  candidate="$GIT_DIR/$candidate" ;;
esac

FIRMWARE_ROOT=$(CDPATH= cd -P "$candidate" && pwd -P)

case "$FIRMWARE_ROOT" in
    "$GIT_DIR")   FIRMWARE_DIR=. ;;
    "$GIT_DIR"/*) FIRMWARE_DIR=${FIRMWARE_ROOT#"$GIT_DIR"/} ;;
    *) error "Firmware path must be inside this Git folder: $GIT_DIR" ;;
esac

read -r -p "   Confirm or enter firmware project's name [$PROJECT_NAME]: " input
PROJECT_NAME=${input:-$PROJECT_NAME}

# Check for existing directory
if [[ -e "$FIRMWARE_DIR/KentAVR" ]]; then
    error "KentAVR directory already exists in '$FIRMWARE_DIR'."
fi

echo
echo "  === Stage 3: Conditional checks"

# Check for existing submodule
if [[ "$FIRMWARE_DIR" == "." ]]; then
    SUBMODULE_PATH="KentAVR"
else
    SUBMODULE_PATH="$FIRMWARE_DIR/KentAVR"
fi

if [[ -f "$GIT_DIR/.gitmodules" ]]; then
    while IFS= read -r key; do
        module_name="${key#submodule.}"
        module_name="${module_name%.path}"
        module_path=$(git -C "$GIT_DIR" config --file "$GIT_DIR/.gitmodules" --get "$key")
        module_url=$(git -C "$GIT_DIR" config --file "$GIT_DIR/.gitmodules" --get "submodule.$module_name.url")

        if [[ "$module_path" == "$SUBMODULE_PATH" ]]; then
            error "A submodule is already registered at '$module_path'."
        fi
        if [[ -n "$module_url" && "$(normalize_github_url "$module_url")" == "$KENTAVR_REPO" ]]; then
            error "KentAVR submodule is already registered at '$module_path' (URL: $module_url)."
        fi
    done < <(git -C "$GIT_DIR" config --file "$GIT_DIR/.gitmodules" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null)
fi
echo "  Passed"

echo
echo "  === Stage 4: KentAVR submodule"
echo "  Using '$GIT_DIR/$FIRMWARE_DIR' as a firmware root directory"
echo "  Adding a git submodule into '$FIRMWARE_DIR/KentAVR'"

git -C "$GIT_DIR" submodule add "$KENTAVR_URL" "$SUBMODULE_PATH"
echo "  KentAVR submodule registered and downloaded into '$SUBMODULE_PATH'."

echo
echo "  === Stage 5: New project template"
cp -R "$GIT_DIR/$FIRMWARE_DIR/KentAVR/Templates/new-project/." "$GIT_DIR/$FIRMWARE_DIR/" || exit 1
mv "$GIT_DIR/$FIRMWARE_DIR/project.cbp" "$GIT_DIR/$FIRMWARE_DIR/$PROJECT_NAME.cbp" || exit 1
sed -i "s/title=\"KentAVR\"/title=\"$PROJECT_NAME\"/" "$GIT_DIR/$FIRMWARE_DIR/$PROJECT_NAME.cbp"
echo "  New project template applied in '$GIT_DIR/$FIRMWARE_DIR'."


echo
echo "  === Stage 6: Clean up"
rm -rf "$CLONE_DIR/.git"
rm "$CLONE_DIR/README.md"
echo "/Scripts" >> "$GIT_DIR/$FIRMWARE_DIR/.gitignore"

echo
echo "  === Stage 7: Commit changes"
git -C "$GIT_DIR" add --no-warn-embedded-repo -- "$FIRMWARE_DIR"
git -C "$GIT_DIR" commit -m "Empty KentAVR project"

echo
echo "  === KentAVR project startup completed"
echo "  Your firmware project '$PROJECT_NAME' lives in '$GIT_DIR/$FIRMWARE_DIR'"

if [[ $CLONE_DIR != "$GIT_DIR/$FIRMWARE_DIR" ]]; then
    echo "  This directory is not needed any more and you may remove it manually: $CLONE_DIR"
fi

cd $START_DIR   # recover entrance dir
sleep 1
