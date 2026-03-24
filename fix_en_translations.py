#!/usr/bin/env python3
import re

# Path to the file
file_path = "lib/core/l10n/app_localizations.dart"

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find the _translations map
# We look for: static const Map<String, Map<String, String>> _translations = {
pattern = r'(static const Map<String, Map<String, String>> _translations = \{)(.*?)(\};)'
match = re.search(pattern, content, re.DOTALL)

if not match:
    print("ERROR: Could not find _translations map")
    exit(1)

prefix = match.group(1)
translations_content = match.group(2)
suffix = match.group(3)

# Now find the 'en' section within translations_content
# Pattern: 'en': { ... }
en_pattern = r"('en':\s*\{)([^}]*(?:\{[^}]*\}[^}]*)*)(\}\s*,?)"
en_match = re.search(en_pattern, translations_content, re.DOTALL)

if not en_match:
    print("ERROR: Could not find 'en' section in _translations")
    exit(1)

en_prefix = en_match.group(1)  # 'en': {
en_content = en_match.group(2)  # content inside the braces
en_suffix = en_match.group(3)  # } followed by comma or nothing

print(f"Found English section, length: {len(en_content)} characters")

# Define corrections for the English section: map of incorrect value patterns to correct values
# We'll look for specific key-value pairs where the value is wrong.
# We'll use regex to find and replace.

corrections = {
    # Key: (incorrect_value_pattern, correct_value)
    'admin': (r"'admin':\s*'[^']*'", "'admin': 'Admin'"),
    'incidencias': (r"'incidencias':\s*'[^']*'", "'incidencias': 'Incidents'"),
    # Add more if needed
}

# Apply corrections
fixed_content = en_content
changes = 0
for key, (pattern, replacement) in corrections.items():
    # We need to make sure we only replace within the correct key context.
    # The pattern already includes the key, so it's safe.
    old_content = fixed_content
    fixed_content = re.sub(pattern, replacement, fixed_content)
    if old_content != fixed_content:
        changes += 1
        print(f"Fixed {key}: {replacement}")

if changes == 0:
    print("No corrections applied to English section.")
else:
    print(f"Applied {changes} corrections.")

# Rebuild the translations section
new_translations = translations_content.replace(en_match.group(0), en_prefix + fixed_content + en_suffix)

# Rebuild the full content
new_content = content.replace(match.group(0), prefix + new_translations + suffix)

# Write back to file
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("File updated successfully.")