static NSString * const WeeLoaderDefaultPluginDirectory = @"/System/Library/WeeAppPlugins";
static NSString * const WeeLoaderCustomPluginDirectory = @"/Library/WeeLoader/Plugins";
static NSString * const WeeLoaderSerializationPrefix = @"/WeeLoaderFailsafePathShouldNotExist/";

static NSString * const WeeLoaderDefaultBulletinBoardPluginDirectory = @"/System/Library/BulletinBoardPlugins";
static NSString * const WeeLoaderCustomBulletinBoardPluginDirectory = @"/Library/WeeLoader/BulletinBoardPlugins";

static NSString * const WeeLoaderThreadDictionaryKey = @"WeeLoaderLoadingPlugins";

static NSInteger WeeLoaderCurrentThreadLoadingStatus() {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:WeeLoaderThreadDictionaryKey] intValue];
}

static void WeeLoaderSetCurrentThreadLoadingStatus(NSInteger loading) {
    [[[NSThread currentThread] threadDictionary] setObject:[NSNumber numberWithInt:loading] forKey:WeeLoaderThreadDictionaryKey];
}

%hook BBSectionInfo

- (void)encodeWithCoder:(NSCoder *)encoder {
    WeeLoaderSetCurrentThreadLoadingStatus(3);
    %orig;
    WeeLoaderSetCurrentThreadLoadingStatus(0);
}

- (NSString *)pathToWeeAppPluginBundle {
    NSString *path = %orig;

    if (WeeLoaderCurrentThreadLoadingStatus() == 3) {
        if ([path hasPrefix:[NSString stringWithFormat:@"%@/", WeeLoaderCustomPluginDirectory]]) {
            return [NSString stringWithFormat:@"%@%@", WeeLoaderSerializationPrefix, path];
        }
    }

    return path;
}

- (void)setPathToWeeAppPluginBundle:(NSString *)path {
    if ([path hasPrefix:WeeLoaderSerializationPrefix]) {
        %orig([path substringFromIndex:[WeeLoaderSerializationPrefix length]]);
    } else {
        %orig(path);
    }
}

%end

%group Legacy

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

%end

extern NSArray *BBLibraryDirectoriesForFolderNamed(NSString *) __attribute__((weak_import));
MSHook(NSArray *,BBLibraryDirectoriesForFolderNamed, NSString *name) {
    NSArray *directories = _BBLibraryDirectoriesForFolderNamed(name);
    if ([name isEqualToString:[WeeLoaderDefaultBulletinBoardPluginDirectory lastPathComponent]]) {
        directories = [directories arrayByAddingObject:WeeLoaderCustomBulletinBoardPluginDirectory];
    }

    return directories;
}

extern NSArray *_SBUIWidgetBundlePaths() __attribute__((weak_import));
MSHook(NSArray *, _SBUIWidgetBundlePaths) {
    NSMutableArray *paths = [NSMutableArray arrayWithArray:__SBUIWidgetBundlePaths()];
    NSArray *additionalPaths = [NSFileManager.defaultManager contentsOfDirectoryAtPath:WeeLoaderCustomPluginDirectory error:NULL];
    for (NSString *basename in additionalPaths) {
        if ([basename hasSuffix:@".bundle"]) {
            NSString *bundlePath = [WeeLoaderCustomPluginDirectory stringByAppendingPathComponent:basename];
            [paths addObject:bundlePath];
        }
    }
    return paths;
}

%ctor {
    %init;
    if ([%c(BBServer) instancesRespondToSelector:@selector(_loadAllDataProviderPluginBundles)]) {
        %init(Legacy);
    } else {
        MSHookFunction(BBLibraryDirectoriesForFolderNamed, $BBLibraryDirectoriesForFolderNamed, (void **)&_BBLibraryDirectoriesForFolderNamed);
        MSHookFunction(_SBUIWidgetBundlePaths, $_SBUIWidgetBundlePaths, (void **)&__SBUIWidgetBundlePaths);
    }
}
