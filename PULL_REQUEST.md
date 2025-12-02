# Add Tag Selection Feature for Bootstrap Downloader

## Summary

This PR adds the ability to select and download Bootstrap-Downloader scripts from specific Git tags instead of always using the `main` branch. This enables users to install specific versions of ComfyUI-Auto_installer and ensures version consistency across installations.

## Changes

### New Files

- **`scripts/Fetch-Tag-Bootstrap.ps1`**: New PowerShell script that:
  - Fetches available tags from the GitHub repository via API
  - Provides an interactive menu for tag selection
  - Downloads `Bootstrap-Downloader.ps1` from the selected tag(s)
  - Automatically modifies the `baseUrl` in downloaded scripts to point to the selected tag instead of `main`
  - Saves the selected bootstrap as `Bootstrap-Downloader-Selected.ps1` for batch file integration

### Modified Files

- **`UmeAiRT-Install-ComfyUI.bat`**: Updated installation batch file to:
  - Download `Fetch-Tag-Bootstrap.ps1` if it doesn't exist
  - Execute tag selection before downloading bootstrap scripts
  - Use the selected tag's bootstrap script instead of always using `main` branch
  - Added error handling for tag selection and bootstrap download failures

## Features

### Interactive Tag Selection
- Displays a numbered list of available tags
- Supports selecting a single tag or multiple tags (comma-separated)
- Option to download all tags at once
- Option to quit without downloading

### Non-Interactive Mode
- `-NonInteractive` switch for automated scripts
- Automatically processes all tags matching the filter

### Tag Filtering
- `-TagFilter` parameter to filter tags (e.g., `v1.*` for version 1.x tags)
- Default filter is `*` (all tags)

### Automatic URL Replacement
- Automatically modifies the `baseUrl` in downloaded Bootstrap-Downloader scripts
- Ensures all subsequent downloads use the correct tag version
- Pattern: `https://github.com/.../raw/main/` → `https://github.com/.../raw/{tag}/`

## Usage

### Standalone Usage

```powershell
# Interactive mode - select tag from menu
.\scripts\Fetch-Tag-Bootstrap.ps1

# Filter tags (e.g., only v1.x versions)
.\scripts\Fetch-Tag-Bootstrap.ps1 -TagFilter "v1.*"

# Non-interactive mode (downloads all matching tags)
.\scripts\Fetch-Tag-Bootstrap.ps1 -NonInteractive -TagFilter "v*"

# Custom output directory
.\scripts\Fetch-Tag-Bootstrap.ps1 -OutputPath ".\tag-versions"
```

### Integrated Usage

The batch file `UmeAiRT-Install-ComfyUI.bat` now automatically:
1. Downloads `Fetch-Tag-Bootstrap.ps1` if needed
2. Prompts user to select a tag
3. Downloads the bootstrap script for the selected tag
4. Executes the bootstrap to download all required files from that tag
5. Continues with the installation process

## Benefits

1. **Version Control**: Users can install specific tagged versions instead of always using the latest `main` branch
2. **Reproducibility**: Ensures consistent installations across different machines using the same tag
3. **Stability**: Allows users to stick with stable releases instead of potentially unstable `main` branch
4. **Flexibility**: Supports both interactive and automated workflows

## Technical Details

- Uses GitHub REST API to fetch tags: `https://api.github.com/repos/{owner}/{repo}/tags`
- Regex pattern matching for `baseUrl` replacement: `\$baseUrl\s*=\s*"https://github\.com/[^/]+/[^/]+/raw/[^"]+/"`
- Saves selected tag name to `selected-tag.txt` for reference
- Creates `Bootstrap-Downloader-Selected.ps1` for batch file integration
- Maintains backward compatibility with existing workflows

## Error Handling

- Validates GitHub URL format
- Handles API request failures gracefully
- Checks for empty tag lists
- Validates user input during tag selection
- Verifies bootstrap script exists before execution
- Provides clear error messages with exit codes

## Testing

Tested scenarios:
- ✅ Fetching tags from GitHub repository
- ✅ Interactive tag selection (single and multiple)
- ✅ Tag filtering with wildcards
- ✅ Non-interactive mode
- ✅ Automatic `baseUrl` replacement
- ✅ Batch file integration
- ✅ Error handling for invalid inputs and network failures

## Notes

- The script requires internet connectivity to fetch tags from GitHub API
- TLS 1.2 protocol is enforced for secure connections
- Selected bootstrap scripts are saved with the format: `Bootstrap-Downloader.{tag}.ps1`
- The first selected tag is also saved as `Bootstrap-Downloader-Selected.ps1` for convenience

