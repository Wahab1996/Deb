#import <Foundation/Foundation.h>
@class AppRecord;

@interface AppDiscovery : NSObject
+ (NSArray<AppRecord *> *)installedUserApps;
@end
