import { Controller, Get, Header } from '@nestjs/common';

/**
 * Serves iOS Universal Links and Android App Links verification files.
 * These endpoints allow homp:// and https://app.homp.app deep links to
 * open the native apps without going through a browser.
 */
@Controller('.well-known')
export class WellKnownController {
  @Get('apple-app-site-association')
  @Header('Content-Type', 'application/json')
  appleAppSiteAssociation() {
    return {
      applinks: {
        apps: [],
        details: [
          {
            appID: 'TEAMID.com.homp.guest',
            paths: ['*'],
          },
        ],
      },
      webcredentials: {
        apps: ['TEAMID.com.homp.guest'],
      },
    };
  }

  @Get('assetlinks.json')
  @Header('Content-Type', 'application/json')
  assetLinks() {
    return [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: 'com.homp.guest',
          sha256_cert_fingerprints: [
            process.env.ANDROID_SHA256_FINGERPRINT ?? 'REPLACE_WITH_RELEASE_KEYSTORE_SHA256',
          ],
        },
      },
    ];
  }
}
