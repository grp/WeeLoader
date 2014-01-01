static NSString * const WeeLoaderDefaultPluginDirectory = @"/System/Library/WeeAppPlugins";
static NSString * const WeeLoaderCustomPluginDirectory = @"/Library/WeeLoader/Plugins";
static NSString * const WeeLoaderSerializationPrefix = @"/WeeLoaderFailsafePathShouldNotExist";

static NSString * const WeeLoaderDefaultBulletinBoardPluginDirectory = @"/System/Library/BulletinBoardPlugins";
static NSString * const WeeLoaderCustomBulletinBoardPluginDirectory = @"/Library/WeeLoader/BulletinBoardPlugins";

static NSString * const WeeLoaderThreadDictionaryKey = @"WeeLoaderLoadingPlugins";

static NSInteger WeeLoaderCurrentThreadLoadingStatus() {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:WeeLoaderThreadDictionaryKey] intValue];
}

static void WeeLoaderSetCurrentThreadLoadingStatus(NSInteger loading) {
    [[[NSThread currentThread] threadDictionary] setObject:[NSNumber numberWithInt:loading] forKey:WeeLoaderThreadDictionaryKey];
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
        if([path hasPrefix:[NSString stringWithFormat:@"%@/", WeeLoaderCustomPluginDirectory]]) {
            return [NSString stringWithFormat:@"%@/%@", WeeLoaderSerializationPrefix, path];
        }
    }

    return path;
}

- (void)setPathToWeeAppPluginBundle:(NSString *)path {
    NSString *prefix = [NSString stringWithFormat:@"%@/", WeeLoaderSerializationPrefix];
    if([path hasPrefix:prefix]) {
        %orig([path substringFromIndex:[prefix length]]);
    } else {
        %orig(path);
    }
}

%end

%hook NSFileManager

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    switch (WeeLoaderCurrentThreadLoadingStatus()) {
        case 1: {
            NSArray *plugins = %orig(path, error);
            NSArray *custom = %orig(WeeLoaderCustomPluginDirectory, error);

            return [plugins arrayByAddingObjectsFromArray:custom];
        }
        case 2: {
            NSArray *plugins = %orig(path, error);
            NSArray *custom = %orig(WeeLoaderCustomBulletinBoardPluginDirectory, error);

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

            if (bundle == nil && [fullPath hasPrefix:WeeLoaderDefaultPluginDirectory]) {
                fullPath = [WeeLoaderCustomPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[WeeLoaderDefaultPluginDirectory length]]];
                bundle = %orig(fullPath);
            }

            return bundle;
        }
        case 2: {
            NSBundle *bundle = %orig(fullPath);

            if (bundle == nil && [fullPath hasPrefix:WeeLoaderDefaultBulletinBoardPluginDirectory]) {
                fullPath = [WeeLoaderCustomBulletinBoardPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[WeeLoaderDefaultBulletinBoardPluginDirectory length]]];
                bundle = %orig(fullPath);
            }

            return bundle;
        }
        default:
            return %orig;
    }
}

%end

