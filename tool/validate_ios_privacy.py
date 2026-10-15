#!/usr/bin/env python3
"""Validate SDK declarations, not merely manifest existence.

The source justification and remaining native archive audit are documented in
../doc/IOS_PRIVACY_API_AUDIT.md. No network requests or device data are read.
"""
import plistlib
import sys
from pathlib import Path


def validate(path):
    try:
        with Path(path).open('rb') as handle:
            manifest = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        return [f'Privacy manifest is not a valid property list: {error}']
    if not isinstance(manifest, dict):
        return ['Privacy manifest root must be a dictionary.']
    errors = []
    if manifest.get('NSPrivacyTracking') is not False:
        errors.append('SDK must declare NSPrivacyTracking=false.')
    if manifest.get('NSPrivacyTrackingDomains') != []:
        errors.append('SDK must not declare tracking domains.')
    if manifest.get('NSPrivacyCollectedDataTypes') != []:
        errors.append('Unexpected SDK collected data declaration: review dataflow policy.')
    entries = manifest.get('NSPrivacyAccessedAPITypes')
    if not isinstance(entries, list):
        return errors + ['NSPrivacyAccessedAPITypes must be an array.']
    declared = {}
    for entry in entries:
        if not isinstance(entry, dict):
            errors.append('Each required reason API entry must be a dictionary.')
            continue
        category = entry.get('NSPrivacyAccessedAPIType')
        reasons = entry.get('NSPrivacyAccessedAPITypeReasons')
        if not isinstance(category, str) or category in declared:
            errors.append('Missing or duplicate required reason API category.')
            continue
        if (not isinstance(reasons, list) or not reasons
                or any(not isinstance(reason, str) or not reason for reason in reasons)
                or len(set(reasons)) != len(reasons)):
            errors.append(f'{category} must contain unique non-empty reason codes.')
            continue
        declared[category] = reasons
    # Stat/lstat are called by the SDK directory policy. RLN additionally uses
    # app-owned file metadata for wallet persistence/orphan-file cleanup.
    if declared.get('NSPrivacyAccessedAPICategoryFileTimestamp') != ['C617.1']:
        errors.append('App-container file metadata requires FileTimestamp C617.1.')
    unexpected = set(declared) - {'NSPrivacyAccessedAPICategoryFileTimestamp'}
    if unexpected:
        errors.append('Unreviewed API categories: ' + ', '.join(sorted(unexpected)))
    return errors


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Expected the SDK PrivacyInfo.xcprivacy path.')
    findings = validate(sys.argv[1])
    if findings:
        print('\n'.join(findings), file=sys.stderr)
        sys.exit(1)
    print('SDK iOS privacy manifest structure and source-justified reasons passed.')
