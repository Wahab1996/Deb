#import <Foundation/Foundation.h>
@interface SnapshotStore : NSObject
+ (BOOL)saveSnapshot:(NSDictionary<NSString *, NSString *> *)snapshot bundleID:(NSString *)bundleID error:(NSError **)error;
+ (NSDictionary<NSString *, NSString *> *)loadSnapshotForBundleID:(NSString *)bundleID;
+ (NSDate *)snapshotDateForBundleID:(NSString *)bundleID;
@end
