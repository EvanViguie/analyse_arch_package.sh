# AUR Package Security Analyzer

This repository contains a script to analyze the security aspects of an Arch Linux package build using AUR PKGBUILD data. It integrates with the Google Generative Language Gemini API to provide an AI-assisted security analysis.

## Features

- Retrieve and analyze PKGBUILD data for a given package.
- Fetch detailed package information using `yay`.
- Query the AUR RPC API for package details.
- Generate a comprehensive Markdown report with:
    - PKGBUILD contents.
    - Package information (if AUR package).
    - AUR package details (if AUR package).
    - AI-generated security analysis.

## Prerequisites

- Arch Linux or an Arch-based distribution (for `yay`).
- `curl`, `jq`, `yay` installed.
- An API key for Google's Generative Language API. Store it securely in a file located at `~/.gcp_api_key`.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/AUR-Package-Security-Analyzer.git
   cd AUR-Package-Security-Analyzer
   ```

2. Make the script executable:

   ```bash
   chmod +x analyze_aur_package.sh
   ```

3. Ensure your Google Cloud API key is saved in `~/.gcp_api_key`.

## Usage

```bash
./analyze_aur_package.sh <package_name>
```

Replace `<package_name>` with the name of the AUR package you want to analyze.

Example:

```bash
./analyze_aur_package.sh libngtcp2
```

## Output

The script will generate a Markdown report file named `<package_name>_report.md` in the generated_report directory containing the security analysis.

### Example Output

You can find several example markdown reports in example_reports

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Disclaimer

This tool is intended to assist with security analysis but does not replace thorough manual review.