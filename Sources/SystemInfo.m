#import "SystemInfo.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>

@implementation SystemInfo

+ (NSString *)machineIdentifier {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] ?: @"Unknown";
}

+ (NSString *)kernelVersion {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.release encoding:NSUTF8StringEncoding] ?: @"Unknown";
}

+ (NSString *)jailbreakRoot {
    NSArray<NSString *> *candidates = @[@"/var/jb", @"/var/containers/Bundle/tweaksupport"];
    for (NSString *path in candidates) {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) return path;
    }
    return @"Not detected";
}

+ (BOOL)isRootless {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb" isDirectory:&isDir] && isDir;
}

+ (NSString *)bootstrapName {
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:@"/var/jb/basebin/dopamine"] || [fm fileExistsAtPath:@"/var/jb/.installed_dopamine"]) return @"Dopamine / Procursus";
    if ([fm fileExistsAtPath:@"/var/jb/usr/bin/apt"]) return @"Rootless bootstrap detected";
    return [self isRootless] ? @"Rootless (unknown bootstrap)" : @"Not detected";
}

+ (NSString *)uptimeString {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) != 0) return @"Unknown";
    NSTimeInterval uptime = [[NSDate date] timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:boottime.tv_sec]];
    NSInteger days = (NSInteger)(uptime / 86400);
    NSInteger hours = ((NSInteger)uptime % 86400) / 3600;
    NSInteger minutes = ((NSInteger)uptime % 3600) / 60;
    return [NSString stringWithFormat:@"%ldd %ldh %ldm", (long)days, (long)hours, (long)minutes];
}

+ (NSString *)storageString {
    NSError *error = nil;
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfFileSystemForPath:@"/var" error:&error];
    if (error || !attrs) return @"Unknown";
    unsigned long long free = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
    unsigned long long total = [attrs[NSFileSystemSize] unsignedLongLongValue];
    NSByteCountFormatter *fmt = [[NSByteCountFormatter alloc] init];
    fmt.countStyle = NSByteCountFormatterCountStyleFile;
    return [NSString stringWithFormat:@"%@ free / %@", [fmt stringFromByteCount:(long long)free], [fmt stringFromByteCount:(long long)total]];
}

+ (NSArray<NSArray<NSDictionary<NSString *,NSString *> *> *> *)overviewSections {
    UIDevice *d = UIDevice.currentDevice;
    NSString *mode = [self isRootless] ? @"Rootless" : @"Unknown / Rootful";
    return @[
        @[
            @{@"title": @"Device", @"value": [self machineIdentifier]},
            @{@"title": @"iOS", @"value": d.systemVersion ?: @"Unknown"},
            @{@"title": @"Kernel", @"value": [self kernelVersion]},
            @{@"title": @"Uptime", @"value": [self uptimeString]}
        ],
        @[
            @{@"title": @"Jailbreak mode", @"value": mode},
            @{@"title": @"JB root", @"value": [self jailbreakRoot]},
            @{@"title": @"Bootstrap", @"value": [self bootstrapName]}
        ],
        @[
            @{@"title": @"Storage", @"value": [self storageString]},
            @{@"title": @"Toolbox", @"value": @"v0.1.1 Core"}
        ]
    ];
}

@end
