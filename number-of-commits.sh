#!/bin/bash

# Organization name
ORG="distribution-innovation"

# Prompt the user for the number of days
read -p "Enter the number of days to look back: " days

# Prompt the user for a specific contributor (optional)
read -p "Enter the username to filter by (leave blank for all users): " filter_user

# Prompt the user for the number of repositories to limit
read -p "Enter the number of repositories to limit (e.g., 15): " repo_limit

# Get the current date and calculate the date X days ago
date_threshold=$(date -v-"$days"d +"%Y-%m-%dT%H:%M:%SZ")

# Get the specified number of repositories in the organization
repos=$(gh repo list $ORG --json name --jq '.[].name' | head -n "$repo_limit")

# Create a temporary file to store commits
temp_file=$(mktemp)

# Initialize the temporary file
echo "" > "$temp_file"

# Loop over each repository
for repo in $repos; do
    echo "Processing repository: $repo"

    # Fetch commits within the last X days
    if [ -z "$filter_user" ]; then
        commits=$(gh api --paginate "repos/$ORG/$repo/commits?since=$date_threshold" --jq ".[] | \"\(.author.login) $repo \(.commit.committer.date[0:7])\"")
    else
        commits=$(gh api --paginate "repos/$ORG/$repo/commits?since=$date_threshold&author=$filter_user" --jq ".[] | \"\(.author.login) $repo \(.commit.committer.date[0:7])\"")
    fi

    # Append each commit's author, repository, and date to the temp file
    echo "$commits" >> "$temp_file"
done

# Generate the report: count commits per user, per repository, across the last X days
report=$(awk '{print $1, $2}' "$temp_file" | sort | uniq -c | sort -nr)

# Define the table header
printf "%-20s %-20s %-10s\n" "Repository" "Contributor" "Commits"
printf "%-20s %-20s %-10s\n" "-------------------" "-------------------" "---------"

# Print the formatted table
echo "$report" | while read -r count user repo; do
    printf "%-20s %-20s %-10s\n" "$repo" "$user" "$count"
done

# Clean up the temporary file
rm "$temp_file"

