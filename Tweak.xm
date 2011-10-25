
#define kWeeLoaderDefaultPluginDirectory @"/System/Library/WeeAppPlugins"
#define kWeeLoaderCustomPluginDirectory @"/Library/WeeLoader/Plugins"


#define kWeeLoaderThreadDictionaryKey @"WeeLoaderLoadingPlugins"

static BOOL WeeLoaderCurrentThreadIsLoading() {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:kWeeLoaderThreadDictionaryKey] boolValue];
}

static void WeeLoaderSetCurrentThreadIsLoading(BOOL loading) {
    [[[NSThread currentThread] threadDictionary] setObject:[NSNumber numberWithBool:loading] forKey:kWeeLoaderThreadDictionaryKey];
}

%hook BBServer

- (void)_loadAllWeeAppSections {
    WeeLoaderSetCurrentThreadIsLoading(YES);
    %orig;
    WeeLoaderSetCurrentThreadIsLoading(NO);
}

%end

%hook NSFileManager

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (WeeLoaderCurrentThreadIsLoading()) {
        NSArray *plugins = %orig(path, error);
        NSArray *custom = %orig(kWeeLoaderCustomPluginDictionary, error);

        return [plugins arrayByAddingObjectsFromArray:custom];
    } else {
        return %orig;
    }
}

%end

%hook NSBundle

+ (NSBundle *)bundleWithPath:(NSString *)fullPath {
    if (WeeLoaderCurrentThreadIsLoading()) {
        NSBundle *bundle = %orig(fullPath);

        if (bundle == nil && [fullPath hasPrefix:kWeeLoaderDefaultPluginDirectory]) {
            fullPath = [kWeeLoaderCustomPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[kWeeLoaderDefaultPluginDirectory length]]];
            bundle = %orig(fullPath);
        }

        return bundle;
    } else {
        return %orig;
    }
}

%end

