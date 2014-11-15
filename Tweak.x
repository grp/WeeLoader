#import "BBWeeAppController-Protocol.h"

static NSString * const WeeLoaderDefaultPluginDirectory = @"/System/Library/WeeAppPlugins";
static NSString * const WeeLoaderCustomPluginDirectory = @"/Library/WeeLoader/Plugins";
static NSString * const WeeLoaderSerializationPrefix = @"/WeeLoaderFailsafePathShouldNotExist/";

static NSString * const WeeLoaderDefaultBulletinBoardPluginDirectory = @"/System/Library/BulletinBoardPlugins";
static NSString * const WeeLoaderCustomBulletinBoardPluginDirectory = @"/Library/WeeLoader/BulletinBoardPlugins";

static NSString * const WeeLoaderThreadDictionaryKey = @"WeeLoaderLoadingPlugins";

static NSInteger WeeLoaderCurrentThreadLoadingStatus() {
    return [NSThread.currentThread.threadDictionary[WeeLoaderThreadDictionaryKey] intValue];
}

static void WeeLoaderSetCurrentThreadLoadingStatus(NSInteger loading) {
    NSThread.currentThread.threadDictionary[WeeLoaderThreadDictionaryKey] = @(loading);
}

__attribute__((weak_import)) @interface BBSectionIconVariant: NSObject
+ (id)variantWithFormat:(int)format imageName:(NSString *)name inBundle:(NSBundle *)bundle;
@end

__attribute__((weak_import)) @interface BBSectionIcon: NSObject
- (void)addVariant:(BBSectionIconVariant *)variant;
@end

@interface BBSectionInfo: NSObject
@property (copy, nonatomic) NSString *pathToWeeAppPluginBundle;
@property (copy, nonatomic) NSString *displayName;
@property (copy, nonatomic) BBSectionIcon *icon;
@property (assign, nonatomic) BOOL showsInNotificationCenter;
@end

%hook BBSectionInfo

- (void)encodeWithCoder:(NSCoder *)encoder {
    WeeLoaderSetCurrentThreadLoadingStatus(3);
    %orig;
    WeeLoaderSetCurrentThreadLoadingStatus(0);
}

- (NSString *)pathToWeeAppPluginBundle {
    NSString *path = %orig;

    if (WeeLoaderCurrentThreadLoadingStatus() == 3) {
        if ([path hasPrefix:WeeLoaderCustomPluginDirectory]) {
            return [WeeLoaderSerializationPrefix stringByAppendingString:path];
        }
    }

    return path;
}

- (void)setPathToWeeAppPluginBundle:(NSString *)path {
    if ([path hasPrefix:WeeLoaderSerializationPrefix]) {
        %orig([path substringFromIndex:WeeLoaderSerializationPrefix.length]);
    } else {
        %orig;
    }
}

%end

%group iOS_5_and_6

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
            NSArray *plugins = %orig;
            NSArray *custom = %orig(WeeLoaderCustomPluginDirectory, error);

            return [plugins arrayByAddingObjectsFromArray:custom];
        }
        case 2: {
            NSArray *plugins = %orig;
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
            NSBundle *bundle = %orig;

            if (bundle == nil && [fullPath hasPrefix:WeeLoaderDefaultPluginDirectory]) {
                fullPath = [WeeLoaderCustomPluginDirectory stringByAppendingString:[fullPath substringFromIndex:[WeeLoaderDefaultPluginDirectory length]]];
                bundle = %orig(fullPath);
            }

            return bundle;
        }
        case 2: {
            NSBundle *bundle = %orig;

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

%group iOS_8

@interface SBNotificationCenterDataProvider: NSObject
- (BBSectionInfo *)defaultSectionInfo;
@end

@interface SBNotificationCenterDataProviderController: NSObject
+ (id)sharedInstance;
- (BBSectionInfo *)_sectionForWidgetExtension:(id)extension withSectionID:(NSString *)sectionID forCategory:(int)category;
- (void)_publishWidgetSection:(BBSectionInfo *)sectionInfo withExtension:(id)extension defaultEnabledWeeAppIDs:(NSArray *)ids;
@end

%hook SBNotificationCenterDataProvider

- (NSString *)sectionDisplayName {
    return %orig ?: self.defaultSectionInfo.displayName;
}

- (BBSectionIcon *)sectionIcon {
    return %orig ?: self.defaultSectionInfo.icon;
}

%end

%hook SpringBoard
- (void)_startBulletinBoardServer {
    %orig;
    SBNotificationCenterDataProviderController *controller = [%c(SBNotificationCenterDataProviderController) sharedInstance];
    for (NSString *basename in [NSFileManager.defaultManager contentsOfDirectoryAtPath:WeeLoaderCustomPluginDirectory error:NULL]) {
        if ([basename hasSuffix:@".bundle"]) {
            NSString *path = [WeeLoaderCustomPluginDirectory stringByAppendingPathComponent:basename];
            NSBundle *bundle = [NSBundle bundleWithPath:path];
            if (bundle) {
                NSString *sectionID = bundle.bundleIdentifier;
                BBSectionInfo *sectionInfo = [controller _sectionForWidgetExtension:nil withSectionID:sectionID forCategory:1];
                sectionInfo.pathToWeeAppPluginBundle = path;
                sectionInfo.displayName = bundle.infoDictionary[@"CFBundleDisplayName"];
                NSString *iconName = bundle.infoDictionary[@"CFBundleIconFile"];
                if (iconName) {
                    BBSectionIconVariant *iconVariant = [BBSectionIconVariant variantWithFormat:0 imageName:iconName inBundle:bundle];
                    BBSectionIcon *sectionIcon = [[BBSectionIcon alloc] init];
                    [sectionIcon addVariant:iconVariant];
                    sectionInfo.icon = sectionIcon;
                }
                [controller _publishWidgetSection:sectionInfo withExtension:nil defaultEnabledWeeAppIDs:@[sectionID]];
            }
        }
    }
}
%end

%hook SBWidgetsSettingsViewController
- (BOOL)_setSectionInfo:(BBSectionInfo *)sectionInfo enabled:(BOOL)enabled {
    BOOL success = %orig;
    if (!success && [sectionInfo.pathToWeeAppPluginBundle hasPrefix:WeeLoaderCustomPluginDirectory]) {
        sectionInfo.showsInNotificationCenter = enabled;
        success = YES;
    }
    return success;
}
%end

%end

@interface WeeLoaderLegacyView: UIView
@end

@implementation WeeLoaderLegacyView
- (void)layoutSubviews {
    for (UIView *subview in self.subviews) {
        subview.frame = self.frame;
    }
    [super layoutSubviews];
}
@end

@interface _SBUIWidgetViewController: UIViewController
@property (copy, nonatomic) NSString *widgetIdentifier;
- (void)loadView;
- (void)unloadView;
- (void)hostWillPresent;
- (void)hostDidDismiss;
- (CGSize)preferredViewSize;
@end

typedef NS_ENUM(NSInteger, WeeLoaderLegacyControllerViewState) {
    WeeLoaderLegacyControllerViewStateNone,
    WeeLoaderLegacyControllerViewStatePlaceholder,
    WeeLoaderLegacyControllerViewStateLoaded
};

@interface WeeLoaderLegacyController: _SBUIWidgetViewController
@end

@implementation WeeLoaderLegacyController {
    id<BBWeeAppController> _weeAppController;
    WeeLoaderLegacyControllerViewState _viewState;
}

- (void)setWidgetIdentifier:(NSString *)widgetIdentifier {
    if (!_weeAppController && widgetIdentifier) {
        NSBundle *weeAppBundle = [NSBundle bundleWithIdentifier:widgetIdentifier];
        _weeAppController = [[weeAppBundle.principalClass alloc] init];
    }
    [super setWidgetIdentifier:widgetIdentifier];
}

- (void)loadView {
    CGSize size = self.preferredViewSize;
    self.view = [[WeeLoaderLegacyView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    if ([_weeAppController respondsToSelector:@selector(launchURLForTapLocation:)]) {
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(launchURLForTapLocationFromRecognizer:)];
        [self.view addGestureRecognizer:tapRecognizer];
    } else if ([_weeAppController respondsToSelector:@selector(launchURL)]) {
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(launchURL)];
        [self.view addGestureRecognizer:tapRecognizer];
    }
    [self loadPlaceholderWeeAppView];
}

- (void)unloadView {
    [self unloadWeeAppView];
    [super unloadView];
}

- (CGSize)preferredViewSize {
    if ([_weeAppController respondsToSelector:@selector(viewHeight)]) {
        CGSize size = CGSizeMake(0, _weeAppController.viewHeight);
        return size;
    }
    return [super preferredViewSize];
}

- (void)loadPlaceholderWeeAppView {
    if (!_weeAppController.view && [_weeAppController respondsToSelector:@selector(loadPlaceholderView)]) {
        [_weeAppController loadPlaceholderView];
        _viewState = WeeLoaderLegacyControllerViewStatePlaceholder;
    }
}

- (void)loadFullWeeAppView {
    if ([_weeAppController respondsToSelector:@selector(loadFullView)]) {
        [_weeAppController loadFullView];
        _viewState = WeeLoaderLegacyControllerViewStateLoaded;
    } else if ([_weeAppController respondsToSelector:@selector(loadView)]) {
        [_weeAppController loadView];
        _viewState = WeeLoaderLegacyControllerViewStateLoaded;
    }
}

- (void)unloadWeeAppView {
    [_weeAppController.view removeFromSuperview];
    if ([_weeAppController respondsToSelector:@selector(unloadView)]) {
        [_weeAppController unloadView];
        if (!_weeAppController.view) {
            _viewState = WeeLoaderLegacyControllerViewStateNone;
        }
    }
}

- (void)hostWillPresent {
    if (_viewState == WeeLoaderLegacyControllerViewStateNone) {
        [self loadPlaceholderWeeAppView];
    }
    if (_viewState != WeeLoaderLegacyControllerViewStateLoaded) {
        [self loadFullWeeAppView];
    }
    [self.view addSubview:_weeAppController.view];
    [super hostWillPresent];
}

- (void)hostDidDismiss {
    [self unloadWeeAppView];
    [self loadPlaceholderWeeAppView];
    [super hostDidDismiss];
}

- (void)launchURLForTapLocationFromRecognizer:(UITapGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:_weeAppController.view];
    NSURL *url = [_weeAppController launchURLForTapLocation:location];
    if (url) {
        [UIApplication.sharedApplication openURL:url];
    }
}

- (void)launchURL {
    NSURL *url = [_weeAppController launchURL];
    if (url) {
        [UIApplication.sharedApplication openURL:url];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    if ([_weeAppController respondsToSelector:@selector(viewWillAppear)]) {
        [_weeAppController viewWillAppear];
    }
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    // On iOS 8, -hostWillPresent might never be called (e.g. when we are disabled and then re-enabled), so
    // let's make sure we load the full view somewhere.  We could do this in -loadView or -viewWillAppear
    // instead, but if we wait for -viewDidAppear the widget gets better initial size info.
    if ([%c(SBNotificationCenterDataProviderController) instancesRespondToSelector:@selector(beginPublishingIfNecessary)]) { // iOS 8
        [self hostWillPresent];
    }

    if ([_weeAppController respondsToSelector:@selector(viewDidAppear)]) {
        [_weeAppController viewDidAppear];
    }
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([_weeAppController respondsToSelector:@selector(viewWillDisappear)]) {
        [_weeAppController viewWillDisappear];
    }
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    if ([_weeAppController respondsToSelector:@selector(viewDidDisappear)]) {
        [_weeAppController viewDidDisappear];
    }
    [super viewDidDisappear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if ([_weeAppController respondsToSelector:@selector(willRotateToInterfaceOrientation:duration:)]) {
        [_weeAppController willRotateToInterfaceOrientation:toInterfaceOrientation];
    }
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
    if ([_weeAppController respondsToSelector:@selector(willAnimateRotationToInterfaceOrientation:duration:)]) {
        [_weeAppController willAnimateRotationToInterfaceOrientation:interfaceOrientation];
    }
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if ([_weeAppController respondsToSelector:@selector(didRotateFromInterfaceOrientation:)]) {
        [_weeAppController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    }
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

@end

extern NSArray *BBLibraryDirectoriesForFolderNamed(NSString *name) __attribute__((weak_import));
MSHook(NSArray *,BBLibraryDirectoriesForFolderNamed, NSString *name) {
    NSArray *directories = _BBLibraryDirectoriesForFolderNamed(name);
    if ([name isEqualToString:WeeLoaderDefaultBulletinBoardPluginDirectory.lastPathComponent]) {
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

MSHook(CFDictionaryRef, CFBundleGetInfoDictionary, CFBundleRef bundle) {
    CFDictionaryRef cf_infoDictionary = _CFBundleGetInfoDictionary(bundle);
    NSURL *bundleURL = (__bridge_transfer NSURL *)CFBundleCopyBundleURL(bundle);
    if ([bundleURL.URLByDeletingLastPathComponent.path isEqualToString:WeeLoaderCustomPluginDirectory]) {
        NSDictionary *infoDict = (__bridge NSDictionary *)cf_infoDictionary;
        if (!infoDict[@"SBUIWidgetViewControllers"]) {
            CFMutableDictionaryRef newInfoDict = CFDictionaryCreateMutableCopy(NULL, infoDict.count + 1, cf_infoDictionary);
            ((__bridge NSMutableDictionary *)newInfoDict)[@"SBUIWidgetViewControllers"] = @{
                @"SBUIWidgetIdiomNotificationCenterToday" : NSStringFromClass(WeeLoaderLegacyController.class)
            };
            CFAutorelease(newInfoDict);
            return newInfoDict;
        }
    }
    return cf_infoDictionary;
}

%ctor {
    %init;
    if ([%c(BBServer) instancesRespondToSelector:@selector(_loadAllDataProviderPluginBundles)]) { // iOS 5, 6
        %init(iOS_5_and_6);
    } else { // iOS 7, 8
        MSHookFunction(BBLibraryDirectoriesForFolderNamed, $BBLibraryDirectoriesForFolderNamed, (void **)&_BBLibraryDirectoriesForFolderNamed);
        MSHookFunction(_SBUIWidgetBundlePaths, $_SBUIWidgetBundlePaths, (void **)&__SBUIWidgetBundlePaths);
        MSHookFunction(CFBundleGetInfoDictionary, $CFBundleGetInfoDictionary, (void **)&_CFBundleGetInfoDictionary);
        if ([%c(SBNotificationCenterDataProviderController) instancesRespondToSelector:@selector(beginPublishingIfNecessary)]) { // iOS 8
            %init(iOS_8);
        }
    }
}
