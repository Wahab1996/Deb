#import "SnapshotStore.h"

@implementation SnapshotStore
+ (NSURL *)directory {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [base URLByAppendingPathComponent:@"Snapshots" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
+ (NSURL *)urlForBundleID:(NSString *)bundleID {
    NSString *safe = [bundleID stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [[self directory] URLByAppendingPathComponent:[safe stringByAppendingString:@".plist"]];
}
+ (BOOL)saveSnapshot:(NSDictionary *)snapshot bundleID:(NSString *)bundleID error:(NSError **)error {
    NSDictionary *wrapper = @{@"created": [NSDate date], @"values": snapshot ?: @{}};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:wrapper format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data ? [data writeToURL:[self urlForBundleID:bundleID] options:NSDataWritingAtomic error:error] : NO;
}
+ (NSDictionary *)wrapperForBundleID:(NSString *)bundleID {
    NSData *data = [NSData dataWithContentsOfURL:[self urlForBundleID:bundleID]];
    if (!data) return nil;
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}
+ (NSDictionary *)loadSnapshotForBundleID:(NSString *)bundleID { return [self wrapperForBundleID:bundleID][@"values"]; }
+ (NSDate *)snapshotDateForBundleID:(NSString *)bundleID { return [self wrapperForBundleID:bundleID][@"created"]; }
@end
