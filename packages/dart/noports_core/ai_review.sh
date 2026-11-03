#!/bin/bash

BASE_BRANCH=${1:-main}

git diff "$BASE_BRANCH"...HEAD \
| gemini ask "
You are my personal code review agent.
Review this diff and:
- Use REVIEW.md
"
