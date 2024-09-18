#!/bin/bash

# GitHub personal access token (set it in your environment or replace it here)
GITHUB_TOKEN=""

# File containing list of PR URLs
PR_LIST_FILE="/Users/rishi/Downloads/dummy-test/pr-list"


# Read each URL from the file and approve the pull request
while IFS= read -r pr_url; do
  # Extract repository owner, repo, and pull request number from the URL
  repo_info=$(echo "$pr_url" | awk -F 'github.com/|/pull/' '{print $2}')
  pr_number=$(echo "$pr_url" | awk -F 'pull/' '{print $2}')

  if [ -z "$repo_info" ] || [ -z "$pr_number" ]; then
    echo "Invalid PR URL format: $pr_url"
    continue
  fi

  # Approve the pull request using GitHub API
  api_url="https://api.github.com/repos/$repo_info/pulls/$pr_number/reviews"
  response=$(curl -s -X POST "$api_url" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d '{"event":"APPROVE"}')

  # Check if the response contains a successful approval
  if echo "$response" | grep -q '"state": "APPROVED"'; then
    echo "Pull request approved: $pr_url"
  else
    echo "Failed to approve pull request: $pr_url"
    echo "Response: $response"
  fi

done < "$PR_LIST_FILE"
