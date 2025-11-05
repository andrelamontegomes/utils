#!/bin/bash

# Git Squash Script
# Squashes all commits on current branch back to base branch (default: main)
# Usage: ./git-squash.sh [base-branch]

set -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE=${1:-main}

# Check if we're on the base branch
if [ "$BRANCH" = "$BASE" ]; then
    echo "Error: Cannot squash $BASE into itself"
    exit 1
fi

# Get the first commit message from the branch
FIRST_MSG=$(git log $BASE..HEAD --format=%B --reverse | head -n 1)

if [ -z "$FIRST_MSG" ]; then
    echo "Error: No commits found between $BASE and $BRANCH"
    exit 1
fi

# Get the merge base
MERGE_BASE=$(git merge-base $BASE HEAD)

echo "Squashing commits from $BASE to $BRANCH..."
echo "Using commit message: $FIRST_MSG"
echo ""

# Confirm before proceeding
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

# Squash commits
git reset --soft $MERGE_BASE
git commit -m "$FIRST_MSG"

echo "Commits squashed successfully!"
echo ""

# Push with force-with-lease
read -p "Push to remote with --force-with-lease? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push --force-with-lease origin $BRANCH
    echo "Pushed to origin/$BRANCH"
else
    echo "Skipped push. Run manually: git push --force-with-lease origin $BRANCH"
fi
