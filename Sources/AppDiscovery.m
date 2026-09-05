#import "AppDiscovery.h"
#import "AppRecord.h"
#import <dlfcn.h>

@implementation AppDiscovery

+ (id)safeValue:(id)obj selectorName:(NSString *)selectorName {
    SEL sel = NSSelectorFromString(selectorName);
    if (!obj || ![obj respondsToSelector:sel]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [obj performSelector:sel];
#pragma clang diagnostic pop
}

+ (NSArray<AppRecord *> *)installedUserApps {
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return @[];

    id workspace = [self safeValue:workspaceClass selectorName:@"defaultWorkspace"];
    NSArray *proxies = [self safeValue:workspace selectorName:@"allInstalledApplications"];
    if (![proxies isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray<AppRecord *> *results = [NSMutableArray array];
    for (id proxy in proxies) {
        NSString *bundleID = [self safeValue:proxy selectorName:@"applicationIdentifier"];
        NSString *name = [self safeValue:proxy selectorName:@"localizedName"];
        NSURL *bundleURL = [self safeValue:proxy selectorName:@"bundleURL"];
        NSURL *dataURL = [self safeValue:proxy selectorName:@"dataContainerURL"];
        if (!dataURL) dataURL = [self safeValue:proxy selectorName:@"containerURL"];

        NSString *appType = [self safeValue:proxy selectorName:@"applicationType"];
        BOOL looksUser = [appType isEqualToString:@"User"] ||
                         [bundleURL.path containsString:@"/Bundle/Application/"] ||
                         [dataURL.path containsString:@"/Data/Application/"];
        if (!looksUser || bundleID.length == 0 || name.length == 0) continue;

        NSString *version = nil;
        NSDictionary *info = bundleURL ? [NSDictionary dictionaryWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]] : nil;
        if ([info isKindOfClass:[NSDictionary class]]) {
            version = info[@"CFBundleShortVersionString"] ?: info[@"CFBundleVersion"];
        }

        AppRecord *record = [AppRecord new];
        record.name = name;
        record.bundleID = bundleID;
        record.bundleURL = bundleURL;
        record.dataURL = dataURL;
        record.version = version ?: @"";
        [results addObject:record];
    }

    [results sortUsingComparator:^NSComparisonResult(AppRecord *a, AppRecord *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return results;
}

@end
