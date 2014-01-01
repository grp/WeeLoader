
#define kWeeLoaderDefaultPluginDirectory @"/System/Library/WeeAppPlugins"
#define kWeeLoaderCustomPluginDirectory @"/Library/WeeLoader/Plugins"
#define kWeeLoaderSerializationPrefix @"/WeeLoaderFailsafePathShouldNotExist"

#define kWeeLoaderDefaultBulletinBoardPluginDirectory @"/System/Library/BulletinBoardPlugins"
#define kWeeLoaderCustomBulletinBoardPluginDirectory @"/Library/WeeLoader/BulletinBoardPlugins"

#define kWeeLoaderThreadDictionaryKey @"WeeLoaderLoadingPlugins"

static NSInteger WeeLoaderCurrentThreadLoadingStatus() {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:kWeeLoaderThreadDictionaryKey] intValue];
}

static void WeeLoaderSetCurrentThreadLoadingStatus(NSInteger loading) {
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

%hook BBSectionInfo

- (void)encodeWithCoder:(NSCoder *)encoder {
    WeeLoaderSetCurrentThreadLoadingStatus(3);
    %orig;
    WeeLoaderSetCurrentThreadLoadingStatus(0);
}

- (NSString *)pathToWeeAppPluginBundle {
    NSString *path = %orig;

    if(WeeLoaderCurrentThreadLoadingStatus() == 3) {
        if([path hasPrefix:[NSString stringWithFormat:@"%@/", kWeeLoaderCustomPluginDirectory]]) {
            return [NSString stringWithFormat:@"%@/%@", kWeeLoaderSerializationPrefix, path];
        }
    }

    return path;
}

- (void)setPathToWeeAppPluginBundle:(NSString *)path {
    NSString *prefix = [NSString stringWithFormat:@"%@/", kWeeLoaderSerializationPrefix];
    if([path hasPrefix:prefix]) {
        path = [path substringFromIndex:[prefix length]];

        NSFileManager *dfm = [NSFileManager defaultManager];
        if (![dfm fileExistsAtPath:path]) {
            NSString *bundle = [[path pathComponents] lastObject];
            NSString *defaultPath = [kWeeLoaderDefaultPluginDirectory stringByAppendingPathComponent:bundle];
            NSString *customPath = [kWeeLoaderCustomPluginDirectory stringByAppendingPathComponent:bundle];
            if ([dfm fileExistsAtPath:defaultPath]) {
                path = defaultPath;
            } else if ([dfm fileExistsAtPath:customPath]) {
                path = customPath;
            }
        }
    }

    %orig(path);
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

