#import <Foundation/Foundation.h>
@class AppRecord, InspectionFinding;

@interface StateScanner : NSObject
+ (NSArray<InspectionFinding *> *)scanApp:(AppRecord *)app;
+ (NSArray<InspectionFinding *> *)scanStoreKitCluesForApp:(AppRecord *)app;
+ (NSDictionary<NSString *, NSString *> *)snapshotApp:(AppRecord *)app;

// Strict purchase-focused diff used by default in the UI.
+ (NSArray<InspectionFinding *> *)diffFrom:(NSDictionary<NSString *, NSString *> *)before
                                        to:(NSDictionary<NSString *, NSString *> *)after;

// Full unfiltered diff. Kept behind an explicit "Raw Changes" action.
+ (NSArray<InspectionFinding *> *)rawDiffFrom:(NSDictionary<NSString *, NSString *> *)before
                                           to:(NSDictionary<NSString *, NSString *> *)after;
@end
