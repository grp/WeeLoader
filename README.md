## WeeLoader

WeeLoader is similar to PreferenceLoader, but for WeeAppPlugins rather than PreferenceBundles. Basically, it makes SpringBoard load WeeAppPlugins from a different directory. This is beneficial for a few reasons: it works better with Safe Mode, as WeeLoader isn't loaded into SpringBoard in that case, and it easily fixes all of the issues with semitethered jailbreaks and Wee apps.

To use WeeLoader with your plugins, simply move your bundles from `/System/Library/WeeAppPlugins/` to `/Library/WeeLoader/Plugins/` (for Wee apps) or `/System/Library/BulletinBoardPlugins/` to `/Library/WeeLoader/BulletinBoardPlugins` (for Bulletin Board plugins), and update any hardcoded paths in your code (if necessary). You'll also want to add a dependency on `com.chpwn.weeloader` to ensure WeeLoader is installed.



