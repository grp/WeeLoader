
#define kWeeLoaderDefaultPluginDirectory @"/System/Library/WeeAppPlugins"
#define kWeeLoaderCustomPluginDirectory @"/Library/WeeLoader/Plugins"

#define kWeeLoaderDefaultBulletinBoardPluginDirectory @"/System/Library/BulletinBoardPlugins"
#define kWeeLoaderCustomBulletinBoardPluginDirectory @"/Library/WeeLoader/BulletinBoardPlugins"

#define kWeeLoaderThreadDictionaryKey @"WeeLoaderLoadingPlugins"

static BOOL WeeLoaderCurrentThreadLoadingStatus() {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:kWeeLoaderThreadDictionaryKey] intValue];
}

static void WeeLoaderSetCurrentThreadLoadingStatus(BOOL loading) {
    [[[NSThread currentThread] threadDictionary] setObject:[NSNumber numberWithInt:loading] forKey:kWeeLoaderThreadDictionaryKey];
}

%hook BBServer

- (void)_loadAllWeeAppSections {
    WeeLoaderSetCurrentThreadLoadingStatus(1);
    %orig;
    WeeLoaderSetCurrentThreadLoadingStatus(0);
}

- (void)_loadAllDataProviderPluginBundles {
    WeeLoaderSetCurrentThreadLoadingStatus(2);
    %orig;
    WeeLoaderSetCurrentThreadLoadingStatus(0);
}

%end

%hook NSFileManager

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    switch (WeeLoaderCurrentThreadLoadingStatus()) {
        case 1: {
            NSArray *plugins = %orig(path, error);
            NSArray *custom = %orig(kWeeLoaderCustomPluginDirectory, error);

            return [plugins arrayByAddingObjectsFromArray:custom];
        }
        case 2: {
            NSArray *plugins = %orig(path, error);
            NSArray *custom = %orig(kWeeLoaderCustomBulletinBoardPluginDirectory, error);

            return [plugins arrayByAddingObjectsFromArray:custom];
        }
        default:
            return %orig;
    }
}

%end

%hook NSBundle

+ (NSBundle *)bundleWithPath:(NSString *)fullPath {
    switch (WeeLoaderCurrentThreadLoadingStatus()) {
        case 1: {
            NSBundle *bundle = %orig(fullPath);

            if (bundle == nil && [fullPath hasPrefix:kWeeLoaderDefaultPluginDirectory]) {
                fullPath = [kWeeLoaderCustomPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[kWeeLoaderDefaultPluginDirectory length]]];
                bundle = %orig(fullPath);
            }

            return bundle;
        }
        case 2: {
            NSBundle *bundle = %orig(fullPath);

            if (bundle == nil && [fullPath hasPrefix:kWeeLoaderDefaultBulletinBoardPluginDirectory]) {
                fullPath = [kWeeLoaderCustomBulletinBoardPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[kWeeLoaderDefaultBulletinBoardPluginDirectory length]]];
                bundle = %orig(fullPath);
            }

            return bundle;
        }
        default:
            return %orig;
    }
}

%end

