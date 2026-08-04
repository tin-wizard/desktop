// Copyright (c) 2016-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

const {spawnSync} = require('child_process');
const path = require('path');

function getAppFileName(context) {
    switch (context.electronPlatformName) {
    case 'darwin':
    case 'mas':
        return `${context.packager.appInfo.productFilename}.app`;
    default:
        return '';
    }
}

// The TIN fork has no Apple Developer signing credentials. When
// CSC_IDENTITY_AUTO_DISCOVERY=false, electron-builder skips codesigning
// entirely instead of falling back to an ad-hoc signature. On Apple Silicon
// (arm64), the kernel (AMFI) requires at least an ad-hoc signature for any
// executable to launch, so a fully unsigned .app fails with "can't be
// opened" even after bypassing the Gatekeeper "unidentified developer"
// warning. This hook applies an ad-hoc signature after packaging so builds
// are launchable without any further intervention.
exports.default = async function afterSign(context) {
    if (context.electronPlatformName !== 'darwin' && context.electronPlatformName !== 'mas') {
        return;
    }

    if (process.env.CSC_IDENTITY_AUTO_DISCOVERY !== 'false') {
        return;
    }

    const appPath = path.join(context.appOutDir, getAppFileName(context));
    const result = spawnSync('codesign', ['--force', '--deep', '--sign', '-', appPath]);
    if (result.error || result.status !== 0) {
        throw new Error(
            `Failed to ad-hoc sign ${appPath}: ${result.error} ${result.stderr} ${result.stdout}`,
        );
    }
};
